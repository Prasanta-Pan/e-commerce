# ─── Environment ──────────────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment tag applied to all new resources."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all NEW resources created by Terraform."
  type        = string
  default     = "australiaeast"
}

variable "prefix" {
  description = "Short prefix (3-8 chars) used to name new resources."
  type        = string
  default     = "ecomm"
  validation {
    condition     = length(var.prefix) >= 3 && length(var.prefix) <= 8
    error_message = "prefix must be between 3 and 8 characters."
  }
}

# ─── Existing Resources (referenced via data sources) ─────────────────────────

variable "resource_group_name" {
  description = "Name of the existing Azure Resource Group that holds the platform resources."
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
  description = "Name of the existing Azure Container Registry (no hyphens)."
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

# ─── Azure AD (used by APIM JWT policy) ───────────────────────────────────────

variable "tenant_id" {
  description = "Azure AD tenant ID. Used in APIM JWT validation policy."
  type        = string
}

variable "api_audience" {
  description = "Azure AD API audience (client ID of the ecommerce-api App Registration)."
  type        = string
}

variable "ui_origin" {
  description = "Allowed CORS origin for the React SPA (e.g. https://shop.contoso.com)."
  type        = string
  default     = "https://shop.contoso.com"
}

# ─── Event Hub ────────────────────────────────────────────────────────────────

variable "eventhub_sku" {
  description = "Event Hub namespace SKU. 'Standard' supports consumer groups and 1-day retention; 'Premium' adds dedicated throughput."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.eventhub_sku)
    error_message = "eventhub_sku must be one of: Basic, Standard, Premium."
  }
}

# ─── API Management ───────────────────────────────────────────────────────────

variable "apim_publisher_email" {
  description = "Email address of the APIM publisher / admin contact."
  type        = string
}

variable "apim_publisher_name" {
  description = "Organisation name shown in the APIM developer portal."
  type        = string
  default     = "E-Commerce Platform"
}

variable "apim_sku_name" {
  description = "APIM SKU. Use 'Developer_1' for dev/staging, 'Standard_1' or 'Premium_1' for production."
  type        = string
  default     = "Developer_1"
}

# ─── Backend Service URLs ──────────────────────────────────────────────────────

variable "product_service_url" {
  description = "Internal Kubernetes DNS URL for the Product Service (used as APIM backend)."
  type        = string
  default     = "http://product-service.default.svc.cluster.local"
}

variable "order_service_url" {
  description = "Internal Kubernetes DNS URL for the Order Service (used as APIM backend)."
  type        = string
  default     = "http://order-service.default.svc.cluster.local"
}
