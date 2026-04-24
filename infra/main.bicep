// ============================================================
// main.bicep — E-Commerce Platform root orchestration template
// Deploys all modules: AKS, PostgreSQL, Service Bus, APIM, ACR
// ============================================================

targetScope = 'resourceGroup'

// ─── Parameters ───────────────────────────────────────────────────────────────

@description('Deployment environment. Controls SKU tiers and replica settings.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short prefix used to name all resources (3-8 alphanumeric chars).')
@minLength(3)
@maxLength(8)
param prefix string = 'ecomm'

@description('Kubernetes version for the AKS cluster.')
param kubernetesVersion string = '1.28.5'

@description('PostgreSQL administrator login username.')
param postgresAdminUser string = 'pgadmin'

@description('PostgreSQL administrator login password.')
@secure()
param postgresAdminPassword string

@description('APIM publisher email address.')
param apimPublisherEmail string

@description('APIM publisher organisation name.')
param apimPublisherName string = 'E-Commerce Platform'

@description('UI origin allowed through CORS (e.g. https://shop.contoso.com).')
param uiOrigin string

@description('Azure AD tenant ID used for JWT validation in APIM.')
param aadTenantId string

@description('Azure AD API application client ID (ecommerce-api app registration).')
param aadApiClientId string

// ─── Variables ────────────────────────────────────────────────────────────────

var resourceSuffix = '${prefix}-${environment}'

// ─── ACR ──────────────────────────────────────────────────────────────────────

module acr 'modules/acr.bicep' = {
  name: 'deploy-acr'
  params: {
    location: location
    acrName: replace('${resourceSuffix}acr', '-', '')
    environment: environment
  }
}

// ─── AKS ──────────────────────────────────────────────────────────────────────

module aks 'modules/aks.bicep' = {
  name: 'deploy-aks'
  params: {
    location: location
    clusterName: '${resourceSuffix}-aks'
    kubernetesVersion: kubernetesVersion
    acrId: acr.outputs.acrId
  }
  dependsOn: [
    acr
  ]
}

// ─── PostgreSQL ───────────────────────────────────────────────────────────────

module postgresql 'modules/postgresql.bicep' = {
  name: 'deploy-postgresql'
  params: {
    location: location
    serverName: '${resourceSuffix}-pg'
    administratorLogin: postgresAdminUser
    administratorLoginPassword: postgresAdminPassword
    environment: environment
  }
}

// ─── Service Bus ──────────────────────────────────────────────────────────────

module serviceBus 'modules/servicebus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    location: location
    namespaceName: '${resourceSuffix}-sb'
    aksClusterPrincipalId: aks.outputs.principalId
  }
  dependsOn: [
    aks
  ]
}

// ─── API Management ───────────────────────────────────────────────────────────

module apim 'modules/apim.bicep' = {
  name: 'deploy-apim'
  params: {
    location: location
    apimName: '${resourceSuffix}-apim'
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    environment: environment
    uiOrigin: uiOrigin
    aadTenantId: aadTenantId
    aadApiClientId: aadApiClientId
    productServiceUrl: 'http://product-service.ecommerce.svc.cluster.local:8080'
    orderServiceUrl: 'http://order-service.ecommerce.svc.cluster.local:8080'
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────

@description('Name of the AKS cluster.')
output aksClusterName string = aks.outputs.clusterName

@description('Login server for Azure Container Registry.')
output acrLoginServer string = acr.outputs.loginServer

@description('FQDN of the primary PostgreSQL server.')
output postgresqlFqdn string = postgresql.outputs.serverFqdn

@description('FQDN of the PostgreSQL read replica (empty in dev).')
output postgresqlReplicaFqdn string = postgresql.outputs.replicaFqdn

@description('Service Bus namespace name.')
output serviceBusNamespace string = serviceBus.outputs.namespaceName

@description('APIM gateway URL.')
output apimGatewayUrl string = apim.outputs.gatewayUrl
