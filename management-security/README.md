# Landing zone e blueprints na management account

A preparação inicial usa [`bootstrap/main.tf`](../bootstrap/README.md). Este root publica o blueprint `account-baseline` na management account, que também será o hub dos blueprints neste projeto pessoal. A landing zone é declarada em `10_controltower.tf`. A criação das contas de workloads é feita pelo console do Account Factory.

## Arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `00_backend.tf` | Backend S3 do estado da management. |
| `00_providers.tf` | Região, profile e tags do provider. |
| `00_variables.tf` | Inputs de execução e ARN do operador do console. |
| `00_data.tf` | Dados da conta, região e partição. |
| `20_account_factory.tf` | Bucket de templates, upload, produto do Service Catalog e role de acesso. |
| `00_outputs.tf` | ID do hub, produto, versão e ARN da role. |
| `templates/account-baseline.yaml` | Recursos CloudFormation a criar nas novas contas. |
| `10_controltower.tf` | Landing zone 4.0 com o manifest `../landing-zone.json`. |
| `account-bootstrap/` | Alternativa preservada, fora do fluxo escolhido; possui estado e execução separados. |

## O que fica na management account

- Bucket privado `controltower-blueprints-<ACCOUNT_ID>-<REGION>`, versionado e com SSE-S3, usando o módulo `s3`.
- Template YAML armazenado no bucket e produto `account-baseline` do tipo `CLOUD_FORMATION_TEMPLATE`.
- Role `AWSControlTowerBlueprintAccess`, com `AWSServiceCatalogAdminFullAccess` e `AmazonS3ReadOnlyAccess`.

A trust policy dessa role autoriza `AWSControlTowerAdmin` da própria management account e o ARN informado em `control_tower_operator_arn`. Informe o ARN IAM completo do usuário ou role que você usa para abrir o Account Factory; para Identity Center, inclua o caminho completo da role `AWSReservedSSO_...`. Não informe o ARN STS de uma sessão.

O Control Tower cria e compartilha o portfólio necessário durante o fluxo AFC; este root publica o produto e concede o acesso. O provider deve usar a management account e a Home Region da landing zone.

## Publicação

O código da landing zone está presente, mas ainda faltam as roles de serviço exigidas pela criação via API e os IDs reais no manifest. A role `AWSControlTowerAdmin` precisa existir antes de criar a trust policy de `AWSControlTowerBlueprintAccess`; ao implementar as roles, declare as dependências Terraform correspondentes. O bucket do backend também precisa existir antes do init: ele é diferente do bucket de templates criado aqui. Substitua `meu-bucket-tfstate` em `environments/management-security/backend.hcl`.

Na raiz `Terraform/`, copie e preencha o exemplo do operador:

```bash
cp environments/management-security/blueprints.tfvars.example environments/management-security/blueprints.tfvars
```

Confira o profile e a região em `management-security.tfvars`. Para um profile SSO, faça o login previamente. Depois:

```bash
export AWS_PROFILE=terraform-management
terraform -chdir=management-security init -reconfigure -backend-config=../environments/management-security/backend.hcl
terraform -chdir=management-security plan -var-file=../environments/management-security/management-security.tfvars -var-file=../environments/management-security/blueprints.tfvars
terraform -chdir=management-security apply -var-file=../environments/management-security/management-security.tfvars -var-file=../environments/management-security/blueprints.tfvars
terraform -chdir=management-security output
```

O profile do provider não configura a autenticação do backend; `AWS_PROFILE` no exemplo atende ao backend também. O apply inclui a landing zone e a publicação do blueprint; não cria contas de workloads nem aplica o template na management account. Conclua os pré-requisitos da landing zone antes de executar esses comandos.

## Uso no console

1. Abra Control Tower → Account Factory → Create account.
2. Informe os dados da conta e selecione uma OU registrada com a baseline do Control Tower habilitada.
3. Em Account factory customization, informe `blueprint_hub_account_id` como conta hub.
4. Escolha o produto `account-baseline` e a versão retornada em `blueprint_version`.
5. Preencha os parâmetros abaixo e escolha **Home Region**: o template contém recursos IAM globais e deve ser aplicado uma única vez por conta.
6. Crie a conta e acompanhe o provisionamento no Control Tower.

| Parâmetro do blueprint | Valor |
| --- | --- |
| `GitHubSubjects` | Subjects exatos, separados por vírgula; por exemplo `repo:OWNER/REPO:environment:dev`. Use o formato real do token, inclusive IDs imutáveis quando aplicável. |
| `GitHubRoleName` | Padrão `TerraformDeploy`. |
| `GitHubPolicyArns` | Policies existentes, separadas por vírgula. Padrão `arn:aws:iam::aws:policy/AdministratorAccess`, que concede administração ampla. |

Na nova conta, CloudFormation cria um bucket `terraform-state-<ACCOUNT_ID>-<REGION>`, com versionamento, SSE-S3 e os quatro bloqueios de acesso público; o provider OIDC do GitHub; e a role de deploy com as policies escolhidas. A trust policy exige audience STS e um dos subjects exatos. O template não contém validações customizadas.

