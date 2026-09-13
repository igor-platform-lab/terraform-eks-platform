# Bootstrap inicial da management account

O fluxo escolhido usa [main.tf](main.tf) para preparar a management account antes da landing zone. Executar Terraform neste diretório carrega todos os seus arquivos `.tf`; `main.tf` não é executado isoladamente. Esta documentação descreve o código em 13/09/2026, sem afirmar que os recursos já existem na AWS.

## Recursos e responsabilidade

| Declaração | Comportamento |
| --- | --- |
| `module.s3_terraform_state` | Bucket de estado, versionado, SSE-S3 e quatro bloqueios de acesso público. |
| `aws_iam_openid_connect_provider.github` | OIDC do GitHub, audience `sts.amazonaws.com`, thumbprint fixo no código. |
| `aws_iam_role.github_actions` | Role `TerraformManagement`, com `AdministratorAccess`. |
| `aws_organizations_organization.org` | Organizations com todas as funcionalidades; tipos SCP e Tag Policy habilitados e trusted access para Control Tower. |
| `aws_organizations_organizational_unit.workloads` | OU `Workloads` diretamente sob a raiz. |
| `aws_organizations_organizational_unit.security` | OU com nome real `LogArchive`, diretamente sob a raiz. O identificador Terraform `security` não é o nome exibido no console. |
| `audit_account` e `log_archive_account` | Contas `Audit` e `Log Archive`, ambas na OU `LogArchive`. |

Habilitar os tipos SCP/Tag Policy não cria políticas personalizadas nem attachments. Criar uma OU no Organizations não a registra automaticamente no Control Tower. Este root não cria a landing zone, as roles de serviço do Control Tower ou o blueprint AFC.

## Inputs

Todos estão em [variables.tf](variables.tf).

| Nome | Tipo | Obrigatório | Uso/padrão |
| --- | --- | --- | --- |
| `aws_region` | `string` | sim | Região da preparação; o desenho atual usa `us-east-2`. |
| `aws_profile` | `string` | sim | Profile com acesso à management. |
| `state_bucket_name` | `string` | sim | Nome globalmente único do bucket. |
| `github_repository` | `string` | sim | Repositório no formato `OWNER/REPO`. |
| `github_branch` | `string` | não | Branch autorizada; padrão `main`. |
| `audit_account_email` | `string` | sim | E-mail exclusivo para a conta Audit. |
| `log_archive_account_email` | `string` | sim | E-mail exclusivo para a conta Log Archive. |
| `localstack_enabled` | `bool` | não | Padrão `false`; deve permanecer falso no fluxo AWS escolhido. |
| `localstack_endpoint` | `string` | não | Referência legada; padrão `http://localhost:4566`. |

## Execução e estado

Pré-requisitos: credenciais da management, permissões de S3/IAM/Organizations, e-mails disponíveis e configuração correspondente aos recursos já existentes. Caso a organização ou o OIDC já exista, o estado precisa representá-los antes de uma tentativa de criação. Este root não adota objetos existentes automaticamente.

Exemplo de conteúdo para `bootstrap/bootstrap.tfvars` local, sem credenciais estáticas:

```hcl
aws_region                = "us-east-2"
aws_profile               = "terraform-management"
state_bucket_name         = "terraform-state-<MANAGEMENT_ACCOUNT_ID>-us-east-2"
github_repository         = "<OWNER>/<REPO>"
github_branch             = "main"
audit_account_email       = "<EMAIL_AUDIT>"
log_archive_account_email = "<EMAIL_LOG_ARCHIVE>"
localstack_enabled        = false
```

A partir da raiz `Terraform/`, com os valores reais preenchidos:

```bash
export AWS_PROFILE=terraform-management
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan -var-file=bootstrap.tfvars -out=bootstrap.tfplan
terraform -chdir=bootstrap apply bootstrap.tfplan
```

`bootstrap.tfvars` não é carregado automaticamente pelo nome; o comando o informa explicitamente. Para profile SSO, o login deve estar válido antes da execução. O provider não fixa uma versão do AWS provider neste root; o lockfile registra a versão selecionada.

O backend atual é local implícito (`bootstrap/terraform.tfstate`). Criar um bucket não migra o próprio estado. Preserve estado e backup fora do Git, pois este estado também controla a organização e as contas compartilhadas. Não reutilize esse estado para `management-security/` ou `live/`.

O root não declara outputs. Após uma aplicação bem-sucedida, os IDs de Audit e Log Archive podem ser consultados no Organizations ou no estado:

```bash
terraform -chdir=bootstrap state show aws_organizations_account.audit_account
terraform -chdir=bootstrap state show aws_organizations_account.log_archive_account
```

Os IDs de 12 dígitos alimentam [landing-zone.json](../landing-zone.json): Log Archive em `centralizedLogging.accountId`; Audit em `config.accountId` e `securityRoles.accountId`. O nome do bucket alimenta [o backend da management](../environments/management-security/backend.hcl), cuja chave é `management-security/terraform.tfstate`. Esse backend autentica independentemente do provider.

Uma eventual migração do próprio estado exige declarar o backend S3 e usar uma chave exclusiva, como `bootstrap/terraform.tfstate`, com backup e `terraform init -migrate-state`. Isso não foi implementado nem executado. `-reconfigure` não substitui migração de estado. Referência: [inicialização e migração de backend](https://developer.hashicorp.com/terraform/cli/commands/init#backend-initialization).

## Acesso GitHub e limites atuais

A trust policy da role `TerraformManagement` exige audience STS e subject `repo:OWNER/REPO:ref:refs/heads/BRANCH`, comparado por `StringLike`. Jobs com GitHub Environment usam outro subject; portanto a role não é automaticamente compatível com os jobs dev/prod atuais. O bootstrap fixa um thumbprint, enquanto `account_baseline` e o blueprint não o fixam. As permissões administrativas são explícitas no código.

O atributo `aws_service_access_principals` declara apenas Control Tower. Integrações posteriores podem habilitar outros serviços no Organizations; a gestão dessa lista precisa ser coerente com esses serviços para evitar que uma reaplicação remova trusted access. Referência: [Organizations no provider AWS](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organization).

LocalStack saiu do plano do projeto, mas suas opções permanecem no código. Os endpoints alternativos declarados aqui cobrem IAM/S3/STS, não Organizations.

[management-security/account-bootstrap](../management-security/account-bootstrap/README.md) é uma alternativa preservada, fora do fluxo escolhido. Não execute os dois roots para gerir o mesmo bucket/OIDC. Nas novas contas de workloads, o dono dos recursos equivalentes é CloudFormation por meio do [blueprint AFC](../management-security/README.md).
