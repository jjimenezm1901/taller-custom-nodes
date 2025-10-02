#!/bin/bash
set -e

echo " # Iniciando despliegue de N8N en GCP..."

# Cargar variables de entorno desde la raíz del proyecto
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
WORKER_SERVICE_NAME_ENV="${WORKER_SERVICE_NAME}${ENV_SUFFIX}"
DB_INSTANCE_NAME_ENV="${DB_INSTANCE_NAME}${ENV_SUFFIX}"
REDIS_INSTANCE_NAME_ENV="${REDIS_INSTANCE_NAME}${ENV_SUFFIX}"
DB_SECRET_NAME_ENV="${DB_SECRET_NAME}${ENV_SUFFIX}"

# --- Validaciones Iniciales ---
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "ERROR: No hay una cuenta activa de gcloud."
    exit 1
fi
if [ "$PROJECT_ID" = "your-project-id" ]; then
    echo "ERROR: Configura PROJECT_ID en el archivo .env"
    exit 1
fi
if [ -z "$DB_PASSWORD" ] || [ -z "$N8N_ENCRYPTION_KEY" ] || [ -z "$N8N_SERVICE_ACCOUNT_NAME" ]; then
    echo "ERROR: Faltan variables requeridas: DB_PASSWORD, N8N_ENCRYPTION_KEY o N8N_SERVICE_ACCOUNT_NAME"
    exit 1
fi

gcloud config set project $PROJECT_ID

# --- PASO 1: Crear/Verificar Cuenta de Servicio Dedicada ---
echo " # Verificando Cuenta de Servicio dedicada: $N8N_SERVICE_ACCOUNT_NAME"
SA_EMAIL="${N8N_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if gcloud iam service-accounts describe "$SA_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    echo "  >> La Cuenta de Servicio ya existe."
else
    echo " # Creando Cuenta de Servicio..."
    gcloud iam service-accounts create "$N8N_SERVICE_ACCOUNT_NAME" \
        --display-name="Service Account for N8N Cloud Run" \
        --project="$PROJECT_ID"
fi

# --- PASO 1.2: Otorgar permisos necesarios a la Cuenta de Servicio ---
echo " # Asignando roles a la Cuenta de Servicio para Cloud SQL/Secret Manager/Red"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/cloudsql.client"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor"

# Para uso de red 'default' con --network y --vpc-egress en Cloud Run (Gen2)
gcloud services enable compute.googleapis.com --project="$PROJECT_ID"
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/compute.networkUser"

# --- PASO 1.5: Configurar permisos específicos del secreto ---
echo " # Configurando permisos específicos del secreto: $DB_SECRET_NAME_ENV"

# Crear el secreto si no existe
if ! gcloud secrets describe $DB_SECRET_NAME_ENV --project=$PROJECT_ID > /dev/null 2>&1; then
    echo "  >> Creando secreto: $DB_SECRET_NAME_ENV"
    gcloud secrets create $DB_SECRET_NAME_ENV --replication-policy="automatic" --project=$PROJECT_ID
    echo "  >> Secreto creado exitosamente."
else
    echo "  >> El secreto ya existe."
fi

# Asignar permisos específicos al secreto
echo "  >> Asignando permisos al secreto..."
gcloud secrets add-iam-policy-binding $DB_SECRET_NAME_ENV \
    --project=$PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None \
    --quiet

echo "  >> Permisos del secreto configurados."

# --- PASO 2: Autenticar Docker INMEDIATAMENTE ---
echo " # Autenticando Docker"
gcloud services enable artifactregistry.googleapis.com
gcloud auth application-default print-access-token | docker login -u oauth2accesstoken --password-stdin ${REGION}-docker.pkg.dev
echo "  >> Autenticación de Docker completado"

# --- Función para ejecutar scripts de infraestructura ---
run_script() {
    local script_name=$1
    local script_path=$2
    chmod +x "$script_path"
    echo " # Ejecutando: $script_name..."
    if ! "$script_path"; then echo "ERROR: Falló $script_name."; exit 1; fi
    echo "  >> $script_name completado."
}

# --- PASO 3: Desplegar Infraestructura ---
run_script "Despliegue de Redis Memorystore" "../infrastructure/deploy-redis.sh"
run_script "Despliegue de Cloud SQL PostgreSQL" "../infrastructure/deploy-postgresql.sh"

# --- PASO 4: Construir y Subir la Imagen Docker ---
echo " # Construyendo y subiendo la imagen Docker..."
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/cloud-run-source-deploy/n8n-custom:latest"

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_USER y/o GITHUB_TOKEN no están definidos en el archivo .env."
    exit 1
fi

echo "  ## Construyendo imagen con nodos customizados..."
docker build \
    --no-cache \
    -t $IMAGE_NAME ..

echo "  ## Subiendo la imagen a ${IMAGE_NAME}..."
docker push $IMAGE_NAME
echo "  >> Imagen Docker subida."

