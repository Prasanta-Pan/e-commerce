# ============================================================
# main.tf — Root module
# Wires all child modules together and passes outputs between them.
# ============================================================

# ─── Existing Infrastructure (data sources only — nothing is created here) ────

module "existing_infra" {
  source = "./modules/existing-infra"

  resource_group_name    = var.resource_group_name
  aks_cluster_name       = var.aks_cluster_name
  postgresql_server_name = var.postgresql_server_name
  acr_name               = var.acr_name
  vnet_name              = var.vnet_name
  subnet_name            = var.subnet_name
}

# ─── NEW: Azure Event Hub (replaces Service Bus) ──────────────────────────────

module "eventhub" {
  source = "./modules/eventhub"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = module.existing_infra.resource_group_name
  environment         = var.environment
  sku                 = var.eventhub_sku
}

# ─── NEW: Azure API Management ────────────────────────────────────────────────

module "apim" {
  source = "./modules/apim"

  prefix              = var.prefix
  location            = var.location
  resource_group_name = module.existing_infra.resource_group_name
  environment         = var.environment
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name
  tenant_id           = var.tenant_id
  api_audience        = var.api_audience
  ui_origin           = var.ui_origin
  product_service_url = var.product_service_url
  order_service_url   = var.order_service_url
}
