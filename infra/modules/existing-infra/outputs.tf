# ─── Resource Group ───────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the existing resource group."
  value       = data.azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the existing resource group."
  value       = data.azurerm_resource_group.main.location
}

# ─── AKS ──────────────────────────────────────────────────────────────────────

output "aks_cluster_name" {
  description = "Name of the existing AKS cluster."
  value       = data.azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "Resource ID of the existing AKS cluster."
  value       = data.azurerm_kubernetes_cluster.aks.id
}

output "aks_kubelet_identity_object_id" {
  description = "Object ID of the AKS kubelet managed identity (useful for RBAC assignments)."
  value       = data.azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# ─── PostgreSQL ───────────────────────────────────────────────────────────────

output "postgresql_fqdn" {
  description = "Fully-qualified domain name of the PostgreSQL Flexible Server."
  value       = data.azurerm_postgresql_flexible_server.postgres.fqdn
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server."
  value       = data.azurerm_postgresql_flexible_server.postgres.name
}

# ─── ACR ──────────────────────────────────────────────────────────────────────

output "acr_login_server" {
  description = "Login server FQDN for the Azure Container Registry."
  value       = data.azurerm_container_registry.acr.login_server
}

output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = data.azurerm_container_registry.acr.id
}

# ─── VNet / Subnet ────────────────────────────────────────────────────────────

output "vnet_id" {
  description = "Resource ID of the existing Virtual Network."
  value       = data.azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  description = "Name of the existing Virtual Network."
  value       = data.azurerm_virtual_network.vnet.name
}

output "aks_subnet_id" {
  description = "Resource ID of the AKS subnet."
  value       = data.azurerm_subnet.aks_subnet.id
}
