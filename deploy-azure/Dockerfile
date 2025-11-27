# Usar la imagen base oficial de n8n
FROM n8nio/n8n:1.107.3

# Cambiar a usuario root para instalar herramientas globales
USER root

# Cargar variables de entorno desde .env
ARG GITHUB_REPO_URL
ENV GITHUB_REPO_URL=${GITHUB_REPO_URL}
ARG GITHUB_REPO_NOMBRE
ENV GITHUB_REPO_NOMBRE=${GITHUB_REPO_NOMBRE}
# Clonar el repositorio en /home/node/qdrant-tool/custom_nodes/
WORKDIR /home
RUN git clone ${GITHUB_REPO_URL}

# Instalar dependencias en el proyecto clonado
WORKDIR /home/${GITHUB_REPO_NOMBRE}
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
RUN chown node:node /home/${GITHUB_REPO_NOMBRE}

RUN mkdir -p /home/node/.n8n/prueba
# Crear la carpeta para los custom nodes dentro de /home/node/
#RUN mkdir -p /home/node/.n8n/custom/node_modules/custom_nodes
# Asignar permisos adecuados
#RUN chmod -R 777 /home/node/.n8n/custom/node_modules/custom_nodes
# Copiar los archivos construidos a la carpeta de custom nodes en n8n
#RUN cp -r /home/qdrant-tool/custom_nodes/* /home/node/.n8n/custom/node_modules/custom_nodes/
# Cambiar al usuario node antes de clonar el repositorio
USER node
# Volver al directorio de trabajo predeterminado
WORKDIR /home/node

# Configuración del entorno
ENV SHELL /bin/sh

# Iniciar n8n
ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
