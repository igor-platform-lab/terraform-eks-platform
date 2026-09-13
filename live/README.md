# Root Terraform ativo: `live`

Esta pasta é o root Terraform de workloads. Bootstrap e management são roots independentes. A descrição reflete o código em 13/09/2026, sem confirmar provisionamento na AWS. Os comandos `terraform init`, `terraform validate`, `terraform plan` e `terraform apply` devem ser executados aqui.

O root declara um backend S3 parcial em `00_backend.tf`. Bucket, região e chave são fornecidos no `terraform init` por `../environments/dev/backend.hcl` ou `../environments/prod/backend.hcl`; assim, os dois ambientes reutilizam a mesma configuração Terraform e mantêm estados separados.

## Configuração atual

- Provider AWS `~> 6.0`, região obrigatória e profile opcional. Os `.tfvars` locais usam `us-east-2` e profiles `terraform-dev`/`terraform-prod`.
- VPC `10.16.0.0/16` com DNS support e DNS hostnames habilitados.
- Internet Gateway associado à VPC.
- Subnets públicas A/B: `10.16.0.0/20` e `10.16.16.0/20`.
- Subnets privadas A/B: `10.16.32.0/20` e `10.16.48.0/20`.
- Route table própria associada a cada subnet.
- Rota `0.0.0.0/0` das subnets públicas para o Internet Gateway.
- Rota `0.0.0.0/0` das subnets privadas para um NAT Gateway regional público.
- Um único ID de NAT Gateway regional consumido pelas duas subnets privadas.
- Gateway Endpoint do S3 associado às duas route tables privadas.
- Nenhum Interface Endpoint instanciado no root ativo.
- Um SG do EKS com regras de ingress e egress explícitas.
- Um SG do ALB com ingress HTTPS/443 público e egress HTTP/80 para o SG do EKS.
- Um caller de ALB internet-facing posicionado nas duas subnets públicas.
- Um bucket S3 versionado para os access logs do ALB.
- Uma bucket policy limitada à entrega de logs do ALB no caminho da conta atual.
- Um listener HTTPS/443 com ação padrão para um target group HTTP/80 ainda sem targets; o listener ainda não recebe o certificado obrigatório.

As subnets privadas não apontam diretamente para o Internet Gateway. Elas encaminham tráfego externo para o NAT Gateway, que permite conexões iniciadas pelos workloads privados sem aceitar conexões de entrada não solicitadas. Esse caminho atende, entre outros casos, ao polling do Argo CD sobre repositórios no GitHub.

## Decisão de arquitetura

O desenho anterior usava Interface Endpoints para `ecr.api` e `ecr.dkr`. A arquitetura foi alterada para combinar NAT Gateway regional e Gateway Endpoint do S3 com os seguintes objetivos:

- oferecer saída genérica para o GitHub e outros endpoints públicos consumidos por workloads e add-ons;
- evitar criar e manter um Interface Endpoint diferente para cada serviço AWS necessário;
- simplificar rotas, security groups e dependências entre módulos;
- reduzir as cobranças fixas dos Interface Endpoints por endpoint e por Availability Zone.

O NAT Gateway também é cobrado por hora em cada AZ atendida pelo modo regional e por volume processado. A mudança não elimina custos de rede; ela troca uma arquitetura de acesso privado específico por serviço por uma saída compartilhada e mais flexível. O custo deve ser acompanhado conforme o volume real.

> [!decision]
> O Gateway Endpoint do S3 foi mantido porque não possui cobrança adicional. Sua rota específica evita que tráfego S3 passe pelo NAT e incorra na cobrança de processamento do NAT, enquanto os demais destinos continuam usando o egress regional.

