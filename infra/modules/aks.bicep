// ============================================================
// modules/aks.bicep — Azure Kubernetes Service cluster
// ============================================================

@description('Azure region for the AKS cluster.')
param location string

@description('Name of the AKS cluster.')
param clusterName string

@description('Kubernetes version.')
param kubernetesVersion string = '1.28.5'

@description('Resource ID of the ACR to attach (AcrPull role granted to kubelet identity).')
param acrId string

@description('VM SKU for the system node pool.')
param systemNodeVmSize string = 'Standard_D2s_v3'

@description('Minimum node count for the system pool autoscaler.')
@minValue(1)
param systemNodeMinCount int = 2

@description('Maximum node count for the system pool autoscaler.')
@maxValue(20)
param systemNodeMaxCount int = 10

// ─── AKS Cluster ──────────────────────────────────────────────────────────────

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-08-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    kubernetesVersion: kubernetesVersion
    dnsPrefix: clusterName
    enableRBAC: true

    // Azure AD / Entra ID integration
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }

    // OIDC issuer for workload identity (federated credentials)
    oidcIssuerProfile: {
      enabled: true
    }

    // Workload identity webhook
    securityProfile: {
      workloadIdentity: {
        enabled: true
      }
    }

    agentPoolProfiles: [
      {
        name: 'system'
        mode: 'System'
        vmSize: systemNodeVmSize
        count: systemNodeMinCount
        minCount: systemNodeMinCount
        maxCount: systemNodeMaxCount
        enableAutoScaling: true
        osDiskSizeGB: 128
        osDiskType: 'Managed'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        type: 'VirtualMachineScaleSets'
        availabilityZones: [
          '1'
          '2'
          '3'
        ]
        nodeTaints: []
        upgradeSettings: {
          maxSurge: '33%'
        }
      }
    ]

    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'Standard'
      outboundType: 'loadBalancer'
    }

    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }

    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        config: {
          enableSecretRotation: 'true'
          rotationPollInterval: '2m'
        }
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: logAnalyticsWorkspace.id
        }
      }
    }
  }
}

// ─── Log Analytics Workspace (for AKS monitoring) ─────────────────────────────

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${clusterName}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ─── AcrPull Role Assignment (kubelet identity → ACR) ─────────────────────────

var acrPullRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull built-in role
)

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aksCluster.id, acrId, acrPullRoleDefinitionId)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: acrPullRoleDefinitionId
    principalId: aksCluster.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────

@description('Name of the AKS cluster.')
output clusterName string = aksCluster.name

@description('Principal ID of the AKS system-assigned managed identity (control plane).')
output principalId string = aksCluster.identity.principalId

@description('OIDC issuer URL for workload identity federation.')
output oidcIssuerUrl string = aksCluster.properties.oidcIssuerProfile.issuerURL

@description('Resource ID of the Log Analytics Workspace.')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
