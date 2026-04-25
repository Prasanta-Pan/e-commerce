output "apim_name" {
  description = "Name of the APIM instance."
  value       = azurerm_api_management.main.name
}

output "apim_id" {
  description = "Resource ID of the APIM instance."
  value       = azurerm_api_management.main.id
}

output "gateway_url" {
  description = "Public HTTPS gateway URL — all API calls are routed through this endpoint."
  value       = azurerm_api_management.main.gateway_url
}

output "portal_url" {
  description = "URL of the APIM developer portal."
  value       = azurerm_api_management.main.developer_portal_url
}

output "principal_id" {
  description = "Object ID of the APIM system-assigned managed identity. Use this to assign Key Vault / ACR roles."
  value       = azurerm_api_management.main.identity[0].principal_id
}

output "product_api_id" {
  description = "Resource ID of the Product Service API in APIM."
  value       = azurerm_api_management_api.product_api.id
}

output "order_api_id" {
  description = "Resource ID of the Order Service API in APIM."
  value       = azurerm_api_management_api.order_api.id
}
