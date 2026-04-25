output "namespace_name" {
  description = "Name of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.main.name
}

output "namespace_id" {
  description = "Resource ID of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.main.id
}

output "order_events_name" {
  description = "Name of the order-events Event Hub."
  value       = azurerm_eventhub.order_events.name
}

output "order_events_id" {
  description = "Resource ID of the order-events Event Hub."
  value       = azurerm_eventhub.order_events.id
}

output "invoice_processor_consumer_group_name" {
  description = "Name of the invoice-processor consumer group."
  value       = azurerm_eventhub_consumer_group.invoice_processor.name
}

output "sender_connection_string" {
  description = "Primary connection string for the order-service-sender authorization rule (send only). Treat as a secret."
  value       = azurerm_eventhub_namespace_authorization_rule.order_service_sender.primary_connection_string
  sensitive   = true
}

output "listener_connection_string" {
  description = "Primary connection string for the invoice-service-listener authorization rule (listen only). Treat as a secret."
  value       = azurerm_eventhub_namespace_authorization_rule.invoice_service_listener.primary_connection_string
  sensitive   = true
}
