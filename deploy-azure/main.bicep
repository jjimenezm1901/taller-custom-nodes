targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name to prefix all resources')
param name string = 'taller-n8n'

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

@description('The IDs of the role definitions to assign to the managed identity.')
param roleDefinitionIds array

@description('Imagen n8n')
param imagenN8N string

@secure()
param databasePassword string

@secure()
param acrPassword string

@description('Server Azure container Registry para imagen')
param acrServer string

@description('Usuario Azure Container Registry')
param acrUserName string

@description('Real path n8n to custom nodes')
param n8ncustomNodesPath string

@secure()
@description('Clave de encriptación para n8n')
param n8nEncryptionKey string

var databaseAdmin = 'dbadmin'
var databaseName = 'n8n'
//var resourceToken = toLower(uniqueString(subscription().id, name, location))

var tags = { 'azd-env-name': name }
//var prefix = '${name}-${resourceToken}'
var prefix = name
//var prefix = 'dev-itc-'
var usecase = 'queue'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  //name: '${name}-resource-group'
  name: '${prefix}-rg-${usecase}'
  location: location
  tags: tags
}


// Managed Identiy for all application
module managedIdentity 'core/security/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: resourceGroup
  params: {
    name: '${prefix}-iden-${usecase}'
  }
}


// Principal ID Variable
var principalId = managedIdentity.outputs.principalId


// Asignar roles a la identidad administrada
module roleAssignment 'core/security/role.bicep' = {
  name: 'assign-role-to-identity'
  scope: resourceGroup
  params: {
    identityName: managedIdentity.outputs.principalName // Usar el ID de la identidad administrada
    roleDefinitionIds: roleDefinitionIds
  }
}

// Store secrets in a keyvault
module keyVault 'core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: 'tallern8nkvqueuev2'
    location: location
    tags: tags
  }
}

// Give the principal access to KeyVault
module principalKeyVaultAccess 'core/security/keyvault-access.bicep' = {
  name: 'keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: principalId
  }
}

module postgresServer 'core/database/flexibleserver.bicep' = {
  name: 'postgresql'
  scope: resourceGroup
  params: {
    //name: '${prefix}-postgresql'
    name: '${prefix}-pg-${usecase}'
    location: location
    tags: tags
    sku: {
      name: 'Standard_B1ms'
      tier: 'Burstable'
    }
    storage: {
      storageSizeGB: 32
    }
    version: '16'
    administratorLogin: databaseAdmin
    administratorLoginPassword: databasePassword
    databaseNames: [ databaseName ]
    allowAzureIPsFirewall: true
  }
}


module logAnalyticsWorkspace 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: resourceGroup
  params: {
    //name: '${prefix}-loganalytics'
    name: '${prefix}-log-${usecase}'
    location: location
    tags: tags
  }
}



// si se requiere crear un volumen
//var storageAccountName='${prefix}-sa-${usecase}'
//module storage 'core/storage/storage.bicep'={
//  scope:resourceGroup
//  name:storageAccountName
//  params:{
//    location:location
//    storageAccountName:replace(storageAccountName, '-', '')
//  }
//}


module containerAppEnv 'core/host/container-app-env.bicep' = {
  name: 'container-env'
  scope: resourceGroup
  params: {
    name: containerAppName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
    //storageAccountName: storage.outputs.storageAccountName
    //fileShareName: storage.outputs.fileShareName
    //storageAccountKey: storage.outputs.storageAccountKey
  }
}

//var containerAppName = '${prefix}-app'
var containerAppName = '${prefix}-capp-${usecase}'

