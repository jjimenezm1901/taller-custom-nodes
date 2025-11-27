# Taller de Arquitectura IA con n8n

Este repositorio contiene un taller práctico para crear nodos personalizados en n8n, incluyendo el nodo ObfuscationWrapper como ejemplo.

## Prerrequisitos

Antes de comenzar, asegúrate de tener instalado lo siguiente en tu máquina de desarrollo:

- **Node.js** (versión >20, preferiblemente instalado con nvm)
- **Git**
- **Docker Desktop**

### Instalación de Node.js con nvm (Recomendado)

Para instalar Node.js usando nvm:

**Linux/Mac/WSL:**
```bash
# Instalar nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash

# Reiniciar terminal o ejecutar:
source ~/.bashrc

# Instalar Node.js 20
nvm install 20
nvm use 20
```

**Windows:**
Descarga e instala nvm-windows desde [GitHub Releases](https://github.com/coreybutler/nvm-windows/releases). Una vez instalado, ejecuta:

```bash
# Instalar Node.js 20
nvm install 20
nvm use 20
```

## Configuración del Proyecto

### 1. Clonar el repositorio base

```bash
git clone https://github.com/n8n-io/n8n-nodes-starter.git taller-custom-nodes
cd taller-custom-nodes
```

### 2. Agregar el nodo ObfuscationWrapper

1. Copia la carpeta `ObfuscationWrapper` (desde el comprimido compartido en SharePoint) dentro de la carpeta `nodes/`
2. La estructura debe quedar así:
   ```
   nodes/
   ├── ExampleNode/
   ├── HttpBin/
   └── ObfuscationWrapper/
       ├── ObfuscationWrapper.node.ts
       ├── ObfuscationWrapper.node.json
       └── obfuscation-icon.svg
   ```

### 3. Actualizar package.json

Agrega la referencia del nodo ObfuscationWrapper en el archivo `package.json`:

```json
{
  "n8n": {
    "n8nNodesApiVersion": 1,
    "credentials": [
      "dist/credentials/ExampleCredentialsApi.credentials.js",
      "dist/credentials/HttpBinApi.credentials.js"
    ],
    "nodes": [
      "dist/nodes/ExampleNode/ExampleNode.node.js",
      "dist/nodes/HttpBin/HttpBin.node.js",
      "dist/nodes/ObfuscationWrapper/ObfuscationWrapper.node.js"
    ]
  }
}
```

### 4. Verificar instalación y compilar

```bash
# Verificar que Node.js esté instalado correctamente
node --version
npm --version

# Instalar dependencias
npm install

# Compilar el proyecto
npm run build
```

## Creación del Dockerfile

El código del Dockerfile ya está incluido en el proyecto. Este archivo:

- Usa la imagen base oficial de n8n
- Clona tu repositorio de GitHub
- Instala las dependencias necesarias
- Compila los nodos personalizados
- Configura n8n para usar los nodos custom

## Despliegue con Docker

### Opción 1: Usar tu propio repositorio

1. Sube tu código a un repositorio público en GitHub
2. Ejecuta el comando de build reemplazando las variables:

```bash
docker build --no-cache \
  --build-arg GITHUB_REPO_URL=https://github.com/tu-usuario/tu-repo.git \
  --build-arg GITHUB_REPO_NOMBRE=tu-repo \
  -t n8n-custom1 .
```

### Opción 2: Usar el repositorio del taller

Si prefieres usar el repositorio ya configurado:

```bash
docker build --no-cache \
  --build-arg GITHUB_REPO_URL=https://github.com/jjimenezm1901/taller-custom-nodes.git \
  --build-arg GITHUB_REPO_NOMBRE=taller-custom-nodes \
  -t n8n-custom1 .
```

### Crear y ejecutar el contenedor

```bash
# Crear el contenedor
docker run -d \
  --name n8n-custom-container \
  -p 5678:5678 \
  n8n-custom1

# Verificar que el contenedor esté ejecutándose
docker ps
```

## Subir Imagen a Docker Hub

Para compartir tu imagen personalizada de n8n con nodos customizados:

### 1. Compilar la imagen

```bash
docker build --no-cache \
  --build-arg GITHUB_REPO_URL=https://github.com/jjimenezm1901/taller-custom-nodes.git \
  --build-arg GITHUB_REPO_NOMBRE=taller-custom-nodes \
  -t taller-custom-nodes .
```

### 2. Etiquetar la imagen para Docker Hub con versionado

Es recomendable usar versionado semántico (SemVer) para tus imágenes. Esto te permite mantener un historial de versiones y facilitar el rollback si es necesario.

**Opción A: Etiquetar con versión específica y latest**

```bash
# Definir la versión (ejemplo: v1.0.0)
VERSION=v1.0.0

# Etiquetar con la versión específica
docker tag taller-custom-nodes xjimenezm/taller-custom-nodes:${VERSION}

# Etiquetar también como latest (opcional, pero recomendado)
docker tag taller-custom-nodes xjimenezm/taller-custom-nodes:latest
```

**Opción B: Etiquetar solo con versión específica**

```bash
# Etiquetar con versión específica
docker tag taller-custom-nodes xjimenezm/taller-custom-nodes:v1.0.0
```

**Ejemplos de versionado semántico:**
- `v1.0.0` - Versión inicial (major.minor.patch)
- `v1.1.0` - Nueva funcionalidad (minor)
- `v1.1.1` - Corrección de errores (patch)
- `v2.0.0` - Cambios incompatibles (major)

### 3. Hacer login en Docker Hub

```bash
docker login
```

### 4. Subir la imagen

**Si etiquetaste con versión y latest:**

```bash
# Subir la versión específica
docker push xjimenezm/taller-custom-nodes:${VERSION}

# Subir la etiqueta latest
docker push xjimenezm/taller-custom-nodes:latest
```

**O subir ambas en un solo comando:**

```bash
# Subir todas las etiquetas de la imagen
docker push xjimenezm/taller-custom-nodes:${VERSION}
docker push xjimenezm/taller-custom-nodes:latest
```

**Si solo etiquetaste con versión específica:**

```bash
docker push xjimenezm/taller-custom-nodes:v1.0.0
```

### 5. Verificar la imagen en Docker Hub

Una vez subida, puedes verificar tus imágenes en [Docker Hub](https://hub.docker.com/) y ver todas las versiones etiquetadas.

## Despliegue en Google Cloud Platform

### Prerrequisitos para GCP

#### Instalar Google Cloud CLI

**Ubuntu WSL / Linux:**

```bash
# Actualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalar herramientas básicas
sudo apt install -y curl wget git unzip

# Instalar Google Cloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Verificar instalación
gcloud --version
```

**macOS:**

```bash
# Instalar con Homebrew
brew install --cask google-cloud-sdk

# O descargar desde Google Cloud
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Windows:**

Descarga e instala desde [Google Cloud CLI](https://cloud.google.com/sdk/docs/install-sdk)

#### Configurar Google Cloud

```bash
# Autenticarse con Google Cloud
gcloud auth login

# Configurar proyecto (reemplaza con tu PROJECT_ID)
gcloud config set project TU_PROJECT_ID

# Verificar configuración
gcloud config list
```

### Configuración del Proyecto

#### 1. Crear archivo .env

Crea un archivo `.env` en la raíz del proyecto con la siguiente configuración:

```bash
# Configuración del proyecto
PROJECT_ID=tu-project-id
REGION=us-central1
ENVIRONMENT=dev

# Configuración de Cloud Run
CLOUDRUN_SERVICE_NAME=n8n-regular
SERVICE_ACCOUNT_NAME=n8n-sa

# Configuración de base de datos
DB_INSTANCE_NAME=n8n-postgres
DB_NAME=n8n
DB_USER=n8n_user
DB_PASSWORD=tu-password-segura
DB_SECRET_NAME=n8n-db-password

# Configuración de N8N
N8N_ENCRYPTION_KEY=tu-clave-de-encriptacion-32-caracteres

# Configuración opcional de GitHub (para nodos customizados)
GITHUB_REPO_URL=https://github.com/jjimenezm1901/taller-custom-nodes.git
GITHUB_REPO_NOMBRE=taller-custom-nodes
```

#### 2. Ejecutar el script de despliegue

```bash
# Navegar al directorio del proyecto
cd /mnt/c/Users/i0329/Documents/projects/datapath/taller-custom-nodes

# Navegar al directorio de despliegue
cd deploy-gcp/n8n-regular

# Convertir el formato CLRF de windows a linux (ir a la carpeta infrastructure):
dos2unix deploy-postgresql.sh 2>/dev/null || sed -i 's/\r$//' deploy-postgresql.sh

# Dar permisos de ejecución
chmod +x deploy-regular.sh

# Ejecutar el script de despliegue
./deploy-regular.sh
```

### Verificación del Despliegue

Una vez completado el despliegue, el script mostrará:

```
=== DESPLIEGUE COMPLETADO ===
URL: https://n8n-regular-dev-123456789.us-central1.run.app
Servicio: n8n-regular-dev
Región: us-central1
```

### Acceder a N8N

1. Abre la URL proporcionada en tu navegador
2. Configura tu cuenta de administrador
3. Verifica que los nodos personalizados estén disponibles
4. ¡Tu instancia de N8N está lista para usar!

## Despliegue en Azure

### Prerrequisitos para Azure

#### Instalar Azure CLI y herramientas

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

# Instalar Azure PowerShell
curl -sL https://raw.githubusercontent.com/Azure/azure-cli/main/scripts/install-az-cli.sh | bash
```

#### Configurar Azure

```bash
# Autenticarse con Azure
az login

# Configurar suscripción (reemplaza con tu SUBSCRIPTION_ID)
az account set --subscription "TU_SUBSCRIPTION_ID"

# Verificar configuración
az account show
```

### Configuración del Proyecto

#### 1. Configurar parámetros de despliegue

Edita el archivo `deploy-azure/main.parameters.json` con tus valores:

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

#### 2. Validar el despliegue

```powershell
# Navegar al directorio de Azure
cd deploy-azure

# Validar la plantilla Bicep
az deployment sub validate --name dev-taller --location eastus2 --template-file main.bicep --parameters main.parameters.json
```

#### 3. Ejecutar el despliegue

```powershell
# Desplegar la infraestructura con parámetros sensibles
az deployment sub create --name dev-taller --location eastus2 --template-file main.bicep --parameters main.parameters.json --parameters databasePassword="tu-password-segura" acrPassword="tu-password-registry" n8nEncryptionKey="tu-clave-encriptacion-32-caracteres"
```

**Parámetros requeridos:**
- `databasePassword`: Contraseña para la base de datos PostgreSQL
- `acrPassword`: Contraseña del Azure Container Registry
- `n8nEncryptionKey`: Clave de encriptación de 32 caracteres para n8n

### Configuración de Imagen Personalizada (Opcional)

Si necesitas nodos customizados, puedes crear una imagen personalizada:

#### 1. Crear Azure Container Registry

```powershell
# Crear un grupo de recursos para el registry
az group create --name rg-container-registry --location eastus

# Crear Azure Container Registry
az acr create --resource-group rg-container-registry --name tu-registry --sku Basic

# Obtener credenciales del registry
az acr credential show --name tu-registry
```

#### 2. Configurar variables de entorno

Crea un archivo `.env` en la raíz del proyecto:

```bash
GITHUB_REPO_URL=https://github.com/tu-usuario/taller-custom-nodes.git
GITHUB_REPO_NOMBRE=taller-custom-nodes
```

#### 3. Construir la imagen Docker

```powershell
# Cargar variables de entorno
$GITHUB_REPO_URL = (Get-Content .env | Select-String "^GITHUB_REPO_URL=") -replace "GITHUB_REPO_URL=", ""
$GITHUB_REPO_NOMBRE = (Get-Content .env | Select-String "^GITHUB_REPO_NOMBRE=") -replace "GITHUB_REPO_NOMBRE=", ""

# Construir la imagen
docker build --build-arg GITHUB_REPO_URL=$GITHUB_REPO_URL --build-arg GITHUB_REPO_NOMBRE=$GITHUB_REPO_NOMBRE -t n8n-custom .
```

#### 4. Subir imagen a Azure Container Registry

```powershell
# Etiquetar la imagen para Azure Container Registry
docker tag n8n-custom tu-registry.azurecr.io/n8n-custom:v1.0

# Loguearse en Azure Container Registry
az acr login --name tu-registry

# Subir la imagen
docker push tu-registry.azurecr.io/n8n-custom:v1.0
```

#### 5. Actualizar parámetros de despliegue

Actualiza los parámetros en `deploy-azure/main.parameters.json`:

```json
{
  "parameters": {
    "imagenN8N": {
      "value": "tu-registry.azurecr.io/n8n-custom:v1.0"
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

#### 6. Configurar credenciales de ACR

Antes del despliegue, necesitas configurar las credenciales del Container Registry:

```powershell
# Obtener la contraseña del registry
$acrPassword = (az acr credential show --name tu-registry --query "passwords[0].value" -o tsv)

# Configurar la contraseña como parámetro (esto se hará en el despliegue)
# Nota: Esta contraseña se debe pasar como parámetro al template Bicep
```

### Verificación del Despliegue

Una vez completado el despliegue, Azure mostrará:

```
=== DESPLIEGUE COMPLETADO ===
SERVICE_APP_URI: https://dev-taller-capp-n8n-test.xxx.azurecontainerapps.io
WORKER_APP_URI: https://dev-taller-capp-n8n-test-worker.xxx.azurecontainerapps.io
AZURE_KEY_VAULT_NAME: dev-taller-kv-n8n-test
```

### Acceder a N8N

1. Abre la URL del `SERVICE_APP_URI` en tu navegador
2. Configura tu cuenta de administrador
3. Verifica que los nodos personalizados estén disponibles
4. ¡Tu instancia de N8N con modo colas está lista para usar!

## Verificación

1. Abre tu navegador y ve a `http://localhost:5678`
2. Inicia sesión en n8n
3. Crea un nuevo workflow
4. Busca el nodo "ObfuscationWrapper" en la lista de nodos disponibles
5. Si puedes ver y usar el nodo, ¡el taller se completó exitosamente!

## Solución de Problemas

### Error de compilación
```bash
# Limpiar y reinstalar dependencias
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Error de Docker
```bash
# Limpiar imágenes y contenedores
docker system prune -a
docker build --no-cache [argumentos...]
```

### Verificar logs del contenedor
```bash
docker logs n8n-custom-container
```

## Estructura del Proyecto

```
taller-custom-nodes/
├── credentials/          # Credenciales personalizadas
├── nodes/               # Nodos personalizados
│   ├── ExampleNode/
│   ├── HttpBin/
│   └── ObfuscationWrapper/
├── dist/                # Archivos compilados
├── package.json         # Configuración del proyecto
├── Dockerfile          # Configuración de Docker
└── README.md           # Este archivo
```

## Recursos Adicionales

- [Documentación oficial de n8n](https://docs.n8n.io/)
- [Guía de creación de nodos](https://docs.n8n.io/integrations/creating-nodes/)
- [Repositorio base n8n-nodes-starter](https://github.com/n8n-io/n8n-nodes-starter)

## Licencia

MIT