# --- PASO 5: Obtener detalles de conexión ---
echo " # Obteniendo detalles de conexión..."
DB_CONNECTION_NAME=$(gcloud sql instances describe "$DB_INSTANCE_NAME_ENV" --project="$PROJECT_ID" --format="value(connectionName)")
REDIS_HOST=$(gcloud redis instances describe "$REDIS_INSTANCE_NAME_ENV" --region="$REGION" --project="$PROJECT_ID" --format="value(host)")
REDIS_AUTH=$(gcloud redis instances get-auth-string "$REDIS_INSTANCE_NAME_ENV" --region="$REGION" --project="$PROJECT_ID" --format="value(authString)")
DB_SOCKET_PATH="/cloudsql/${DB_CONNECTION_NAME}"
echo "  >> Detalles de conexión obtenidos."

# --- PASO 6: Desplegar N8N Principal con Sonda de Arranque ---
echo " # Desplegando N8N Principal: $CLOUDRUN_SERVICE_NAME_ENV"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUDRUN_URL="https://${CLOUDRUN_SERVICE_NAME_ENV}-${PROJECT_NUMBER}.${REGION}.run.app"
N8N_HOST="${CLOUDRUN_SERVICE_NAME_ENV}-${PROJECT_NUMBER}.${REGION}.run.app"
COMMON_ENV_VARS="NODE_FUNCTION_ALLOW_BUILTIN=*,NODE_FUNCTION_ALLOW_EXTERNAL=*,N8N_COMMUNITY_PACKAGES_ENABLED=true,N8N_LOG_LEVEL=debug,N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY},DB_TYPE=postgresdb,DB_POSTGRESDB_HOST=${DB_SOCKET_PATH},DB_POSTGRESDB_PORT=5432,DB_POSTGRESDB_DATABASE=${DB_NAME},DB_POSTGRESDB_USER=${DB_USER},DB_POSTGRESDB_SSL=false,DB_POSTGRESDB_SCHEMA=public,EXECUTIONS_MODE=queue,QUEUE_BULL_REDIS_HOST=${REDIS_HOST},QUEUE_BULL_REDIS_PASSWORD=${REDIS_AUTH},QUEUE_BULL_REDIS_PORT=6379,QUEUE_BULL_REDIS_TLS=false,GENERIC_TIMEZONE=America/Lima,ENVIRONMENT=${ENVIRONMENT},N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true"
MAIN_ENV_VARS="WEBHOOK_URL=${CLOUDRUN_URL}/,N8N_HOST=${N8N_HOST},N8N_SECURE_COOKIE=true,N8N_RUNNERS_ENABLED=true,N8N_RUNNERS_MODE=internal,OFFLOAD_MANUAL_EXECUTIONS_TO_WORKERS=true"
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
    --set-env-vars="$COMMON_ENV_VARS,$MAIN_ENV_VARS" \
    --network=default \
    --vpc-egress=private-ranges-only \
    --timeout=600s \
    --startup-probe="httpGet.path=/healthz,httpGet.port=5678,initialDelaySeconds=10,timeoutSeconds=10,periodSeconds=10,failureThreshold=60" \
    --quiet

# --- PASO 7: Obtener la URL y Actualizar el Servicio para Webhooks ---
echo "  >> N8N Principal desplegado en: $CLOUDRUN_URL"

# --- PASO 8: Desplegar N8N Workers con Sonda de Arranque ---
echo " # Desplegando N8N Workers: $WORKER_SERVICE_NAME_ENV"
WORKER_ENV_VARS="SKIP_DB_MIGRATION=true,N8N_HOST=${N8N_HOST},QUEUE_HEALTH_CHECK_ACTIVE=true, N8N_GRACEFUL_SHUTDOWN_TIMEOUT=300,N8N_RUNNERS_ENABLED=false,N8N_CONCURRENCY_PRODUCTION_LIMIT=20"
ALL_WORKER_ENV_VARS="${COMMON_ENV_VARS},${WORKER_ENV_VARS}"

gcloud run deploy "$WORKER_SERVICE_NAME_ENV" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --no-allow-unauthenticated \
    --cpu=1 --memory=2Gi \
    --port=5678 \
    --min-instances=1 --max-instances=20 \
    --execution-environment=gen2 \
    --service-account="$SA_EMAIL" \
    --add-cloudsql-instances="$DB_CONNECTION_NAME" \
    --set-secrets="DB_POSTGRESDB_PASSWORD=${DB_SECRET_NAME_ENV}:latest" \
    --set-env-vars="$ALL_WORKER_ENV_VARS" \
    --network=default \
    --vpc-egress=private-ranges-only \
    --startup-probe="httpGet.path=/healthz,httpGet.port=5678,initialDelaySeconds=10,timeoutSeconds=10,periodSeconds=10,failureThreshold=60" \
    --command="/docker-entrypoint.sh" --args="worker" \
    --timeout=600s \
    --concurrency=10 \
    --quiet

echo "  >> N8N Workers desplegados."
echo " # Despliegue de N8N finalizado con éxito."
