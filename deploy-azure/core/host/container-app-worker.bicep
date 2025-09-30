@description('Nombre del container app')
param name string

@description('Ubicación del recurso')
param location string

@description('Tags para el recurso')
param tags object

@description('ID del entorno de container apps')
param containerEnvId string

@description('Nombre de la imagen')
param imageName string

@description('Puerto objetivo')
param targetPort int

@description('Variables de entorno')
param env array

@description('Secretos')
param secrets object

@description('Server Azure container Registry para imagen')
param acrServer string

@description('Usuario Azure Container Registry')
param acrUserName string

@description('Nombre de host de Redis')
param redisHostName string

@description('Puerto SSL de Redis')
param redisSslPort string

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerEnvId
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'http'
      }
      secrets: [
        for secret in items(secrets): {
          name: secret.key
          value: secret.value
        }
      ]
      registries: [
        {
          server: acrServer
          username: acrUserName
          passwordSecretRef: 'acrpassword'
        }
      ]
    }
    template: {
      containers: [
        {
          name: name
          image: imageName
          command: ['/docker-entrypoint.sh', 'worker']
          env: env
          resources: {
            cpu: json('1.5')
            memory: '3Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 20
        rules: [
          {
            name: 'redis-queue-length'
            custom: {
              type: 'redis'
              metadata: {
                host: redisHostName
                port: redisSslPort
                listName: 'bull:jobs:wait'
                listLength: '10'
                enableTLS: 'true'
                tls_skip_verify: 'true'
                connectionTimeout: '120000'
                syncTimeout: '120000'
              }
              auth: [
                {
                  secretRef: 'redispassword'
                  triggerParameter: 'password'
                }
              ]
            }
          }
          {
            name: 'cpu-rule'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '70'
              }
            }
          }
          {
            name: 'memory-rule'
            custom: {
              type: 'memory'
              metadata: {
                type: 'Utilization'
                value: '70'
              }
            }
          }
        ]
      }
    }
  }
}

output id string = containerApp.id
output uri string = containerApp.properties.configuration.ingress.fqdn 
