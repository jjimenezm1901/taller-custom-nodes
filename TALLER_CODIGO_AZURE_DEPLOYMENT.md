# 🏗️ Taller: Código de Despliegue Azure - n8n Queue Mode

## 📋 Índice
1. [Estructura del Proyecto](#estructura-del-proyecto)
2. [Archivo Principal: main.bicep](#archivo-principal-mainbicep)
3. [Módulos de Infraestructura](#módulos-de-infraestructura)
4. [Parámetros y Configuración](#parámetros-y-configuración)
5. [Flujo de Despliegue](#flujo-de-despliegue)
6. [Explicación por Componentes](#explicación-por-componentes)

---

## 📁 Estructura del Proyecto

```
deploy-azure/
├── main.bicep                    # 🎯 Archivo principal de orquestación
├── main.parameters.json          # ⚙️ Parámetros de configuración
├── Dockerfile                    # 🐳 Imagen personalizada de n8n
└── core/                        # 📦 Módulos de infraestructura
    ├── cache/
    │   └── redis.bicep          # 🔴 Redis Cache para colas
    ├── database/
    │   └── flexibleserver.bicep # 🗄️ PostgreSQL Flexible Server
    ├── host/
    │   ├── container-app.bicep  # 🚀 n8n Web UI Container
    │   ├── container-app-worker.bicep # 👷 n8n Worker Container
    │   └── container-app-env.bicep   # 🌐 Container Apps Environment
    ├── monitor/
    │   └── loganalytics.bicep   # 📊 Log Analytics Workspace
    └── security/
        ├── keyvault.bicep       # 🔐 Azure Key Vault
        ├── keyvault-access.bicep # 🔑 Acceso al Key Vault
        ├── keyvault-secret.bicep # 🗝️ Secretos en Key Vault
        ├── managed-identity.bicep # 🆔 Managed Identity
        └── role.bicep           # 👤 Asignación de roles
```

---

## 🎯 Archivo Principal: main.bicep

### **Propósito**
Es el **orquestador principal** que coordina todos los módulos y define la arquitectura completa.

### **Estructura del Archivo**

#### 1. **Parámetros de Entrada** (líneas 1-35)
```bicep
@minLength(1)
@maxLength(64)
@description('Name to prefix all resources')
param name string = 'taller-n8n'

@minLength(1)
@description('Primary location for all resources')
param location string = 'eastus'

@secure()
param databasePassword string

@secure()
param acrPassword string
```

**¿Por qué estos parámetros?**
- **`name`**: Prefijo para todos los recursos (evita conflictos)
- **`location`**: Región de Azure (consistencia geográfica)
- **`@secure()`**: Decorador que marca parámetros sensibles
- **`databasePassword`**: Contraseña de PostgreSQL (sensible)
- **`acrPassword`**: Contraseña de Azure Container Registry (sensible)

#### 2. **Variables y Constantes** (líneas 37-45)
```bicep
var databaseAdmin = 'dbadmin'
var databaseName = 'n8n'
var tags = { 'azd-env-name': name }
var prefix = name
var usecase = 'queue'
```

**¿Por qué estas variables?**
- **`databaseAdmin`**: Usuario fijo para PostgreSQL (no sensible)
- **`databaseName`**: Nombre de la base de datos n8n
- **`tags`**: Etiquetas para organización y facturación
- **`prefix`**: Reutilización del nombre para consistencia
- **`usecase`**: Identificador del caso de uso (queue mode)

#### 3. **Recursos de Infraestructura** (líneas 47-341)

**Grupo de Recursos** (líneas 47-52):
```bicep
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${prefix}-rg-${usecase}'
  location: location
  tags: tags
}
```

**¿Por qué este patrón?**
- **`${prefix}-rg-${usecase}`**: Nombre predecible y organizado
- **`location`**: Hereda la región del parámetro
- **`tags`**: Aplicación de etiquetas para organización

---

## 📦 Módulos de Infraestructura

### **1. Seguridad y Autenticación**

#### **Managed Identity** (líneas 56-62)
```bicep
module managedIdentity 'core/security/managed-identity.bicep' = {
  name: 'managed-identity'
  scope: resourceGroup
  params: {
    name: '${prefix}-iden-${usecase}'
  }
}
```

**¿Qué hace?**
- Crea una **identidad administrada** para autenticación automática
- **Sin credenciales**: No necesita passwords ni keys
- **Seguridad**: Azure maneja la autenticación internamente

#### **Key Vault** (líneas 80-88)
```bicep
module keyVault 'core/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: 'tallern8nkvqueuev2'
    location: location
    tags: tags
  }
}
```

**¿Por qué Key Vault?**
- **Almacenamiento seguro** de secretos (passwords, keys)
- **Rotación automática** de credenciales
- **Auditoría**: Log de acceso a secretos
- **Integración**: Acceso automático desde Container Apps

### **2. Base de Datos**

#### **PostgreSQL Flexible Server** (líneas 100-121)
```bicep
module postgresServer 'core/database/flexibleserver.bicep' = {
  name: 'postgresql'
  scope: resourceGroup
  params: {
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
```

**¿Por qué PostgreSQL Flexible Server?**
- **Escalabilidad**: Puede escalar verticalmente según demanda
- **Alta disponibilidad**: Opción de replicación automática
- **Backup automático**: Respaldos programados
- **SSL/TLS**: Conexiones encriptadas por defecto
- **Firewall**: Control de acceso por IP

**¿Por qué estos parámetros?**
- **`Standard_B1ms`**: SKU balanceado (1 vCPU, 2GB RAM)
- **`storageSizeGB: 32`**: Mínimo requerido por Azure
- **`version: '16'`**: Versión estable y compatible con n8n
- **`allowAzureIPsFirewall: true`**: Permite conexiones desde Azure

### **3. Cola de Mensajes**

#### **Redis Cache** (líneas 333-341)
```bicep
module redisCache 'core/cache/redis.bicep' = {
  name: 'redis-cache'
  scope: resourceGroup
  params: {
    name: '${prefix}-redis-${usecase}'
    location: location
    tags: tags
  }
}
```

**¿Por qué Redis?**
- **Cola de mensajes**: Almacena jobs de workflows
- **Alta performance**: In-memory, muy rápido
- **Persistencia**: Opción de persistir datos
- **Clustering**: Escalabilidad horizontal
- **TLS**: Conexiones encriptadas

### **4. Aplicaciones**

#### **Container Apps Environment** (líneas 149-161)
```bicep
module containerAppEnv 'core/host/container-app-env.bicep' = {
  name: 'container-env'
  scope: resourceGroup
  params: {
    name: containerAppName
    location: location
    tags: tags
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
  }
}
```

**¿Qué es Container Apps Environment?**
- **Plataforma de orquestación**: Similar a Kubernetes pero más simple
- **Auto-scaling**: Escala automáticamente según demanda
- **Networking**: Red interna entre contenedores
- **Logging**: Integración automática con Log Analytics

#### **n8n Web UI Container** (líneas 166-310)
```bicep
module containerApp 'core/host/container-app.bicep' = {
  name: 'container'
  scope: resourceGroup
  params: {
    name: containerAppName
    location: location
    tags: tags
    containerEnvId: containerAppEnv.outputs.id
    imageName: imagenN8N
    targetPort: 5678
    env: [
      {
        name: 'DB_TYPE'
        value: 'postgresdb'
      }
      // ... más variables de entorno
    ]
    secrets: {
      databasepassword: databasePassword
      databaseuser: databaseAdmin
      redispassword: redisCache.outputs.primaryKey
      acrpassword: acrPassword
      n8nencryptionkey: n8nEncryptionKey
    }
  }
}
```

**¿Por qué estas variables de entorno?**
- **`DB_TYPE=postgresdb`**: Tipo de base de datos
- **`EXECUTIONS_MODE=queue`**: Habilita modo cola
- **`QUEUE_BULL_REDIS_*`**: Configuración de Redis para colas
- **`N8N_RUNNERS_ENABLED=true`**: Habilita workers
- **`OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true`**: Envía ejecuciones a workers

#### **n8n Worker Container** (líneas 345-504)
```bicep
module workerContainerApp 'core/host/container-app-worker.bicep' = {
  name: 'worker-container'
  scope: resourceGroup
  dependsOn: [containerApp]
  params: {
    name: workerContainerAppName
    // ... configuración similar pero para workers
    env: [
      {
        name: 'N8N_CONCURRENCY_PRODUCTION_LIMIT'
        value: '25'
      }
      // ... más variables específicas de worker
    ]
  }
}
```

**¿Por qué un contenedor separado para workers?**
- **Separación de responsabilidades**: UI vs. procesamiento
- **Escalabilidad independiente**: Escalar workers sin afectar UI
- **Aislamiento**: Fallos en workers no afectan UI
- **Configuración específica**: Variables optimizadas para procesamiento

---

## ⚙️ Parámetros y Configuración

### **Archivo: main.parameters.json**

```json
{
  "roleDefinitionIds": {
    "value": ["b24988ac-6180-42a0-ab88-20f7382dd24c"]
  },
  "imagenN8N": {
    "value": "talleracrn8n.azurecr.io/n8n-custom:v1.0"
  },
  "n8ncustomNodesPath": {
    "value": "/home/taller-custom-nodes"
  },
  "acrServer": {
    "value": "talleracrn8n.azurecr.io"
  },
  "acrUserName": {
    "value": "talleracrn8n"
  }
}
```

**¿Por qué estos parámetros?**
- **`roleDefinitionIds`**: ID del rol "Contributor" para Managed Identity
- **`imagenN8N`**: Imagen personalizada de n8n con nodos custom
- **`n8ncustomNodesPath`**: Ruta donde están los nodos personalizados
- **`acrServer`**: Servidor de Azure Container Registry
- **`acrUserName`**: Usuario para autenticación en ACR

---

## 🔄 Flujo de Despliegue

### **1. Orden de Creación**
```
1. Resource Group
2. Managed Identity
3. Key Vault
4. PostgreSQL
5. Redis
6. Log Analytics
7. Container Apps Environment
8. Container Apps (Web UI + Worker)
9. Role Assignments
10. Key Vault Secrets
```

### **2. Dependencias**
```bicep
// Worker depende de Container App principal
dependsOn: [containerApp]

// Key Vault Access depende de Key Vault
dependsOn: [keyVault]

// Container Apps dependen de Environment
containerEnvId: containerAppEnv.outputs.id
```

### **3. Outputs**
```bicep
output SERVICE_APP_URI string = containerApp.outputs.uri
output WORKER_APP_URI string = workerContainerApp.outputs.uri
output REDIS_HOST string = redisCache.outputs.hostName
output REDIS_PORT string = string(redisCache.outputs.sslPort)
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
```

**¿Por qué estos outputs?**
- **URLs de acceso**: Para conectarse a las aplicaciones
- **Configuración de Redis**: Para debugging y monitoreo
- **Nombre de Key Vault**: Para gestión de secretos

---

## 🎯 Explicación por Componentes

### **1. Arquitectura de Seguridad**
- **Managed Identity**: Autenticación sin credenciales
- **Key Vault**: Almacenamiento seguro de secretos
- **Role Assignments**: Permisos granulares
- **SSL/TLS**: Conexiones encriptadas

### **2. Arquitectura de Datos**
- **PostgreSQL**: Persistencia de workflows y ejecuciones
- **Redis**: Cola de mensajes para jobs
- **Log Analytics**: Almacenamiento de logs

### **3. Arquitectura de Aplicación**
- **Container Apps Environment**: Plataforma de orquestación
- **Web UI Container**: Interfaz de usuario de n8n
- **Worker Container**: Procesamiento de workflows
- **Auto-scaling**: Escalabilidad automática

### **4. Patrones de Diseño**
- **Modularidad**: Cada componente en su propio archivo
- **Reutilización**: Módulos reutilizables
- **Separación de responsabilidades**: UI vs. procesamiento
- **Configuración externa**: Parámetros en archivos separados

---

## 💡 Puntos Clave para el Taller

### **¿Por qué esta arquitectura?**
1. **Escalabilidad**: Workers independientes
2. **Confiabilidad**: Fallos aislados
3. **Seguridad**: Gestión centralizada de secretos
4. **Mantenibilidad**: Código modular y organizado

### **¿Por qué Azure?**
1. **Container Apps**: Orquestación simple
2. **PostgreSQL Flexible**: Base de datos escalable
3. **Redis Cache**: Cola de mensajes de alta performance
4. **Key Vault**: Gestión segura de secretos

### **¿Por qué Bicep?**
1. **Infrastructure as Code**: Versionado y reutilización
2. **Declarativo**: Describe el estado deseado
3. **Modular**: Componentes reutilizables
4. **Integración**: Nativo con Azure

---

## 🎯 Resumen para el Taller

### **Estructura del Código:**
- **`main.bicep`**: Orquestador principal
- **`core/`**: Módulos de infraestructura
- **`main.parameters.json`**: Configuración externa

### **Flujo de Despliegue:**
1. **Infraestructura**: PostgreSQL, Redis, Key Vault
2. **Seguridad**: Managed Identity, Roles
3. **Aplicaciones**: Container Apps Environment
4. **Contenedores**: Web UI + Workers

### **Beneficios de esta Arquitectura:**
- ✅ **Escalabilidad**: Workers independientes
- ✅ **Seguridad**: Gestión centralizada de secretos
- ✅ **Mantenibilidad**: Código modular
- ✅ **Confiabilidad**: Fallos aislados

¡Esta es la estructura del código que vas a explicar en tu taller! 🚀
