variable "prefix" {
  description = "Short prefix used to construct resource names."
  type        = string
}

variable "location" {
  description = "Azure region for the APIM instance."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group in which to create the APIM instance."
  type        = string
}

variable "environment" {
  description = "Environment tag (dev / staging / prod)."
  type        = string
}

variable "publisher_name" {
  description = "Organisation name displayed in the APIM developer portal."
  type        = string
}

variable "publisher_email" {
  description = "Contact email for the APIM publisher / admin."
  type        = string
}

variable "sku_name" {
  description = "APIM pricing tier. Format: '<Tier>_<Units>' e.g. 'Developer_1', 'Standard_1', 'Premium_1'."
  type        = string
  default     = "Developer_1"
}

variable "tenant_id" {
  description = "Azure AD tenant ID used in the JWT validation OpenID config URL."
  type        = string
}

variable "api_audience" {
  description = "Expected audience in the JWT (client ID of the ecommerce-api App Registration)."
  type        = string
}

variable "ui_origin" {
  description = "Allowed CORS origin for the React SPA (e.g. https://shop.contoso.com)."
  type        = string
}

variable "product_service_url" {
  description = "Internal K8s service URL for the Product Service backend."
  type        = string
}

variable "order_service_url" {
  description = "Internal K8s service URL for the Order Service backend."
  type        = string
}
