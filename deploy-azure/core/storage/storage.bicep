@description('Especificar nombre para la cuenta de almacenamiento')
@minLength(10)
param storageAccountName string

@description('Especificar la region')
@minLength(1)
param location string

@description('Nombre del file share para custom nodes')
param fileShareName string = 'customnodes'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: { name: 'Standard_LRS' }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    enabledProtocols: 'SMB'
  }
}

output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
output storageAccountKey string = listKeys(storageAccount.id, '2022-05-01').keys[0].value
