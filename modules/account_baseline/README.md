# Account baseline

Módulo Terraform para conta existente: bucket de estado versionado e privado com SSE-S3, OIDC do GitHub e role de deploy com subjects exatos e policies explícitas.

O contrato completo de inputs, outputs, dependências, exemplo e limitações está no [catálogo de módulos](../../README.md#account_baseline).

Seu caller é a [alternativa account-bootstrap](../../management-security/account-bootstrap/README.md), preservada fora do fluxo escolhido. A management será preparada por [bootstrap/main.tf](../../bootstrap/README.md). Contas de workloads criadas pelo console recebem recursos equivalentes pelo [template CloudFormation AFC](../../management-security/templates/account-baseline.yaml), que não executa este módulo.
