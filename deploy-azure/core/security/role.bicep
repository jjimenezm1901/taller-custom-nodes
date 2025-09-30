@description('Name of the Managed Identity to grant access')
param identityName string


@description('The IDs of the role definitions to assign to the managed identity. Each role assignment is created at the resource group scope. Role definition IDs are GUIDs. To find the GUID for built-in Azure role definitions, see https://docs.microsoft.com/azure/role-based-access-control/built-in-roles. You can also use IDs of custom role definitions.')
param roleDefinitionIds array

// Reference the existing Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}


var roleAssignmentsToCreate = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(managedIdentity.id, resourceGroup().id, roleDefinitionId)
  roleDefinitionId: roleDefinitionId
}]

// Role assignment for the Managed Identity

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for roleAssignmentToCreate in roleAssignmentsToCreate: {
  name: roleAssignmentToCreate.name
  scope: resourceGroup()
  properties: {
    description: 'roleassingment'
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleAssignmentToCreate.roleDefinitionId)
    principalType: 'ServicePrincipal' // See https://docs.microsoft.com/azure/role-based-access-control/role-assignments-template#new-service-principal to understand why this property is included.
  }
}]


output principalId string = managedIdentity.properties.principalId
//output roleAssignmentName string = roleAssignment.name
