variable "subnet_ids" {
  type        = list(string)
  description = "Subnet of the AZs"
}

variable "name" {
  type        = string
  description = "Name of the Cluster"

}

variable "version" {
  type        = string
  description = "Version of the Cluster"

}