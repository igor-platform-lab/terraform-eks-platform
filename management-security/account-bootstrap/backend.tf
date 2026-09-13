terraform {
  # O bucket ainda não existe na primeira execução.
  # Informe um path diferente para cada conta no terraform init.
  backend "local" {}
}