module containerApp 'core/host/container-app.bicep' = {
  name: 'container'
  scope: resourceGroup
  params: {
    name: containerAppName
    location: location
    tags: tags
    containerEnvId: containerAppEnv.outputs.id
    imageName: imagenN8N // Imagen personalizada en ACR imageName o 'docker.n8n.io/n8nio/n8n:latest'
    targetPort: 5678
    env: [
      {
        name: 'DB_TYPE'
        value: 'postgresdb'
      }
      {
        name: 'DB_POSTGRESDB_HOST'
        value: postgresServer.outputs.fqdn
      }
      {
        name: 'DB_POSTGRESDB_PORT'
        value: '5432'
      }
      {
        name: 'DB_POSTGRESDB_DATABASE'
        value: databaseName
      }
      {
        name: 'DB_POSTGRESDB_USER'
        secretRef: 'databaseuser'
      }
      {
        name: 'DB_POSTGRESDB_PASSWORD'
        secretRef: 'databasepassword'
      }
      {
        name: 'DB_POSTGRESDB_SSL_ENABLED'
        value: 'true'
      }
      {
        name: 'N8N_HOST'
        value: '${containerAppName}.${containerAppEnv.outputs.defaultDomain}'
      }
      {
        name: 'WEBHOOK_URL'
        value: 'https://${containerAppName}.${containerAppEnv.outputs.defaultDomain}/'
      }
      {
        name: 'N8N_PROTOCOL'
        value: 'https'
      }
      {
        name: 'N8N_LOG_LEVEL'
        value: 'debug'
      }
      {
        name: 'N8N_COMMUNITY_PACKAGES_ENABLED'
        value: 'true'
      }
      {
        name: 'NODE_FUNCTION_ALLOW_BUILTIN'
        value: '*'
      }
      {
        name: 'NODE_FUNCTION_ALLOW_EXTERNAL'
        value: '*'
      }
      {
        name: 'N8N_CUSTOM_EXTENSIONS'
        value: n8ncustomNodesPath
      }
      {
        name: 'N8N_ENCRYPTION_KEY'
        secretRef: 'n8nencryptionkey'
      }
      {
        name: 'EXECUTIONS_MODE'
        value: 'queue'
      }
      {
        name: 'QUEUE_BULL_REDIS_HOST'
        value: redisCache.outputs.hostName
      }
      {
        name: 'QUEUE_BULL_REDIS_PORT'
        value: string(redisCache.outputs.sslPort)
      }
      {
        name: 'QUEUE_BULL_REDIS_PASSWORD'
        secretRef: 'redispassword'
      }
      {
        name: 'QUEUE_BULL_REDIS_TLS'
        value: 'true'
      }
      {
        name: 'QUEUE_BULL_REDIS_DB'
        value: '0'
      }
      {
        name: 'QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD'
        value: '10000'
      }
      {
        name: 'N8N_GRACEFUL_SHUTDOWN_TIMEOUT'
        value: '60'
      }
      {
        name: 'QUEUE_HEALTH_CHECK_ACTIVE'
        value: 'true'
      }
      {
        name: 'N8N_RUNNERS_ENABLED'
        value: 'true'
      }
      {
        name: 'OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS'
        value: 'true'
      }
      {
        name: 'N8N_WORKER_EXECUTIONS'
        value: 'true'
      }
      {
        name: 'N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS'
        value: 'true'
      }
      {
        name: 'GENERIC_TIMEZONE'
        value: 'America/Lima'
      }
    ]
    secrets: {
      databasepassword: databasePassword
      databaseuser: databaseAdmin
      redispassword: redisCache.outputs.primaryKey
      acrpassword: acrPassword
      n8nencryptionkey: n8nEncryptionKey
    }
    //storageMountName: containerAppEnv.outputs.storageMountName
    //n8ncustomVolPath: n8ncustomVolPath
    acrServer: acrServer
    acrUserName: acrUserName
  }
}

var secrets = [
  {
    name: 'DATABASEPASSWORD'
    value: databasePassword
  }
]

module keyVaultSecrets 'core/security/keyvault-secret.bicep' = [for secret in secrets: {
  name: 'keyvault-secret-${secret.name}'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    name: secret.name
    secretValue: secret.value
  }
}]

output SERVICE_APP_URI string = containerApp.outputs.uri
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name

// Redis Cache
module redisCache 'core/cache/redis.bicep' = {
  name: 'redis-cache'
  scope: resourceGroup
  params: {
    name: '${prefix}-redis-${usecase}'
    location: location
    tags: tags
  }
}

