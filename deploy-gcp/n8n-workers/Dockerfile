FROM n8nio/n8n:1.113.3

# Cambia a usuario root para permisos de instalación
USER root

# Define argumentos para autenticación en GitHub

# Clona el repositorio privado de nodos custom
WORKDIR /home/node
RUN git clone https://github.com/jjimenezm1901/taller-custom-nodes.git

# Instalación de dependencias del proyecto - SECUENCIA AZURE
WORKDIR /home/node/ailab-n8n-nodes/custom_nodes/

# 1. Instalar pg y tipos PRIMERO (como en Azure)
RUN npm install pg
RUN npm install --save-dev @types/pg
RUN npm install livekit-server-sdk
# 2. Primera instalación de dependencias del proyecto
RUN npm install --include=dev --force

# 3. Limpiar instalaciones anteriores
RUN npm uninstall tsc gulp

# 4. Install Gulp locally
RUN npm install gulp

# 5. Instalación global de devDependencies
RUN npm install -g typescript gulp gulp-cli
RUN npm install -g livekit-server-sdk
# 6. SEGUNDA instalación de dependencias (CLAVE - como en Azure)
RUN npm install --include=dev --force

# 7. Compila los nodos custom
RUN npx tsc && npx gulp build:icons

# Mueve los nodos compilados a la carpeta de `n8n`
RUN mkdir -p /home/node/.n8n && chown node:node /home/node/.n8n

RUN mkdir -p /home/node/.n8n/custom/node_modules \
    && cp -r /home/node/ailab-n8n-nodes/custom_nodes /home/node/.n8n/custom/node_modules/

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENV SHELL=/bin/sh
USER node
WORKDIR /home/node

ENTRYPOINT ["tini", "--", "/docker-entrypoint.sh"]
