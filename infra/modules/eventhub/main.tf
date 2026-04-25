# ============================================================
# modules/eventhub/main.tf
#
# Creates an Event Hub namespace, the 'order-events' hub,
# a consumer group for the invoice-service, and send/listen
# authorization rules for order-service and invoice-service.
# ============================================================

locals {
  namespace_name = "${var.prefix}-eventhub-ns"
}

# ─── Event Hub Namespace ──────────────────────────────────────────────────────

resource "azurerm_eventhub_namespace" "main" {
  name                = local.namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  capacity            = var.capacity

  # Auto-inflate allows the namespace to scale up automatically under load.
  # Only supported on Standard SKU; ignored for Basic/Premium.
  auto_inflate_enabled     = var.sku == "Standard" ? true : false
  maximum_throughput_units = var.sku == "Standard" ? var.maximum_throughput_units : null

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ─── order-events Hub ─────────────────────────────────────────────────────────

resource "azurerm_eventhub" "order_events" {
  name                = "order-events"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = var.order_events_partition_count
  message_retention   = var.order_events_message_retention
}

# ─── Consumer Group for Invoice Service ───────────────────────────────────────

resource "azurerm_eventhub_consumer_group" "invoice_processor" {
  name                = "invoice-processor"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.order_events.name
  resource_group_name = var.resource_group_name
}

# ─── Authorization Rule: Order Service (send only) ────────────────────────────

resource "azurerm_eventhub_namespace_authorization_rule" "order_service_sender" {
  name                = "order-service-sender"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name

  listen = false
  send   = true
  manage = false
}

# ─── Authorization Rule: Invoice Service (listen only) ────────────────────────

resource "azurerm_eventhub_namespace_authorization_rule" "invoice_service_listener" {
  name                = "invoice-service-listener"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name

  listen = true
  send   = false
  manage = false
}
