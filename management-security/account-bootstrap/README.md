# Bootstrap alternativo da management account

O fluxo escolhido usa [`bootstrap/main.tf`](../../bootstrap/README.md). Este diretório é uma alternativa preservada e não deve ser executado junto com o bootstrap escolhido para criar os mesmos recursos. As instruções abaixo documentam apenas o uso independente da alternativa.

Este root fica dentro de [management-security](../README.md) e prepara somente a management account. As contas de workloads serão criadas pelo Account Factory com o blueprint. Por ser um subdiretório, ele tem execução e estado próprios; não é executado pelo Terraform do diretório pai.

Este root aplica o módulo [account_baseline](../../modules/account_baseline) na management account existente. Cria bucket de estado, provider OIDC do GitHub e role de deploy. Não cria contas, Organizations, Control Tower, SCPs ou IAM Identity Center.

## Primeira execução

Use Terraform e um profile com acesso administrativo à conta de destino. Para um profile configurado com IAM Identity Center, autentique com `aws sso login --profile terraform-management`.

Copie o exemplo, preencha o profile da conta, o nome globalmente único do bucket e o subject exato do GitHub:

```bash
cp environments/management-security/account-bootstrap.tfvars.example environments/management-security/account-bootstrap.tfvars
```

O exemplo concede `AdministratorAccess` explicitamente, reproduzindo o bootstrap original. Isso dá permissões administrativas amplas ao GitHub na conta. Escolha as policies adequadas ao seu deployment; o módulo não possui uma policy padrão. Os ARNs informados devem existir.

Depois de preencher o arquivo, execute a partir da raiz `Terraform/`:

```bash
cd management-security/account-bootstrap
export TF_DATA_DIR="$PWD/.terraform-management"
terraform init -reconfigure -backend-config="path=states/management/terraform.tfstate"
terraform validate
terraform plan -var-file=../../environments/management-security/account-bootstrap.tfvars -out=management.tfplan
terraform apply management.tfplan
terraform output
```

Use o workspace `default`. A conta de destino é determinada pelas credenciais do provider: informe o profile da management account. Os exemplos antigos de dev/prod são referências da proposta anterior e não fazem parte deste fluxo.

## Estado inicial e uso pelo root management-security

O backend inicial é local porque o bucket ainda será criado. Preserve o arquivo `states/management/terraform.tfstate` e seu backup; eles não devem ser commitados. Excluir o estado perde o vínculo com os recursos existentes. Não use o backend de `live/` para este root.

Depois do apply:

1. Configure o bucket retornado por `state_bucket_name` em `environments/management-security/backend.hcl`, usado pelo root pai.
2. Configure `github_role_arn` como `AWS_ROLE_ARN` no GitHub Environment correspondente.
3. Mantenha as chaves dos estados distintas: por exemplo, `management-security/terraform.tfstate` e `management-security/account-bootstrap.tfstate`.

Se quiser migrar o próprio estado do bootstrap para S3, faça isso depois que o bucket existir: substitua o bloco `backend "local" {}` de `backend.tf` por `backend "s3" {}` e prepare um arquivo de backend com bucket, região, chave exclusiva e `use_lockfile = true`. Com as credenciais da conta e o mesmo `TF_DATA_DIR` da execução local, execute `terraform init -migrate-state -backend-config=<arquivo>`. Não use `-reconfigure` para essa migração. Mantenha backup do estado local e não use a mesma chave do root pai.

## Trust policy do GitHub

`github_subjects` recebe valores completos e exatos, por exemplo:

- Job com GitHub Environment: `repo:OWNER/REPO:environment:management-security`.
- Job sem environment, limitado à branch: `repo:OWNER/REPO:ref:refs/heads/main`.
- Pull request sem environment: `repo:OWNER/REPO:pull_request`.

O exemplo da management usa um GitHub Environment chamado `management-security`, que deve existir caso você use essa forma de autenticação. O workflow atual cobre apenas dev/prod; ele não executa este root. Se o repositório usa IDs imutáveis no subject, informe o valor correspondente, como `repo:OWNER@OWNER_ID/REPO@REPO_ID:environment:management-security`. Configure as restrições de branches no GitHub Environment quando usar subjects por environment. Não é aplicado um curinga para liberar todo o repositório.

## Relação com o bootstrap escolhido

O `bootstrap/` original foi preservado e não foi migrado. Ele já declara bucket de estado e OIDC para a management; como foi escolhido para criá-los, não execute este root para criar os mesmos objetos novamente. Este root destina-se a contas que ainda não têm esses recursos gerenciados. Se o bucket, OIDC ou role já existir, será necessário reconciliar/importar o recurso e seu estado antes de aplicar. Não gerencie o mesmo objeto por dois roots.

O bucket começa vazio; não inclui retenção automática de versões nem chave KMS personalizada. O GitHub OIDC é único por URL na conta. As tags padrão são aplicadas pelo provider. A região dos recursos S3 é a mesma do provider.

As falhas previamente identificadas no workflow e seus profiles continuam fora desta entrega: criar a role não torna o pipeline existente operacional automaticamente.

Referências: [backend local](https://developer.hashicorp.com/terraform/language/backend/local), [OIDC GitHub/AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) e [provider OIDC no Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider).

## Inputs e outputs da alternativa

| Input | Tipo | Padrão/obrigatoriedade |
| --- | --- | --- |
| `aws_region` | `string` | `us-east-2`. |
| `aws_profile` | `string` | `null`; credenciais do ambiente quando omitido. |
| `environment` | `string` | Obrigatório; identifica as tags. |
| `state_bucket_name` | `string` | Obrigatório. |
| `github_role_name` | `string` | `TerraformDeploy`. |
| `github_subjects` | `set(string)` | Obrigatório; subjects exatos. |
| `github_policy_arns` | `set(string)` | Obrigatório; policies explícitas. |

Outputs: `state_bucket_name`, `github_role_arn` e `github_oidc_provider_arn`. O contrato interno e as limitações do módulo estão no [catálogo account_baseline](../../README.md#account_baseline). Provider AWS `~> 6.0`; credenciais determinam a conta de destino.
