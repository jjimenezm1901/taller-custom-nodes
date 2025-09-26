#!/bin/bash
set -e

echo "=== DESPLIEGUE DE N8N EN GOOGLE CLOUD PLATFORM ==="

# Cargar variables de entorno
if [ -f .env ]; then
    export $(grep -v '^\s*#' .env | sed 's/\s*#.*$//' | tr '\n' ' ')
else
    echo "ERROR: No se encontró el archivo .env en la raíz del proyecto."
    exit 1
fi

# --- Sufijo de entorno para nombres de recursos ---
ENV_SUFFIX=""
if [ -n "$ENVIRONMENT" ]; then
    ENV_SUFFIX="-$ENVIRONMENT"
fi

CLOUDRUN_SERVICE_NAME_ENV="${CLOUDRUN_SERVICE_NAME}${ENV_SUFFIX}"
DB_INSTANCE_NAME_ENV="${DB_INSTANCE_NAME}${ENV_SUFFIX}"
DB_SECRET_NAME_ENV="${DB_SECRET_NAME}${ENV_SUFFIX}"

# --- VALIDACIONES INICIALES ---
echo "1. Validando configuración..."

if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "   ERROR: No hay una cuenta activa de gcloud."
    exit 1
fi
if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "   ERROR: Configura PROJECT_ID en el archivo .env"
    exit 1
fi
if [ -z "$DB_PASSWORD" ] || [ -z "$N8N_ENCRYPTION_KEY" ]; then
    echo "   ERROR: Faltan variables requeridas: DB_PASSWORD o N8N_ENCRYPTION_KEY"
    exit 1
fi

echo "   # Configuración validada"

gcloud config set project $PROJECT_ID

# --- CONFIGURACIÓN DE PERMISOS ---
echo "2. Configurando permisos y APIs..."
SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Habilitar APIs necesarias
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable sqladmin.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable run.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable artifactregistry.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable compute.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable iam.googleapis.com --project=$PROJECT_ID --quiet

# Configurar agente de servicio de Cloud Run
CR_SERVICE_AGENT=$(gcloud beta services identity create --service=run.googleapis.com --project=$PROJECT_ID --format='value(email)')
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${CR_SERVICE_AGENT}" \
    --role="roles/compute.networkUser" \
    --condition=None \
    --quiet

echo "   # APIs y permisos configurados"

# Crear cuenta de servicio si no existe
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --display-name="N8N Service Account" \
        --description="Cuenta de servicio para N8N" \
        --project="$PROJECT_ID"

    # Asignar roles necesarios
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/cloudsql.client" \
        --quiet

    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/secretmanager.secretAccessor" \
        --quiet

    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/run.invoker" \
        --quiet
fi

# Configurar secretos
if ! gcloud secrets describe $DB_SECRET_NAME_ENV --project=$PROJECT_ID > /dev/null 2>&1; then
    gcloud secrets create $DB_SECRET_NAME_ENV --replication-policy="automatic" --project=$PROJECT_ID
fi

gcloud secrets add-iam-policy-binding $DB_SECRET_NAME_ENV \
    --project=$PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None \
    --quiet

# Guardar contraseña en el secreto
if ! gcloud secrets versions list $DB_SECRET_NAME_ENV --project=$PROJECT_ID --format="value(name)" | grep -q .; then
    printf "$DB_PASSWORD" | gcloud secrets versions add $DB_SECRET_NAME_ENV --data-file=- --project=$PROJECT_ID
fi

# Configurar Docker y Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

REPOSITORY_NAME="cloud-run-source-deploy"
if ! gcloud artifacts repositories describe $REPOSITORY_NAME --location=$REGION --project=$PROJECT_ID >/dev/null 2>&1; then
    gcloud artifacts repositories create $REPOSITORY_NAME \
        --repository-format=docker \
        --location=$REGION \
        --project=$PROJECT_ID \
        --quiet
