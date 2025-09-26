#!/bin/bash
set -e

echo "=== CONFIGURACIÓN DE POSTGRESQL ==="

# Cargar variables de entorno
if [ -f .env ]; then
    export $(grep -v '^\s*#' .env | sed 's/\s*#.*$//' | tr '\n' ' ')
fi

# Sufijo de entorno para nombres
ENV_SUFFIX=""
if [ -n "$ENVIRONMENT" ]; then
    ENV_SUFFIX="-$ENVIRONMENT"
fi

DB_INSTANCE_NAME="${DB_INSTANCE_NAME}${ENV_SUFFIX}"
DB_SECRET_NAME="${DB_SECRET_NAME}${ENV_SUFFIX}"

# Habilitar APIs
gcloud services enable sqladmin.googleapis.com --project=$PROJECT_ID --quiet
gcloud services enable secretmanager.googleapis.com --project=$PROJECT_ID --quiet

# --- INSTANCIA DE CLOUD SQL ---
echo "1. Configurando instancia de PostgreSQL..."
if ! gcloud sql instances describe $DB_INSTANCE_NAME --project=$PROJECT_ID --format="value(name)" >/dev/null 2>&1; then
    gcloud sql instances create $DB_INSTANCE_NAME \
        --database-version=POSTGRES_14 \
        --tier=db-custom-1-3840 \
        --region=$REGION \
        --project=$PROJECT_ID \
        --storage-size=10GB \
        --storage-type=SSD
fi
echo "   # Instancia PostgreSQL configurada"

# --- BASE DE DATOS ---
echo "2. Configurando base de datos..."
if ! gcloud sql databases describe $DB_NAME --instance=$DB_INSTANCE_NAME --project=$PROJECT_ID --format="value(name)" >/dev/null 2>&1; then
    gcloud sql databases create $DB_NAME --instance=$DB_INSTANCE_NAME --project=$PROJECT_ID
fi
echo "   # Base de datos configurada"

# --- USUARIO ---
echo "3. Configurando usuario de base de datos..."
if ! gcloud sql users list --instance=$DB_INSTANCE_NAME --project=$PROJECT_ID --format="value(name)" | grep -w $DB_USER >/dev/null 2>&1; then
    gcloud sql users create $DB_USER --instance=$DB_INSTANCE_NAME --project=$PROJECT_ID --password=$DB_PASSWORD
fi
gcloud sql users set-password $DB_USER --instance=$DB_INSTANCE_NAME --project=$PROJECT_ID --password=$DB_PASSWORD
echo "   # Usuario configurado"

# --- SECRET MANAGER ---
echo "4. Configurando Secret Manager..."
if ! gcloud secrets describe $DB_SECRET_NAME --project=$PROJECT_ID > /dev/null 2>&1; then
    gcloud secrets create $DB_SECRET_NAME --replication-policy="automatic" --project=$PROJECT_ID
fi
printf "$DB_PASSWORD" | gcloud secrets versions add $DB_SECRET_NAME --data-file=- --project=$PROJECT_ID
echo "   # Contraseña guardada en Secret Manager"

# --- PERMISOS ---
if [ -n "$N8N_SERVICE_ACCOUNT_NAME" ]; then
    SA_EMAIL="${N8N_SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    gcloud secrets add-iam-policy-binding $DB_SECRET_NAME \
        --project=$PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/secretmanager.secretAccessor" \
        --condition=None \
        --quiet
fi

echo ""
echo "=== POSTGRESQL CONFIGURADO ==="
echo "Instancia: $DB_INSTANCE_NAME"
echo "Base de datos: $DB_NAME"
echo "Usuario: $DB_USER"