Os outputs da stack na nova conta expõem `StateBucketName`, `GitHubRoleArn` e `GitHubOIDCProviderArn`. Use o bucket no backend do `live/` e o ARN da role em `AWS_ROLE_ARN` do GitHub Environment.

## SCPs e manutenção

Associe previamente suas SCPs à OU no Organizations. As contas ficam sujeitas às políticas da OU selecionada. O blueprint não cria SCPs e não concede exceções às políticas.

A versão do produto usa um hash do YAML: mudar o template altera a versão publicada no próximo apply. Isso não atualiza automaticamente as contas existentes; atualize o blueprint dessas contas pelo Control Tower. Este root não mantém um catálogo explícito de todas as versões históricas.

`bootstrap/main.tf` prepara a management no fluxo escolhido. `management-security/account-bootstrap/` permanece como alternativa, em estado separado. O módulo `modules/account_baseline/` permanece reutilizável; as contas criadas pelo Account Factory recebem os recursos pelo template. Não aplique ambos na mesma conta para criar os mesmos recursos. OIDC, role ou bucket preexistentes podem conflitar com o template.

O `10_controltower.tf` está ativo e lê `../landing-zone.json` com `file()`. Nenhuma migração de state foi feita. O `bootstrap/` original também declara bucket e OIDC na management; não duplique a gestão desses objetos no subdiretório `account-bootstrap/`.

Os recursos do blueprint são gerenciados pelo CloudFormation/AFC. Não foi definida retenção na exclusão da stack; remover o blueprint não é uma operação de simples publicação. O bucket versionado com objetos pode impedir a exclusão. Não há chave KMS personalizada, lifecycle de versões, integração Entra/Identity Center ou recursos EKS neste template.

Referências: [configuração do AFC](https://docs.aws.amazon.com/controltower/latest/userguide/afc-setup-steps.html), [role de acesso](https://docs.aws.amazon.com/controltower/latest/userguide/step-1-create-blueprint-access-role.html) e [seleção do blueprint no console](https://docs.aws.amazon.com/controltower/latest/userguide/create-afc-customized-account.html).

## Contrato do root

| Input | Tipo | Padrão/obrigatoriedade |
| --- | --- | --- |
| `aws_region` | `string` | `us-east-2`; deve corresponder à Home Region. |
| `aws_profile` | `string` | `null`; credenciais do ambiente quando não informado. |
| `environment` | `string` | `management-security`. |
| `environment_tags` | `map(string)` | `{}`; provider também define `Environment` e `ManagedBy`. |
| `control_tower_operator_arn` | `string` | Obrigatório; ARN IAM completo do operador do console. |

Outputs: `blueprint_hub_account_id`, `blueprint_product_id`, `blueprint_version` e `blueprint_access_role_arn`. Não há output da landing zone neste root. O `blueprint_version` usa `v-` seguido dos primeiros 12 caracteres do SHA-256 do template; o objeto S3 usa `account-baseline/<versão>.yaml`.

## Manifest e abrangência de segurança

`10_controltower.tf` está ativo com `version = "4.0"` e `manifest_json = file("${path.module}/../landing-zone.json")`. O caminho aponta para o JSON na raiz deste repositório, não para um arquivo dentro de `account-bootstrap/`.

O manifest governa `us-east-2`, habilita Identity Center, logging, Config e security roles; desabilita Backup. Audit é o destino de Config/security roles e Log Archive é o destino de logging. Os buckets de logs e access logs têm retenção configurada em 365 dias, sem chave KMS personalizada. Os IDs ainda são placeholders. As contas de integração precisam estar na mesma OU diretamente sob a raiz. Veja [manifest 4.0](https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-launch.html).

As roles de serviço `AWSControlTowerAdmin`, `AWSControlTowerCloudTrailRole` e `AWSControlTowerStackSetRole`, no path `/service-role/`, não são declaradas aqui nem no bootstrap. O guia genérico também cita a role de agregação antiga, mas ela não é necessária para landing zone 4.0. Referências: [pré-requisitos via API](https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-prereques.html) e [diferença da role de Config em 4.0](https://docs.aws.amazon.com/controltower/latest/userguide/roles-how.html).

Na versão 4.0, Config e CloudTrail usam recursos dedicados separados. No desenho deste manifest, Config fica na Audit e CloudTrail na Log Archive. A agregação não equivale a gravação habilitada em todas as contas: cobertura depende de baselines e OUs registradas. Referência: [AWS Config em 4.0](https://docs.aws.amazon.com/controltower/latest/userguide/config-updates-v4.html).

Não há um recurso separado de criação de contas do Account Factory neste fluxo: Terraform declara a landing zone e publica o produto; o provisionamento das contas usa o console. OUs do Organizations, registro no Control Tower, baseline do Control Tower e blueprint pessoal são conceitos distintos. Não existem SCPs customizadas, GuardDuty, Security Hub ou alertas centrais declarados neste root.

`accessManagement.enabled = true` não configura o Entra ID. Integração SAML/SCIM, permission sets e assignments ainda não estão implementados. OIDC do GitHub é autenticação de automação e não substitui o Identity Center de acesso humano.
