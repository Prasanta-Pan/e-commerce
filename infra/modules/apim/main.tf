# ============================================================
# modules/apim/main.tf
#
# Creates an Azure API Management instance with:
#   - System-assigned managed identity
#   - Global policy: JWT validation, rate limiting, CORS
#   - Product Service API  (path: /products)
#   - Order Service API    (path: /orders)
# ============================================================

locals {
  apim_name = "${var.prefix}-apim"
}

# ─── APIM Instance ────────────────────────────────────────────────────────────

resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = var.sku_name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ─── Global Policy ────────────────────────────────────────────────────────────
# Applied to every API in this APIM instance.
# Policy order: CORS → JWT validation → rate limiting → forward request.

resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.main.id

  xml_content = <<-XML
    <policies>
      <inbound>
        <!-- CORS: allow the React SPA origin -->
        <cors allow-credentials="true">
          <allowed-origins>
            <origin>${var.ui_origin}</origin>
          </allowed-origins>
          <allowed-methods>
            <method>GET</method>
            <method>POST</method>
            <method>PUT</method>
            <method>DELETE</method>
            <method>PATCH</method>
            <method>OPTIONS</method>
          </allowed-methods>
          <allowed-headers>
            <header>*</header>
          </allowed-headers>
          <expose-headers>
            <header>*</header>
          </expose-headers>
        </cors>

        <!-- JWT validation against Azure AD (Entra ID) OIDC endpoint -->
        <validate-jwt
          header-name="Authorization"
          failed-validation-httpcode="401"
          failed-validation-error-message="Unauthorized: valid Bearer token required"
          require-scheme="Bearer">
          <openid-config url="https://login.microsoftonline.com/${var.tenant_id}/v2.0/.well-known/openid-configuration" />
          <audiences>
            <audience>${var.api_audience}</audience>
          </audiences>
          <issuers>
            <issuer>https://login.microsoftonline.com/${var.tenant_id}/v2.0</issuer>
            <issuer>https://sts.windows.net/${var.tenant_id}/</issuer>
          </issuers>
        </validate-jwt>

        <!-- Rate limiting: 1 000 calls per 60 seconds per subscription key (falls back to IP) -->
        <rate-limit-by-key
          calls="1000"
          renewal-period="60"
          counter-key="@(context.Subscription?.Key ?? context.Request.IpAddress)"
          increment-condition="@(context.Response.StatusCode >= 200 &amp;&amp; context.Response.StatusCode &lt; 300)" />
      </inbound>

      <backend>
        <forward-request />
      </backend>

      <outbound>
        <base />
      </outbound>

      <on-error>
        <base />
      </on-error>
    </policies>
  XML
}

# ─── Product Service API ──────────────────────────────────────────────────────

resource "azurerm_api_management_api" "product_api" {
  name                  = "product-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Product Service API"
  description           = "Manages product catalogue — listing, search, create, update, delete."
  path                  = "products"
  protocols             = ["https"]
  service_url           = var.product_service_url
  subscription_required = false
}

# ─── Order Service API ────────────────────────────────────────────────────────

resource "azurerm_api_management_api" "order_api" {
  name                  = "order-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Order Service API"
  description           = "Handles order placement, status tracking, and payment processing."
  path                  = "orders"
  protocols             = ["https"]
  service_url           = var.order_service_url
  subscription_required = false
}
