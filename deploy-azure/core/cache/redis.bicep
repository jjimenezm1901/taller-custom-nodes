@description('Nombre del recurso de Redis Cache')
param name string

@description('Ubicación del recurso')
param location string

@description('Tags para el recurso')
param tags object

@description('SKU de Redis Cache')
param sku string = 'Basic'

@description('Tamaño de la familia de Redis Cache')
param family string = 'C'

@description('Capacidad de Redis Cache')
param capacity int = 0

@description('Versión de Redis')
param redisVersion string = '6'

@description('Habilitar autenticación no SSL')
param enableNonSslPort bool = true

resource redisCache 'Microsoft.Cache/Redis@2023-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
      family: family
      capacity: capacity
    }
    enableNonSslPort: enableNonSslPort
    redisVersion: redisVersion
    publicNetworkAccess: 'Enabled'
  }
}

// Crear regla de firewall para permitir todo el tráfico (para desarrollo)
resource firewallRule 'Microsoft.Cache/Redis/firewallRules@2023-04-01' = {
  parent: redisCache
  name: 'AllowAll'
  properties: {
    startIP: '0.0.0.0'
    endIP: '255.255.255.255'
  }
}

output name string = redisCache.name
output hostName string = redisCache.properties.hostName
output sslPort int = redisCache.properties.sslPort
output port int = redisCache.properties.port
output primaryKey string = redisCache.listKeys().primaryKey
output secondaryKey string = redisCache.listKeys().secondaryKey