Referências: [Interface VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html), [Gateway Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html) e [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

## Roteamento

Cada subnet possui uma route table própria. A mesma rede de destino pode aparecer em route tables diferentes com alvos distintos:

| Route table | Rota default | Finalidade |
| --- | --- | --- |
| Pública A | `0.0.0.0/0 → Internet Gateway` | Saída direta dos recursos públicos. |
| Pública B | `0.0.0.0/0 → Internet Gateway` | Saída direta dos recursos públicos. |
| Privada A | `0.0.0.0/0 → NAT regional` e prefix list S3 → Gateway Endpoint | NAT para egress geral; endpoint para S3. |
| Privada B | `0.0.0.0/0 → NAT regional` e prefix list S3 → Gateway Endpoint | NAT para egress geral; endpoint para S3. |

O NAT regional é associado diretamente à VPC e não recebe `subnet_id`. A AWS gerencia sua expansão entre Availability Zones e a route table própria com o caminho até o Internet Gateway.

```text
subnet-public-a/b  ──0.0.0.0/0──> Internet Gateway

subnet-private-a/b ──0.0.0.0/0──> NAT Gateway regional
                                          │
                                          └──> Internet Gateway ──> Internet

subnet-private-a/b ──prefix list S3──> Gateway Endpoint S3
```

A rota da prefix list do S3 é mais específica que `0.0.0.0/0` e, por longest prefix match, tem precedência sobre o NAT para destinos do S3. Rotas e security groups cumprem funções diferentes: a route table define o caminho; regras de egress, network ACLs e políticas aplicáveis autorizam o tráfego.

## Mapa de arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `00_backend.tf` | Declara o backend S3 parcial, preenchido pelo `backend.hcl` do ambiente durante o `init`. |
| `00_providers.tf` | Provider AWS, versão `~> 6.0`, região e profile. |
| `00_variables.tf` | Variáveis `environment_tags` e `environment`. |
| `00_data.tf` | Availability Zones, região e identidade da conta atual. |
| `00_output.tf` | Output com o ID do Internet Gateway. |
| `01_vpc.tf` | Módulo VPC e Internet Gateway. |
| `01_nat.tf` | Instância do NAT Gateway regional. |
| `01_subnet.tf` | Duas subnets públicas, duas privadas e seus destinos de rota. |
| `02_sg_engress_eks.tf` | SG do EKS e regras de egress para DNS, HTTPS público e S3. |
| `02_sg_ingress_eks.tf` | Regra de ingress do EKS proveniente do SG do ALB. |
| `03_endpoint_gateway.tf` | Gateway Endpoint do S3 nas route tables privadas. |
| `04_alb.tf` | ALB internet-facing, listener, target group, SG do ALB e regras de ingress/egress. |
| `05_s3.tf` | Bucket versionado e bucket policy dos access logs do ALB. |

O arquivo `03_endpoint_interface.tf` foi retirado do root ativo. O módulo reutilizável continua disponível em `../modules/endpoint_interface`.

## Estado remoto e automação

Os arquivos de ambiente ficam fora deste root e são selecionados explicitamente:

| Ambiente | Backend config | Var file | Chave S3 |
| --- | --- | --- | --- |
| `dev` | `../environments/dev/backend.hcl` | `../environments/dev/dev.tfvars` | `dev/live.tfstate` |
| `prod` | `../environments/prod/backend.hcl` | `../environments/prod/prod.tfvars` | `prod/live.tfstate` |

O bucket `meu-bucket-tfstate` presente nos dois `backend.hcl` é um placeholder e precisa ser substituído por um bucket já existente. Os `.tfvars` locais já contêm região, profile, ambiente e tags correspondentes a dev/prod, mas são ignorados pelo Git. O runner precisa receber arquivos de variáveis disponíveis no checkout ou por outro mecanismo; os arquivos locais não aparecem automaticamente no GitHub.

O workflow `../.github/workflows/terraform.yaml` executa a partir deste diretório. Pull requests para `develop` usam o GitHub Environment `dev`; pull requests para `main` usam `prod`. Pushes nessas branches tentam executar `apply tfplan`, mas o job não gera nem baixa esse arquivo. O plan do PR não salva nem publica um plano. Os environments precisam fornecer:

- `AWS_ROLE_ARN`: role assumida pelo runner via OIDC;
- `BACKEND_CONFIG`: caminho relativo a `live`, como `../environments/prod/backend.hcl`;
- `TFVARS_FILE`: caminho relativo a `live`, como `../environments/prod/prod.tfvars`.

O provider usa `aws_profile`, cujo padrão é `null`. Os profiles nomeados dos arquivos locais dependem de configuração na máquina; no runner OIDC, o valor efetivo deve permitir usar as credenciais do job. O backend usa sua própria autenticação. O bootstrap da management confia em subject de branch; os jobs de dev/prod usam subjects de environment e roles das respectivas contas.

## Fluxo de dependências

```text
module.vpc
├── aws_internet_gateway.internet_gateway
├── module.nat_gateway
├── module.subnet-public-a/b
├── module.subnet-private-a/b
│       ├── module.nat_gateway.nat_id
│       └── module.s3_gateway via route_table_id
├── module.sg_eks
│       ├── ingress HTTP/80 a partir de module.sg_alb
│       ├── egress DNS UDP/TCP e HTTPS público
│       └── module.egress_s3_gateway via prefix_list_id
├── module.sg_alb
│       ├── ingress HTTPS de 0.0.0.0/0
│       └── egress HTTP/80 para module.sg_eks
├── module.s3_alb
│       ├── aws_s3_bucket_versioning
│       ├── aws_s3_bucket_server_side_encryption_configuration
│       ├── aws_s3_bucket_public_access_block
│       └── aws_s3_bucket_policy.alb_access_logs
└── module.alb_internet_facing
        ├── module.subnet-public-a/b
        ├── module.sg_alb
        └── module.s3_alb via access_logs

module.alb_internet_facing.alb_arn ──> module.alb_listener
module.alb_target_group.target_group_arn ──> module.alb_listener
module.vpc.vpc_id ──> module.alb_target_group
```

- `module.nat_gateway` recebe `module.vpc.vpc_id` e declara dependência do Internet Gateway.
- As subnets públicas recebem `aws_internet_gateway.internet_gateway.id`.
- As subnets privadas recebem `module.nat_gateway.nat_id`.
- `module.s3_gateway` recebe os `route_table_id` das duas subnets privadas.
- `module.egress_s3_gateway` recebe `module.s3_gateway.prefix_list_id`.
- `aws_s3_bucket_policy.alb_access_logs` usa o ARN de `module.s3_alb` e limita a escrita ao caminho `AWSLogs/<account-id>/*`.
- `module.alb_internet_facing` aguarda a bucket policy antes de habilitar os access logs.
- `module.alb_listener` recebe o ARN do ALB e o ARN de `module.alb_target_group`, criando dependências implícitas com ambos.
- `module.alb_target_group` recebe `module.vpc.vpc_id`; ainda não existem target attachments.
- As referências a outputs criam dependências implícitas entre VPC, NAT, subnets, endpoint e regra de egress.

## Módulos instanciados

### VPC e Internet Gateway

`module.vpc` cria a VPC. O recurso `aws_internet_gateway.internet_gateway` é associado a essa VPC e serve como destino das rotas públicas e como caminho externo do NAT regional.

### NAT Gateway regional

`module.nat_gateway` cria um NAT Gateway com:

```hcl
availability_mode = "regional"
connectivity_type = "public"
```

O módulo recebe `vpc_id` e `tags`, e exporta `nat_id`. No modo regional automático atual, o caller não informa subnet nem Elastic IP.

### Subnets

- `module.subnet-public-a` e `module.subnet-public-b` criam subnets públicas e direcionam `0.0.0.0/0` ao Internet Gateway.
- `module.subnet-private-a` e `module.subnet-private-b` criam subnets privadas e direcionam `0.0.0.0/0` ao NAT Gateway regional.

Cada módulo de subnet exporta `subnet_id` e `route_table_id`.

### Gateway Endpoint do S3

`module.s3_gateway` instancia `endpoint_gateway` para `com.amazonaws.us-east-2.s3` e associa o endpoint às duas route tables privadas. O output `prefix_list_id` é consumido pela regra de egress HTTPS específica para S3.

O Gateway Endpoint não cria ENIs nem possui SG próprio. A route table direciona o tráfego pela prefix list, enquanto o SG cliente permite TCP/443 para essa mesma prefix list.

### Interface Endpoints preservados

O módulo `endpoint_interface` não é instanciado neste root, mas permanece no repositório. Ele pode ser reutilizado se surgir requisito de tráfego privado, restrição de egress ou compliance. A reativação exige restaurar callers, SG das ENIs e regras de entrada e saída compatíveis.

### Security groups

`module.sg_eks` e `module.sg_alb` usam o mesmo módulo genérico `security_group`. A separação ocorre por recurso protegido, não por direção de tráfego: cada SG pode receber regras de ingress e egress.

O módulo `security_group_egress_rule` é instanciado quatro vezes para o SG do EKS:

- UDP/53 para o resolver da VPC em `10.16.0.2/32`;
- TCP/53 para o resolver da VPC em `10.16.0.2/32`;
- TCP/443 para `0.0.0.0/0`, usando o NAT como caminho de rede;
- TCP/443 para a prefix list do Gateway Endpoint do S3.

Cada regra seleciona seu destino por `destination_type`: `cidr_ipv4`, `prefix_list` ou `security_group`. O NAT Gateway não é destino do SG; a regra HTTPS autoriza os endereços externos e a route table encaminha esse tráfego ao NAT.

O SG do ALB permite ingress TCP/443 de `0.0.0.0/0` e egress TCP/80 para o SG do EKS. O SG do EKS aceita TCP/80 cuja origem seja o SG do ALB. Esse conjunto implementa HTTPS até o ALB e HTTP restrito pelos SGs no caminho interno até os workloads. As respostas são tratadas de forma stateful pelos security groups.

### Application Load Balancer

`module.alb_internet_facing` configura o ALB com `internal = false`, associa as duas subnets públicas, usa `module.sg_alb` e habilita access logs no bucket `module.s3_alb`.

`module.alb_listener` declara um listener HTTPS/443 cuja ação padrão encaminha para `module.alb_target_group`. O target group `eks-workloads-http` usa HTTP/80 e pertence à VPC ativa, implementando terminação TLS no ALB e encaminhamento interno sem TLS.

O caminho ainda não está operacional: o caller não informa `certificate_arn` ao listener HTTPS e o target group ainda não possui targets associados. Os nodes e pods do EKS também ainda não existem no root ativo. As regras dos SGs já correspondem ao fluxo externo HTTPS/443 e interno HTTP/80.

### Bucket de access logs do ALB

`module.s3_alb` cria um bucket na região atual com versionamento `Enabled`, SSE-S3 e os quatro bloqueios de acesso público. O nome combina produto, ambiente, região e account ID para reduzir colisões globais.

`aws_s3_bucket_policy.alb_access_logs` concede somente `s3:PutObject` ao principal `logdelivery.elasticloadbalancing.amazonaws.com`, restrito ao caminho `AWSLogs/<account-id>/*`. O `depends_on` do caller do ALB garante que a AWS encontre essa policy quando testar a entrega dos logs.

## Estado da configuração

> [!note]
> O ALB declara listener HTTPS/443 e target group HTTP/80. Os security groups estão alinhados a esse fluxo, mas o listener ainda não recebe um certificado e o target group não possui associação de targets; portanto, o caminho ainda não está operacional.

## Comandos

```bash
export AWS_PROFILE=terraform-dev
terraform init -reconfigure -backend-config=../environments/dev/backend.hcl
terraform fmt -recursive
terraform validate
terraform plan -var-file=../environments/dev/dev.tfvars -out=tfplan
terraform apply tfplan
```

Para produção, substitua os dois caminhos de `dev` pelos equivalentes em `prod`. Confirme o workspace, a conta AWS e a chave do backend antes de qualquer `apply`.

Revise o `terraform plan` antes do apply para confirmar:

- eventuais remoções de Interface Endpoints apenas se ainda existirem no estado dessa conta;
- criação do NAT Gateway regional;
- rotas públicas apontando para o Internet Gateway;
- rotas privadas apontando para o NAT Gateway;
- preservação do Gateway Endpoint do S3 nas duas route tables privadas;
- egress DNS UDP/TCP, HTTPS público e HTTPS para a prefix list do S3.
- ALB associado somente às duas subnets públicas e ao SG do ALB.
- ingress do EKS limitado à origem `module.sg_alb` na porta 80.
- bucket S3 versionado, na mesma região do ALB, com policy de entrega restrita à conta atual.
- listener HTTPS/443 com certificado ACM válido e target group HTTP/80 com targets compatíveis.

## Limitações atuais

- O cluster EKS ainda não está definido neste root.
- O SG do EKS ainda não está associado a nodes ou pods reais.
- O target group do ALB ainda não possui targets associados nem health check customizado.
- O listener HTTPS/443 ainda não recebe o `certificate_arn` obrigatório do ACM.
- O bucket de access logs ainda não possui lifecycle de retenção/expiração.
- O NAT regional simplifica HA, mas possui cobrança horária por AZ atendida e por volume processado.
- O Gateway Endpoint reduz processamento do NAT para S3, mas ainda não possui policy customizada.
- A tag interna `Purpose = "eks-interface-endpoints"` do NAT não representa sua finalidade atual.
- Não existem network ACLs customizadas no projeto.
- A região está declarada no provider, mas alguns módulos ainda possuem valores regionais fixos.
- Os arquivos de `environments/dev` e `environments/prod` ainda não são roots Terraform independentes.
- O bucket dos arquivos `backend.hcl` ainda é um placeholder e não há configuração explícita de locking no backend.
- Os `.tfvars` locais têm valores por ambiente, mas não são versionados e não estão automaticamente disponíveis no runner.
- GitHub Environments, variáveis e assignments de acesso não são gerenciados aqui. O blueprint declara a role OIDC nas contas novas; sua implantação real não foi confirmada.
- O job de apply não produz nem recebe o `tfplan` que tenta aplicar.
- Profiles nomeados nos `.tfvars` locais não existem por padrão no runner OIDC.
- Os módulos `eks_cluster` e `eks_access` estão disponíveis, mas não são chamados por este root.
- O target group usa o tipo padrão `instance`; não há integração implementada com pods nem controller.
- LocalStack saiu do fluxo escolhido, mas suas opções continuam no provider; o fluxo AWS pressupõe `localstack_enabled = false`.
