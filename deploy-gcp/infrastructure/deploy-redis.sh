#!/bin/bash
set -e

# Cargar variables de entorno
if [ -f .env ]; then
    export $(grep -v '^\s*#' .env | sed 's/\s*#.*$//' | tr '\n' ' ')
fi

# Sufijo de entorno para nombres
ENV_SUFFIX=""
if [ -n "$ENVIRONMENT" ]; then
    ENV_SUFFIX="-$ENVIRONMENT"
fi

REDIS_INSTANCE_NAME="${REDIS_INSTANCE_NAME}${ENV_SUFFIX}"

# Habilitar API
gcloud services enable redis.googleapis.com --project=$PROJECT_ID

echo " # Verificando si la instancia de Redis '$REDIS_INSTANCE_NAME' ya existe..."
if gcloud redis instances describe $REDIS_INSTANCE_NAME --region=$REGION --project=$PROJECT_ID --format="value(name)" >/dev/null 2>&1; then
    echo "  >> La instancia de Redis '$REDIS_INSTANCE_NAME' ya existe."
else
    echo " # Creando instancia de Redis Memorystore"
    gcloud redis instances create $REDIS_INSTANCE_NAME \
        --size=1 \
        --region=$REGION \
        --project=$PROJECT_ID \
        --redis-version=redis_6_x \
        --tier=BASIC \
        --connect-mode=direct-peering \
        --network="projects/${PROJECT_ID}/global/networks/default" \
        --enable-auth --quiet
    echo "  >> Instancia de Redis Memorystore creada."
fi