# 🚀 Taller de n8n en Modo Cola (Queue Mode) con Azure

## 📋 Índice
1. [Introducción](#introducción)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Configuración de Azure](#configuración-de-azure)
4. [Despliegue de Infraestructura](#despliegue-de-infraestructura)
5. [Configuración de n8n](#configuración-de-n8n)
6. [Construcción de Imagen Personalizada](#construcción-de-imagen-personalizada)
7. [Verificación y Testing](#verificación-y-testing)
8. [Monitoreo y Logs](#monitoreo-y-logs)
9. [Troubleshooting](#troubleshooting)
10. [Próximos Pasos](#próximos-pasos)

---

## 🎯 Introducción

### ¿Qué es n8n en Modo Cola?
n8n en **Queue Mode** es una arquitectura escalable que separa la ejecución de workflows en workers dedicados, permitiendo:
- **Escalabilidad horizontal**: Múltiples workers procesando workflows
- **Alta disponibilidad**: Si un worker falla, otros continúan
- **Mejor rendimiento**: Distribución de carga entre workers
- **Aislamiento**: Workers independientes para diferentes tipos de workflows

### ¿Por qué Azure?
- **Container Apps**: Orquestación automática de contenedores
- **PostgreSQL Flexible Server**: Base de datos escalable y confiable
- **Redis Cache**: Cola de mensajes de alta performance
- **Key Vault**: Gestión segura de secretos
- **Managed Identity**: Autenticación sin credenciales

---

## 🏗️ Arquitectura del Sistema

### Componentes Principales

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   n8n Web UI    │    │   n8n Worker 1  │    │   n8n Worker N  │
│   (Container)   │    │   (Container)   │    │   (Container)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Redis Cache   │
                    │   (Queue)      │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   PostgreSQL    │
                    │   (Database)    │
                    └─────────────────┘
```

### Flujo de Datos
1. **Usuario** crea/ejecuta workflow en n8n Web UI
2. **n8n Web UI** envía job a Redis Queue
3. **Workers** consumen jobs de la cola
4. **Workers** ejecutan workflows y guardan resultados en PostgreSQL
5. **n8n Web UI** muestra resultados al usuario

---

## ⚙️ Configuración de Azure

### Prerrequisitos
- **Azure CLI** instalado y configurado
- **Bicep CLI** (incluido en Azure CLI)
- **Docker** para construcción de imágenes
- **Suscripción Azure** (Pay-as-you-go recomendado)

### Variables de Entorno Necesarias
```bash
# Credenciales de base de datos
DATABASE_PASSWORD="2025#TallerArqN8N"

# Credenciales de Azure Container Registry
ACR_PASSWORD="tu-password-acr"

# Clave de encriptación para n8n
N8N_ENCRYPTION_KEY="WnIFazlKwsUcT12erWaaHN8ZWkMoCoW3"
```

---

## 🚀 Despliegue de Infraestructura

### 1. Configuración de Parámetros

**Archivo**: `deploy-azure/main.parameters.json`

```json
{
  "roleDefinitionIds": {
    "value": ["b24988ac-6180-42a0-ab88-20f7382dd24c"]
  },
  "imagenN8N": {
    "value": "docker.n8n.io/n8nio/n8n:latest"
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

### 2. Comando de Despliegue

```bash
az deployment sub create \
  --name taller-n8n-deploy \
  --location eastus \
  --template-file main.bicep \
  --parameters main.parameters.json \
  --parameters \
    databasePassword="2025#TallerArqN8N" \
    acrPassword="tu-password-acr" \
    n8nEncryptionKey="WnIFazlKwsUcT12erWaaHN8ZWkMoCoW3"
```

### 3. Recursos Creados

- **Grupo de recursos**: `taller-n8n-rg-queue`
- **PostgreSQL**: `taller-n8n-pg-queue`
- **Redis**: `taller-n8n-redis-queue`
- **Container Apps**: `taller-n8n-capp-queue` + worker
- **Key Vault**: `tallern8nkvqueuev2`
- **Managed Identity**: `taller-n8n-iden-queue`

---

## 🔧 Configuración de n8n

### Variables de Entorno Principales

#### Para n8n Web UI:
```bash
# Base de datos
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=taller-n8n-pg-queue.postgres.database.azure.com
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_SSL_ENABLED=true

# Modo cola
EXECUTIONS_MODE=queue
QUEUE_BULL_REDIS_HOST=taller-n8n-redis-queue.redis.cache.windows.net
QUEUE_BULL_REDIS_PORT=6380
QUEUE_BULL_REDIS_TLS=true
QUEUE_BULL_REDIS_DB=0

# Configuración de workers
N8N_RUNNERS_ENABLED=true
OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true
N8N_WORKER_EXECUTIONS=true
```

#### Para n8n Workers:
```bash
# Mismas variables de base de datos
# + Variables específicas de worker
N8N_CONCURRENCY_PRODUCTION_LIMIT=25
QUEUE_HEALTH_CHECK_ACTIVE=true
```

### Configuración de Seguridad
- **Managed Identity**: Autenticación automática a Azure
- **Key Vault**: Almacenamiento seguro de secretos
- **SSL/TLS**: Conexiones encriptadas a PostgreSQL y Redis

---

## 🐳 Construcción de Imagen Personalizada

### 1. Crear Azure Container Registry

```bash
az acr create \
  --resource-group taller-n8n-rg-queue \
  --name talleracrn8n \
  --sku Basic \
  --location eastus
```

### 2. Construir Imagen Docker

**Dockerfile**:
```dockerfile
FROM docker.n8n.io/n8nio/n8n:latest

# Copiar nodos personalizados
COPY nodes/ /home/taller-custom-nodes/

# Instalar dependencias adicionales si es necesario
RUN npm install -g @n8n/n8n-nodes-langchain
```

### 3. Construir y Subir Imagen

```bash
# Login a ACR
az acr login --name talleracrn8n

# Construir imagen
docker build -t talleracrn8n.azurecr.io/n8n-custom:v1.0 .

# Subir imagen
docker push talleracrn8n.azurecr.io/n8n-custom:v1.0
```

### 4. Actualizar Parámetros

```json
{
  "imagenN8N": {
    "value": "talleracrn8n.azurecr.io/n8n-custom:v1.0"
  }
}
```

---

## ✅ Verificación y Testing

### 1. Verificar Recursos Creados

```bash
# Listar recursos
az resource list --resource-group taller-n8n-rg-queue --output table

# Ver estado de Container Apps
az containerapp list --resource-group taller-n8n-rg-queue --output table
```

### 2. Acceder a n8n

```bash
# Obtener URL de la aplicación
az deployment sub show --name taller-n8n-deploy --query "properties.outputs.SERVICE_APP_URI"
```

### 3. Testing de Queue Mode

1. **Crear workflow simple** en n8n Web UI
2. **Ejecutar workflow** manualmente
3. **Verificar** que aparece en Redis Queue
4. **Confirmar** que worker procesa el job
5. **Verificar** resultados en PostgreSQL

### 4. Testing de Escalabilidad

```bash
# Escalar workers
az containerapp update \
  --name taller-n8n-capp-queue-worker \
  --resource-group taller-n8n-rg-queue \
  --min-replicas 3 \
  --max-replicas 10
```

---

## 📊 Monitoreo y Logs

### 1. Log Analytics

```bash
# Ver logs de Container Apps
az monitor log-analytics query \
  --workspace taller-n8n-log-queue \
  --analytics-query "ContainerAppConsoleLogs_CL | where TimeGenerated > ago(1h)"
```

### 2. Métricas de Redis

```bash
# Ver métricas de Redis
az monitor metrics list \
  --resource taller-n8n-redis-queue \
  --metric "connectedclients"
```

### 3. Métricas de PostgreSQL

```bash
# Ver métricas de PostgreSQL
az monitor metrics list \
  --resource taller-n8n-pg-queue \
  --metric "cpu_percent"
```

---

## 🔧 Troubleshooting

### Problemas Comunes

#### 1. Error de Conexión a PostgreSQL
```bash
# Verificar firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group taller-n8n-rg-queue \
  --name taller-n8n-pg-queue
```

#### 2. Error de Conexión a Redis
```bash
# Verificar estado de Redis
az redis show \
  --resource-group taller-n8n-rg-queue \
  --name taller-n8n-redis-queue
```

#### 3. Workers No Procesan Jobs
```bash
# Ver logs de workers
az containerapp logs show \
  --name taller-n8n-capp-queue-worker \
  --resource-group taller-n8n-rg-queue
```

### Comandos de Diagnóstico

```bash
# Ver estado de todos los recursos
az resource list --resource-group taller-n8n-rg-queue --query "[].{Name:name, Type:type, Status:properties.provisioningState}"

# Ver logs de deployment
az deployment sub show --name taller-n8n-deploy --query "properties.outputs"
```

---

## 🚀 Próximos Pasos

### 1. Optimizaciones
- **Auto-scaling**: Configurar reglas de escalado automático
- **Monitoring**: Implementar alertas y dashboards
- **Backup**: Configurar backups automáticos de PostgreSQL
- **Security**: Implementar network security groups

### 2. Funcionalidades Avanzadas
- **Custom Nodes**: Desarrollar nodos personalizados
- **Webhooks**: Configurar webhooks para integraciones
- **Scheduling**: Implementar workflows programados
- **Error Handling**: Configurar manejo de errores avanzado

### 3. Producción
- **High Availability**: Configurar múltiples regiones
- **Disaster Recovery**: Implementar estrategia de recuperación
- **Performance**: Optimizar queries y conexiones
- **Security**: Implementar autenticación y autorización

---

## 📚 Recursos Adicionales

- [Documentación oficial de n8n](https://docs.n8n.io/)
- [Azure Container Apps](https://docs.microsoft.com/en-us/azure/container-apps/)
- [Azure PostgreSQL](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Azure Redis Cache](https://docs.microsoft.com/en-us/azure/azure-cache-for-redis/)

---

## 🎯 Resumen del Taller

### Lo que aprendimos:
1. **Arquitectura de n8n en Queue Mode**
2. **Despliegue de infraestructura en Azure**
3. **Configuración de componentes**
4. **Construcción de imágenes personalizadas**
5. **Verificación y testing**
6. **Monitoreo y troubleshooting**

### Beneficios obtenidos:
- ✅ **Escalabilidad**: Múltiples workers procesando workflows
- ✅ **Confiabilidad**: Alta disponibilidad y recuperación automática
- ✅ **Performance**: Distribución de carga optimizada
- ✅ **Seguridad**: Gestión segura de secretos y autenticación
- ✅ **Monitoreo**: Visibilidad completa del sistema

¡Felicidades! Has implementado exitosamente n8n en modo cola en Azure. 🎉
