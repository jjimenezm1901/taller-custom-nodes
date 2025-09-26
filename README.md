# Taller de Nodos Personalizados para n8n

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

### 2. Etiquetar la imagen para Docker Hub

```bash
docker tag taller-custom-nodes xjimenezm/taller-custom-nodes:latest
```

### 3. Hacer login en Docker Hub

```bash
docker login
```

### 4. Subir la imagen

```bash
docker push xjimenezm/taller-custom-nodes:latest
```

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
