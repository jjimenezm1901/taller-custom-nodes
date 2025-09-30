# Usar la imagen base oficial de n8n
FROM n8nio/n8n:1.107.3

# Cambiar a usuario root para instalar herramientas globales
USER root

# Cargar variables de entorno desde .env
ARG GITHUB_REPO_URL
ENV GITHUB_REPO_URL=${GITHUB_REPO_URL}
ARG GITHUB_REPO_NOMBRE
ENV GITHUB_REPO_NOMBRE=${GITHUB_REPO_NOMBRE}

#ENV DB_TYPE=postgresdb
#ENV DB_POSTGRESDB_HOST=postgres
#ENV DB_POSTGRESDB_PORT=5432
#ENV DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
#ENV DB_POSTGRESDB_USER=${POSTGRES_NON_ROOT_USER}
#ENV DB_POSTGRESDB_PASSWORD=${POSTGRES_NON_ROOT_PASSWORD}
#ENV EXECUTIONS_MODE=regular
#ENV N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
#ENV N8N_HOST=${N8N_HOST}
#ENV WEBHOOK_URL=${WEBHOOK_URL}
#ENV N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
ENV GENERIC_TIMEZONE=America/Lima
ENV NODE_FUNCTION_ALLOW_BUILTIN=*
ENV NODE_FUNCTION_ALLOW_EXTERNAL=*
ENV N8N_COMMUNITY_PACKAGES_ENABLED=true
ENV N8N_CUSTOM_EXTENSIONS=/home/node/.n8n/custom/node_modules/
ENV N8N_COMMUNITY_PACKAGES_ALLOW_TOOL_USAGE=true

# Clonar el repositorio en /home/node/${GITHUB_REPO_NOMBRE}/custom_nodes/
WORKDIR /home/node
RUN git clone ${GITHUB_REPO_URL}

# Instalar dependencias en el proyecto clonado
WORKDIR /home/node/${GITHUB_REPO_NOMBRE}
RUN npm i pg
RUN npm i --save-dev @types/pg
RUN npm install --include=dev --force
RUN npm uninstall tsc gulp
#Install Gulp locally
RUN npm install gulp
# Instalación global de devDependencies
RUN npm install -g typescript gulp gulp-cli
# Compila los nodos custom
RUN npm install --include=dev --force
RUN npx tsc && npx gulp build:icons
RUN chown node:node /home/node/${GITHUB_REPO_NOMBRE}

# Crear directorio para nodos custom
RUN mkdir -p /home/node/.n8n/custom/node_modules

# Copiar el proyecto compilado a la ubicación correcta
RUN cp -r /home/node/${GITHUB_REPO_NOMBRE} /home/node/.n8n/custom/node_modules/

# Ajustar permisos
RUN chown -R node:node /home/node/.n8n

# Cambiar a usuario node
USER node

# Volver al directorio de trabajo predeterminado
WORKDIR /home/node

# Configuración del entorno
ENV SHELL /bin/sh

# Iniciar n8n
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
