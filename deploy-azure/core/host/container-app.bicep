param name string
param location string = resourceGroup().location
param tags object = {}

param containerEnvId string
@secure()
param secrets object

param env array = []
param imageName string
param targetPort int = 5678

//param storageMountName string
//param n8ncustomVolPath string

param acrUserName string
param acrServer string

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'None'
  }
  properties: {
    managedEnvironmentId: containerEnvId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: targetPort
      }
      registries: [
        {
          server: acrServer
          username: acrUserName
          passwordSecretRef: 'acrpassword'
        }
      ]
      secrets: [for secret in items(secrets): {
        name: secret.key
        value: secret.value
      }]
        
    }
    template: {
      containers: [
        {
          image: imageName
          name: name
          env: env 
          resources: {
            cpu: '1.0'
            memory: '2Gi'
          }
          //volumeMounts: [
          //  {
          //    volumeName: 'customnodes-volume'
          //    mountPath: n8ncustomVolPath              
          //  }
          //]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3      
      }
      //volumes: [
      //  {
      //    name: 'customnodes-volume'
      //    storageType: 'AzureFile'
      //    storageName: storageMountName
      //    mountOptions: 'dir_mode=0777,file_mode=0777'
      //  }
      //]  
    }
  }
}

output imageName string = imageName
output name string = containerApp.name
output uri string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
