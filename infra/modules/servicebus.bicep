// ============================================================
// modules/servicebus.bicep — Azure Service Bus
//   Standard-tier namespace, order-events topic,
//   invoice-processor subscription
// ============================================================

@description('Azure region for the Service Bus namespace.')
param location string

@description('Name of the Service Bus namespace (must be globally unique).')
param namespaceName string

@description('Principal ID of the AKS cluster managed identity (granted Azure Service Bus Data Receiver).')
param aksClusterPrincipalId string

// ─── Namespace ────────────────────────────────────────────────────────────────

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    minimumTlsVersion: '1.2'
    disableLocalAuth: false  // Set true in prod and rely solely on managed identity
    zoneRedundant: false
  }
}

// ─── Topic: order-events ──────────────────────────────────────────────────────

resource orderEventsTopic 'Microsoft.ServiceBus/namespaces/topics@2023-01-01-preview' = {
  parent: serviceBusNamespace
  name: 'order-events'
  properties: {
    defaultMessageTimeToLive: 'P7D'          // 7 days
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: true
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    enableBatchedOperations: true
    enablePartitioning: false
    supportOrdering: true
  }
}

// ─── Subscription: invoice-processor ─────────────────────────────────────────

resource invoiceProcessorSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2023-01-01-preview' = {
  parent: orderEventsTopic
  name: 'invoice-processor'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'                       // 5-minute lock duration
    defaultMessageTimeToLive: 'P7D'
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: true
    enableBatchedOperations: true
    requiresSession: false
  }
}

// ─── Subscription filter: only order.placed events ───────────────────────────

resource invoiceProcessorFilter 'Microsoft.ServiceBus/namespaces/topics/subscriptions/rules@2023-01-01-preview' = {
  parent: invoiceProcessorSubscription
  name: 'OrderPlacedFilter'
  properties: {
    filterType: 'CorrelationFilter'
    correlationFilter: {
      properties: {
        eventType: 'order.placed'
      }
    }
  }
}

// Dead-letter queue for invoice-processor (built-in, no separate resource needed)

// ─── Subscription: order-notifications (optional fanout) ─────────────────────

resource orderNotificationsSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2023-01-01-preview' = {
  parent: orderEventsTopic
  name: 'order-notifications'
  properties: {
    maxDeliveryCount: 5
    lockDuration: 'PT1M'
    defaultMessageTimeToLive: 'P1D'
    deadLetteringOnMessageExpiration: true
    enableBatchedOperations: true
    requiresSession: false
  }
}

// ─── RBAC: AKS managed identity → Azure Service Bus Data Receiver ─────────────

var sbDataReceiverRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'  // Azure Service Bus Data Receiver
)

resource aksSbReceiverAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusNamespace.id, aksClusterPrincipalId, sbDataReceiverRoleId)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: sbDataReceiverRoleId
    principalId: aksClusterPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ─── RBAC: AKS managed identity → Azure Service Bus Data Sender ───────────────

var sbDataSenderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'  // Azure Service Bus Data Sender
)

resource aksSbSenderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBusNamespace.id, aksClusterPrincipalId, sbDataSenderRoleId)
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: sbDataSenderRoleId
    principalId: aksClusterPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────

@description('Name of the Service Bus namespace.')
output namespaceName string = serviceBusNamespace.name

@description('Service Bus namespace host (for connection strings).')
output namespaceHost string = '${serviceBusNamespace.name}.servicebus.windows.net'

@description('Resource ID of the Service Bus namespace.')
output namespaceId string = serviceBusNamespace.id

@description('Name of the order-events topic.')
output orderEventsTopicName string = orderEventsTopic.name
