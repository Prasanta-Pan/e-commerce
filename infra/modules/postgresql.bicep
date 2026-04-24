// ============================================================
// modules/postgresql.bicep — Azure PostgreSQL Flexible Server
//   Primary (R/W) + optional Read Replica in paired region
// ============================================================

@description('Azure region for the primary PostgreSQL server.')
param location string

@description('Name of the primary PostgreSQL Flexible Server.')
param serverName string

@description('PostgreSQL administrator login username.')
param administratorLogin string

@description('PostgreSQL administrator login password.')
@secure()
param administratorLoginPassword string

@description('Deployment environment — controls SKU and replica creation.')
@allowed(['dev', 'staging', 'prod'])
param environment string = 'dev'

@description('Azure region for the read replica. Defaults to paired region for australiaeast.')
param replicaLocation string = 'australiasoutheast'

@description('Name of the database to create inside the server.')
param databaseName string = 'ecommerce'

// ─── Derived Variables ────────────────────────────────────────────────────────

// Use Burstable tier in dev to reduce cost; GeneralPurpose in staging/prod
var skuName = environment == 'dev' ? 'Standard_B2s' : 'Standard_D2ds_v4'
var skuTier = environment == 'dev' ? 'Burstable' : 'GeneralPurpose'

// Only create a read replica in staging and prod
var deployReplica = environment != 'dev'

// ─── Primary Server ───────────────────────────────────────────────────────────

resource primaryServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: serverName
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: '15'
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
    storage: {
      storageSizeGB: 128
      autoGrow: 'Enabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: environment == 'prod' ? 'Enabled' : 'Disabled'
    }
    highAvailability: {
      mode: environment == 'prod' ? 'ZoneRedundant' : 'Disabled'
    }
    maintenanceWindow: {
      customWindow: 'Enabled'
      dayOfWeek: 0  // Sunday
      startHour: 2
      startMinute: 0
    }
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
  }
}

// ─── Database ────────────────────────────────────────────────────────────────

resource ecommerceDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: primaryServer
  name: databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// ─── Server Configuration (PG settings) ──────────────────────────────────────

resource pgConfig 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2023-06-01-preview' = {
  parent: primaryServer
  name: 'max_connections'
  properties: {
    value: '200'
    source: 'user-override'
  }
}

// ─── Firewall Rule — Allow Azure Services ─────────────────────────────────────

resource allowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: primaryServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ─── Read Replica (staging + prod only) ──────────────────────────────────────

resource readReplica 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = if (deployReplica) {
  name: '${serverName}-replica'
  location: replicaLocation
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    createMode: 'Replica'
    sourceServerResourceId: primaryServer.id
    storage: {
      storageSizeGB: 128
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// ─── Outputs ──────────────────────────────────────────────────────────────────

@description('Fully qualified domain name of the primary PostgreSQL server.')
output serverFqdn string = primaryServer.properties.fullyQualifiedDomainName

@description('Fully qualified domain name of the read replica (empty string in dev).')
output replicaFqdn string = deployReplica ? readReplica.properties.fullyQualifiedDomainName : ''

@description('Resource ID of the primary server.')
output serverId string = primaryServer.id

@description('Name of the application database.')
output databaseName string = ecommerceDatabase.name
