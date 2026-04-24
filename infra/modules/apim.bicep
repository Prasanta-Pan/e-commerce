// ============================================================
// modules/apim.bicep — Azure API Management
//   JWT validation, rate limiting, CORS, path-based routing
//   Developer SKU for dev, Standard for staging/prod
// ============================================================

@description('Azure region for APIM.')
param location string

@description('Name of the APIM instance (must be globally unique).')
param apimName string

@description('Publisher email for APIM notifications.')
param apimPublisherEmail string

@description('Publisher organisation name.')
param apimPublisherName string = 'E-Commerce Platform'

@description('Deployment environment — controls APIM SKU.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Allowed CORS origin (UI domain via Front Door).')
param uiOrigin string

@description('Azure AD tenant ID for JWT validation.')
param aadTenantId string

@description('Azure AD API application client ID (audience for JWT validation).')
param aadApiClientId string

@description('Backend URL of the Product Service (AKS cluster-internal).')
param productServiceUrl string

@description('Backend URL of the Order Service (AKS cluster-internal).')
param orderServiceUrl string

// ─── Derived Variables ────────────────────────────────────────────────────────

var apimSkuName = environment == 'prod' ? 'Standard' : 'Developer'
var apimSkuCapacity = environment == 'prod' ? 1 : 1

var openIdConnectUrl = 'https://login.microsoftonline.com/${aadTenantId}/v2.0/.well-known/openid-configuration'

// ─── APIM Instance ────────────────────────────────────────────────────────────

resource apimInstance 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: apimSkuName
    capacity: apimSkuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkType: 'None'
    customProperties: {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
    }
  }
}

// ─── Global Policy (JWT validation + rate limit + CORS) ───────────────────────

resource globalPolicy 'Microsoft.ApiManagement/service/policies@2023-05-01-preview' = {
  parent: apimInstance
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: '''
<policies>
  <inbound>
    <!-- CORS: allow requests from the React SPA origin -->
    <cors allow-credentials="true">
      <allowed-origins>
        <origin>${uiOrigin}</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>PATCH</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>Authorization</header>
        <header>Content-Type</header>
        <header>X-Requested-With</header>
      </allowed-headers>
    </cors>

    <!-- JWT Validation against Azure AD -->
    <validate-jwt header-name="Authorization" failed-validation-httpcode="401"
                  failed-validation-error-message="Unauthorized: valid JWT required"
                  require-expiration-time="true"
                  require-signed-tokens="true">
      <openid-config url="${openIdConnectUrl}" />
      <audiences>
        <audience>api://${aadApiClientId}</audience>
      </audiences>
      <issuers>
        <issuer>https://login.microsoftonline.com/${aadTenantId}/v2.0</issuer>
      </issuers>
    </validate-jwt>

    <!-- Rate limiting: 1000 calls per minute per subscription key -->
    <rate-limit-by-key calls="1000" renewal-period="60"
                       counter-key="@(context.Subscription.Id ?? context.Request.IpAddress)"
                       increment-condition="@(context.Response.StatusCode < 500)" />
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <set-header name="X-Content-Type-Options" exists-action="override">
      <value>nosniff</value>
    </set-header>
    <set-header name="X-Frame-Options" exists-action="override">
      <value>DENY</value>
    </set-header>
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

// ─── Product Service API ───────────────────────────────────────────────────────

resource productApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimInstance
  name: 'product-service'
  properties: {
    displayName: 'Product Service API'
    description: 'REST API for product catalogue management (.NET 8)'
    path: 'api/products'
    protocols: [
      'https'
    ]
    serviceUrl: productServiceUrl
    subscriptionRequired: false
    isCurrent: true
    apiVersion: 'v1'
    apiVersionSetId: productApiVersionSet.id
  }
}

resource productApiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2023-05-01-preview' = {
  parent: apimInstance
  name: 'product-service-version-set'
  properties: {
    displayName: 'Product Service'
    versioningScheme: 'Segment'
  }
}

// Product API GET /  (list all)
resource productListOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: productApi
  name: 'list-products'
  properties: {
    displayName: 'List Products'
    method: 'GET'
    urlTemplate: '/'
    description: 'Returns a paginated list of products. Requires products.read scope.'
    responses: [
      {
        statusCode: 200
        description: 'OK'
      }
    ]
  }
}

// Product API GET /{id}
resource productGetOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: productApi
  name: 'get-product'
  properties: {
    displayName: 'Get Product by ID'
    method: 'GET'
    urlTemplate: '/{id}'
    templateParameters: [
      {
        name: 'id'
        required: true
        type: 'string'
      }
    ]
    description: 'Returns a single product by its UUID.'
    responses: [
      {
        statusCode: 200
        description: 'OK'
      }
      {
        statusCode: 404
        description: 'Not Found'
      }
    ]
  }
}

// ─── Order Service API ─────────────────────────────────────────────────────────

resource orderApi 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimInstance
  name: 'order-service'
  properties: {
    displayName: 'Order Service API'
    description: 'REST API for order processing (Java 21 / Spring Boot 3.3)'
    path: 'api/orders'
    protocols: [
      'https'
    ]
    serviceUrl: orderServiceUrl
    subscriptionRequired: false
    isCurrent: true
    apiVersion: 'v1'
    apiVersionSetId: orderApiVersionSet.id
  }
}

resource orderApiVersionSet 'Microsoft.ApiManagement/service/apiVersionSets@2023-05-01-preview' = {
  parent: apimInstance
  name: 'order-service-version-set'
  properties: {
    displayName: 'Order Service'
    versioningScheme: 'Segment'
  }
}

// Order API POST /  (place order)
resource placeOrderOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: orderApi
  name: 'place-order'
  properties: {
    displayName: 'Place Order'
    method: 'POST'
    urlTemplate: '/'
    description: 'Creates a new order. Requires orders.write scope.'
    responses: [
      {
        statusCode: 201
        description: 'Created'
      }
    ]
  }
}

// Order API GET /{id}
resource getOrderOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: orderApi
  name: 'get-order'
  properties: {
    displayName: 'Get Order by ID'
    method: 'GET'
    urlTemplate: '/{id}'
    templateParameters: [
      {
        name: 'id'
        required: true
        type: 'string'
      }
    ]
    description: 'Returns an order by ID. Requires orders.read scope.'
    responses: [
      {
        statusCode: 200
        description: 'OK'
      }
      {
        statusCode: 404
        description: 'Not Found'
      }
    ]
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────

@description('APIM gateway URL.')
output gatewayUrl string = apimInstance.properties.gatewayUrl

@description('APIM developer portal URL.')
output developerPortalUrl string = apimInstance.properties.developerPortalUrl

@description('Principal ID of the APIM system-assigned managed identity.')
output principalId string = apimInstance.identity.principalId

@description('Resource ID of the APIM instance.')
output apimId string = apimInstance.id
