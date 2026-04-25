# ============================================================
# modules/existing-infra/main.tf
#
# ALL blocks here are `data` sources — Terraform reads the existing
# Azure resources but does NOT create, modify, or destroy them.
# If you later want Terraform to fully manage any of these resources,
# use `terraform import` (see root README.md for commands).
# ============================================================

# ─── Resource Group ───────────────────────────────────────────────────────────

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# ─── AKS ──────────────────────────────────────────────────────────────────────

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# ─── PostgreSQL Flexible Server ───────────────────────────────────────────────

data "azurerm_postgresql_flexible_server" "postgres" {
  name                = var.postgresql_server_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# ─── Azure Container Registry ─────────────────────────────────────────────────

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# ─── Virtual Network ──────────────────────────────────────────────────────────

data "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# ─── AKS Subnet ───────────────────────────────────────────────────────────────

data "azurerm_subnet" "aks_subnet" {
  name                 = var.subnet_name
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_resource_group.main.name
}
