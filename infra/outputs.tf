# ─── Existing Resources (read from data sources) ──────────────────────────────

output "aks_cluster_name" {
  description = "Name of the existing AKS cluster (from data source)."
  value       = module.existing_infra.aks_cluster_name
}

output "acr_login_server" {
  description = "Login server FQDN of the existing Azure Container Registry."
  value       = module.existing_infra.acr_login_server
}

output "postgresql_fqdn" {
  description = "FQDN of the existing PostgreSQL Flexible Server primary."
  value       = module.existing_infra.postgresql_fqdn
}

output "vnet_id" {
  description = "Resource ID of the existing Virtual Network."
  value       = module.existing_infra.vnet_id
}

output "aks_subnet_id" {
  description = "Resource ID of the existing AKS subnet."
  value       = module.existing_infra.aks_subnet_id
}

# ─── Event Hub ────────────────────────────────────────────────────────────────

output "eventhub_namespace_name" {
  description = "Name of the newly created Event Hub namespace."
  value       = module.eventhub.namespace_name
}

output "eventhub_namespace_id" {
  description = "Resource ID of the Event Hub namespace."
  value       = module.eventhub.namespace_id
}

output "eventhub_order_events_name" {
  description = "Name of the 'order-events' Event Hub."
  value       = module.eventhub.order_events_name
}

output "eventhub_sender_connection_string" {
  description = "Connection string for the order-service (send-only) authorization rule."
  value       = module.eventhub.sender_connection_string
  sensitive   = true
}

output "eventhub_listener_connection_string" {
  description = "Connection string for the invoice-service (listen-only) authorization rule."
  value       = module.eventhub.listener_connection_string
  sensitive   = true
}

# ─── API Management ───────────────────────────────────────────────────────────

output "apim_gateway_url" {
  description = "Public HTTPS gateway URL for the APIM instance."
  value       = module.apim.gateway_url
}

output "apim_name" {
  description = "Name of the newly created APIM instance."
  value       = module.apim.apim_name
}

output "apim_principal_id" {
  description = "Object ID of the APIM system-assigned managed identity."
  value       = module.apim.principal_id
}
