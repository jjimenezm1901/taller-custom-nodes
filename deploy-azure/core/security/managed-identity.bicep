@description('Prefix for resource names')
param name string


@description('Location for the Managed Identity')
param location string = resourceGroup().location

// Create Managed Identity in the current Resource Group
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
}

output principalId string = managedIdentity.properties.principalId
output identityId string = managedIdentity.id
output principalName string = managedIdentity.name
