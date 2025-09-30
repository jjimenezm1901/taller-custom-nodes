# Despliegue de n8n en Azure con Modo Colas

Este directorio contiene la configuración para desplegar n8n en Azure usando Container Apps con modo colas (queue mode) para procesamiento distribuido.

## Arquitectura

El despliegue incluye:

- **Container App Principal**: Interfaz web de n8n
- **Container App Worker**: Procesadores de colas para ejecutar workflows
- **PostgreSQL Flexible Server**: Base de datos para n8n
- **Redis Cache**: Cola de mensajes para el modo colas
- **Azure Key Vault**: Almacenamiento seguro de secretos
- **Log Analytics**: Monitoreo y logging

## Prerrequisitos

### Instalar herramientas necesarias

**Windows:**
```powershell
# Instalar Azure CLI
winget install Microsoft.AzureCLI

# Instalar Bicep CLI
winget install Microsoft.Bicep

# Instalar Azure PowerShell
winget install Microsoft.PowerShell
```

**Linux/macOS:**
```bash
# Instalar Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Instalar Bicep CLI
az bicep install
```

### Configurar Azure

```bash
# Autenticarse con Azure
az login

# Configurar suscripción
az account set --subscription "TU_SUBSCRIPTION_ID"

# Verificar configuración
az account show
```

## Configuración del Despliegue

### 1. Configurar parámetros básicos

Edita el archivo `main.parameters.json`:

```json
{
  "parameters": {
    "imagenN8N": {
      "value": "docker.n8n.io/n8nio/n8n:latest"
    },
    "n8ncustomNodesPath": {
      "value": "/home/taller-custom-nodes/custom_nodes"
    },
    "acrServer": {
      "value": "tu-registry.azurecr.io"
    },
    "acrUserName": {
      "value": "tu-registry"
    }
  }
}
```

### 2. Validar la plantilla

```powershell
cd deploy-azure
az deployment sub validate --name dev-taller --location eastus2 --template-file main.bicep --parameters main.parameters.json
```

### 3. Ejecutar el despliegue

```powershell
az deployment sub create --name dev-taller --location eastus2 --template-file main.bicep --parameters main.parameters.json --parameters databasePassword="tu-password-segura" acrPassword="tu-password-registry" n8nEncryptionKey="tu-clave-encriptacion-32-caracteres"
```

## Configuración de Imagen Personalizada

### 1. Crear Azure Container Registry

```powershell
# Crear grupo de recursos
az group create --name rg-container-registry --location eastus

# Crear Container Registry
az acr create --resource-group rg-container-registry --name tu-registry --sku Basic

# Obtener credenciales
az acr credential show --name tu-registry
```

### 2. Construir imagen personalizada

```powershell
# Configurar variables de entorno
$GITHUB_REPO_URL = "https://github.com/tu-usuario/taller-custom-nodes.git"
$GITHUB_REPO_NOMBRE = "taller-custom-nodes"

# Construir imagen
docker build --build-arg GITHUB_REPO_URL=$GITHUB_REPO_URL --build-arg GITHUB_REPO_NOMBRE=$GITHUB_REPO_NOMBRE -t n8n-custom .

# Etiquetar para Azure Container Registry
docker tag n8n-custom tu-registry.azurecr.io/n8n-custom:v1.0

# Loguearse en ACR
az acr login --name tu-registry

# Subir imagen
docker push tu-registry.azurecr.io/n8n-custom:v1.0
```

### 3. Actualizar parámetros

Actualiza `main.parameters.json`:

```json
{
  "parameters": {
    "imagenN8N": {
      "value": "tu-registry.azurecr.io/n8n-custom:v1.0"
    }
  }
}
```

## Verificación del Despliegue

Una vez completado, obtendrás:

```
=== DESPLIEGUE COMPLETADO ===
SERVICE_APP_URI: https://dev-taller-capp-n8n-test.xxx.azurecontainerapps.io
WORKER_APP_URI: https://dev-taller-capp-n8n-test-worker.xxx.azurecontainerapps.io
AZURE_KEY_VAULT_NAME: dev-taller-kv-n8n-test
```

## Acceder a n8n

1. Abre la URL del `SERVICE_APP_URI` en tu navegador
2. Configura tu cuenta de administrador
3. Verifica que los nodos personalizados estén disponibles
4. ¡Tu instancia de n8n con modo colas está lista!

## Características del Modo Colas

- **Procesamiento Distribuido**: Los workflows se ejecutan en workers separados
- **Escalabilidad**: Puedes escalar workers independientemente
- **Confiabilidad**: Redis maneja la cola de mensajes de forma confiable
- **Monitoreo**: Log Analytics proporciona visibilidad completa

## Solución de Problemas

### Verificar estado de los servicios

```powershell
# Verificar Container Apps
az containerapp list --resource-group dev-taller-rg-n8n-test

# Verificar logs del servicio principal
az containerapp logs show --name dev-taller-capp-n8n-test --resource-group dev-taller-rg-n8n-test

# Verificar logs del worker
az containerapp logs show --name dev-taller-capp-n8n-test-worker --resource-group dev-taller-rg-n8n-test
```

### Verificar Redis

```powershell
# Verificar estado de Redis
az redis show --name dev-taller-redis-n8n-test --resource-group dev-taller-rg-n8n-test
```

## Limpieza de Recursos

```powershell
# Eliminar grupo de recursos completo
az group delete --name dev-taller-rg-n8n-test --yes --no-wait
```
