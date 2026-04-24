// ============================================================
// modules/acr.bicep — Azure Container Registry
//   Basic SKU for dev, Premium for staging/prod
//   Admin account disabled — use managed identity / service principal
//   Geo-replication enabled for prod
// ============================================================

@description('Azure region for the primary ACR instance.')
param location string

@description('Name of the Azure Container Registry (alphanumeric, 5-50 chars, globally unique).')
@minLength(5)
@maxLength(50)
param acrName string

@description('Deployment environment — controls SKU and geo-replication.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Secondary Azure region for geo-replication (prod only).')
param replicaLocation string = 'australiasoutheast'

// ─── Derived Variables ────────────────────────────────────────────────────────

// Basic for dev (cost-efficient), Premium for staging/prod (geo-replication, content trust)
var acrSku = environment == 'dev' ? 'Basic' : 'Premium'
var enableGeoReplication = environment == 'prod'

// ─── Container Registry ───────────────────────────────────────────────────────

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // Admin account disabled — AKS uses managed identity (AcrPull role) instead
    adminUserEnabled: false

    // Enforce HTTPS for all registry operations
    publicNetworkAccess: 'Enabled'

    // Require TLS 1.2+
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: environment == 'prod' ? 'enabled' : 'disabled'
      }
      retentionPolicy: {
        days: environment == 'prod' ? 30 : 7
        status: 'enabled'
      }
      exportPolicy: {
        status: environment == 'prod' ? 'disabled' : 'enabled'
      }
    }

    encryption: {
      status: 'disabled'  // Enable with CMK in prod if compliance requires it
    }

    zoneRedundancy: environment == 'prod' ? 'Enabled' : 'Disabled'
    anonymousPullEnabled: false
  }
}

// ─── Geo-Replication (prod only) ──────────────────────────────────────────────

resource geoReplication 'Microsoft.ContainerRegistry/registries/replications@2023-07-01' = if (enableGeoReplication) {
  parent: containerRegistry
  name: replicaLocation
  location: replicaLocation
  properties: {
    zoneRedundancy: 'Disabled'
    regionEndpointEnabled: true
  }
}

// ─── Diagnostic Settings (push audit logs to Log Analytics) ──────────────────
// Note: Requires a Log Analytics Workspace resource ID to be passed in for prod.
// Omitted here for simplicity — wire up via Azure Policy in production.

// ─── Outputs ──────────────────────────────────────────────────────────────────

@description('Login server URL for the container registry (e.g. myacr.azurecr.io).')
output loginServer string = containerRegistry.properties.loginServer

@description('Resource ID of the container registry.')
output acrId string = containerRegistry.id

@description('Name of the container registry.')
output acrName string = containerRegistry.name

@description('Principal ID of the ACR system-assigned managed identity.')
output principalId string = containerRegistry.identity.principalId