var workerContainerAppName = '${prefix}-capp-${usecase}-worker'
// Worker Container App
module workerContainerApp 'core/host/container-app-worker.bicep' = {
  name: 'worker-container'
  scope: resourceGroup
  dependsOn: [
    containerApp
  ]
  params: {
    name: workerContainerAppName
    location: location
    tags: tags
    containerEnvId: containerAppEnv.outputs.id
    imageName: imagenN8N
    targetPort: 5678
    redisHostName: redisCache.outputs.hostName
    redisSslPort: string(redisCache.outputs.sslPort)
    env: [
      {
        name: 'DB_TYPE'
        value: 'postgresdb'
      }
      {
        name: 'DB_POSTGRESDB_HOST'
        value: postgresServer.outputs.fqdn
      }
      {
        name: 'DB_POSTGRESDB_PORT'
        value: '5432'
      }
      {
        name: 'DB_POSTGRESDB_DATABASE'
        value: databaseName
      }
      {
        name: 'DB_POSTGRESDB_USER'
        secretRef: 'databaseuser'
      }
      {
        name: 'DB_POSTGRESDB_PASSWORD'
        secretRef: 'databasepassword'
      }
      {
        name: 'DB_POSTGRESDB_SSL_ENABLED'
        value: 'true'
      }
      {
        name: 'N8N_HOST'
        value: '${workerContainerAppName}.${containerAppEnv.outputs.defaultDomain}'
      }
      {
        name: 'N8N_PROTOCOL'
        value: 'https'
      }
      {
        name: 'N8N_LOG_LEVEL'
        value: 'debug'
      }
      {
        name: 'N8N_COMMUNITY_PACKAGES_ENABLED'
        value: 'true'
      }
      {
        name: 'NODE_FUNCTION_ALLOW_BUILTIN'
        value: '*'
      }
      {
        name: 'NODE_FUNCTION_ALLOW_EXTERNAL'
        value: '*'
      }
      {
        name: 'N8N_CUSTOM_EXTENSIONS'
        value: n8ncustomNodesPath
      }
      {
        name: 'N8N_REDIS_HOST'
        value: redisCache.outputs.hostName
      }
      {
        name: 'N8N_REDIS_PORT'
        value: string(redisCache.outputs.sslPort)
      }
      {
        name: 'N8N_REDIS_PASSWORD'
        secretRef: 'redispassword'
      }
      {
        name: 'N8N_ENCRYPTION_KEY'
        secretRef: 'n8nencryptionkey'
      }
      {
        name: 'EXECUTIONS_MODE'
        value: 'queue'
      }
      {
        name: 'QUEUE_BULL_REDIS_HOST'
        value: redisCache.outputs.hostName
      }
      {
        name: 'QUEUE_BULL_REDIS_PORT'
        value: string(redisCache.outputs.sslPort)
      }
      {
        name: 'QUEUE_BULL_REDIS_PASSWORD'
        secretRef: 'redispassword'
      }
      {
        name: 'QUEUE_BULL_REDIS_TLS'
        value: 'true'
      }
      {
        name: 'QUEUE_BULL_REDIS_DB'
        value: '0'
      }
      {
        name: 'QUEUE_BULL_REDIS_TIMEOUT_THRESHOLD'
        value: '10000'
      }
      {
        name: 'N8N_GRACEFUL_SHUTDOWN_TIMEOUT'
        value: '60'
      }
      {
        name: 'QUEUE_HEALTH_CHECK_ACTIVE'
        value: 'true'
      }
      {
        name: 'N8N_RUNNERS_ENABLED'
        value: 'true'
      }
      {
        name: 'N8N_CONCURRENCY_PRODUCTION_LIMIT'
        value: '25'
      }
      {
        name: 'OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS'
        value: 'true'
      }
      {
        name: 'N8N_WORKER_EXECUTIONS'
        value: 'true'
      }
      {
        name: 'N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS'
        value: 'true'
      }
      {
        name: 'GENERIC_TIMEZONE'
        value: 'America/Lima'
      }
    ]
    secrets: {
      databasepassword: databasePassword
      databaseuser: databaseAdmin
      redispassword: redisCache.outputs.primaryKey
      acrpassword: acrPassword
      n8nencryptionkey: n8nEncryptionKey
    }
    acrServer: acrServer
    acrUserName: acrUserName
  }
}

output WORKER_APP_URI string = workerContainerApp.outputs.uri
output REDIS_HOST string = redisCache.outputs.hostName
output REDIS_PORT string = string(redisCache.outputs.sslPort)
