variable "resource_group_name" {
  description = "Name of the existing Azure Resource Group."
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the existing AKS cluster."
  type        = string
}

variable "postgresql_server_name" {
  description = "Name of the existing PostgreSQL Flexible Server."
  type        = string
}

variable "acr_name" {
  description = "Name of the existing Azure Container Registry."
  type        = string
}

variable "vnet_name" {
  description = "Name of the existing Virtual Network."
  type        = string
}

variable "subnet_name" {
  description = "Name of the existing subnet used by AKS node pools."
  type        = string
}
