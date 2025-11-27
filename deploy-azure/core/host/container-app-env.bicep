param name string
param location string = resourceGroup().location
param tags object = {}

param logAnalyticsWorkspaceName string
//param storageAccountName string
//param fileShareName string
//param storageAccountKey string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource containerEnv 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// Definir el recurso `storageMount` como un módulo SEPARADO
//resource storageMount 'Microsoft.App/managedEnvironments/storages@2022-03-01' = {
//storageAccountName  parent: containerEnv  // Ahora `storageMount` es hijo de `containerEnv`
//  name: 'customnodes-storage'
//  properties: {
//    azureFile: {
//      accountKey: storageAccountKey
//      accountName: storageAccountName
//      shareName: fileShareName
//      accessMode: 'ReadWrite'
//    }
//  }
//}


output id string = containerEnv.id
output defaultDomain string = containerEnv.properties.defaultDomain
//output storageMountName string = storageMount.name  // 🔹 Exporta el nombre correctamente
//output storageMountName2 string = storageMount2.name  // 🔹 Exporta el nombre correctamente
