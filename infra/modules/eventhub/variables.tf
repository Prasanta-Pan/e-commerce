variable "prefix" {
  description = "Short prefix used to construct resource names."
  type        = string
}

variable "location" {
  description = "Azure region for the Event Hub namespace."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group in which to create the Event Hub namespace."
  type        = string
}

variable "environment" {
  description = "Environment tag (dev / staging / prod)."
  type        = string
}

variable "sku" {
  description = "Event Hub namespace SKU tier (Basic / Standard / Premium)."
  type        = string
  default     = "Standard"
}

variable "capacity" {
  description = "Number of throughput units (Standard) or processing units (Premium)."
  type        = number
  default     = 1
}

variable "maximum_throughput_units" {
  description = "Upper limit for Auto-Inflate scale-out. Only applies to Standard SKU."
  type        = number
  default     = 5
}

variable "order_events_partition_count" {
  description = "Number of partitions for the order-events hub. Cannot be changed after creation."
  type        = number
  default     = 4
}

variable "order_events_message_retention" {
  description = "Message retention in days for the order-events hub (max 7 for Standard)."
  type        = number
  default     = 7
}