fi

echo "   # Cuenta de servicio y secretos configurados"

# --- DESPLIEGUE DE BASE DE DATOS ---
echo "3. Desplegando PostgreSQL..."
chmod +x ../infrastructure/deploy-postgresql.sh
if ! ../infrastructure/deploy-postgresql.sh; then
    echo "   ERROR: Falló el despliegue de PostgreSQL."
    exit 1
fi
echo "   # PostgreSQL desplegado"

# Obtener detalles de conexión
DB_CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE_NAME_ENV" --project="$PROJECT_ID" --format="value(connectionName)")
DB_SOCKET_PATH="/cloudsql/${DB_CONNECTION_NAME}"

# --- CONSTRUCCIÓN Y DESPLIEGUE ---
echo "4. Construyendo imagen Docker..."
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/n8n-custom:latest"

# Navegar al directorio raíz del proyecto
cd ../..

# Verificar que el Dockerfile existe
if [ ! -f "Dockerfile" ]; then
    echo "   ERROR: No se encontró el Dockerfile en el directorio raíz del proyecto."
    exit 1
fi

# Construir imagen
if [ -n "$GITHUB_REPO_URL" ] && [ -n "$GITHUB_REPO_NOMBRE" ]; then
    docker build \
        --build-arg GITHUB_REPO_URL="$GITHUB_REPO_URL" \
        --build-arg GITHUB_REPO_NOMBRE="$GITHUB_REPO_NOMBRE" \
        -t $IMAGE_NAME .
else
    docker build -t $IMAGE_NAME .
fi

# Subir imagen
docker push $IMAGE_NAME
echo "   # Imagen Docker construida y subida"

# --- DESPLIEGUE DE N8N ---
echo "5. Desplegando N8N en Cloud Run..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUDRUN_URL="https://${CLOUDRUN_SERVICE_NAME_ENV}-${PROJECT_NUMBER}.${REGION}.run.app"
N8N_HOST="${CLOUDRUN_SERVICE_NAME_ENV}-${PROJECT_NUMBER}.${REGION}.run.app"

# Variables de entorno para N8N
ENV_VARS="N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY},DB_TYPE=postgresdb,DB_POSTGRESDB_HOST=${DB_SOCKET_PATH},DB_POSTGRESDB_PORT=5432,DB_POSTGRESDB_DATABASE=${DB_NAME},DB_POSTGRESDB_USER=${DB_USER},DB_POSTGRESDB_SCHEMA=public,DB_POSTGRESDB_SSL=false,WEBHOOK_URL=${CLOUDRUN_URL}/,N8N_HOST=${N8N_HOST},N8N_SECURE_COOKIE=true,N8N_RUNNERS_ENABLED=true,GENERIC_TIMEZONE=America/Lima,ENVIRONMENT=${ENVIRONMENT}"

gcloud run deploy "$CLOUDRUN_SERVICE_NAME_ENV" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --allow-unauthenticated \
    --port=5678 \
    --cpu=2 --memory=2Gi \
    --min-instances=1 --max-instances=3 \
    --execution-environment=gen2 \
    --service-account="$SA_EMAIL" \
    --add-cloudsql-instances="$DB_CONNECTION_NAME" \
    --set-secrets="DB_POSTGRESDB_PASSWORD=${DB_SECRET_NAME_ENV}:latest" \
    --set-env-vars="$ENV_VARS" \
    --timeout=600s \
    --startup-probe="httpGet.path=/healthz,httpGet.port=5678,initialDelaySeconds=10,timeoutSeconds=10,periodSeconds=10,failureThreshold=60" \
    --quiet

echo "   # N8N desplegado exitosamente"
echo ""
echo "=== DESPLIEGUE COMPLETADO ==="
echo "URL: $CLOUDRUN_URL"
echo "Servicio: $CLOUDRUN_SERVICE_NAME_ENV"
echo "Región: $REGION"


