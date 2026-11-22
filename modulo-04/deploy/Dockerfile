# Imagen oficial de Microsoft Data API Builder
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest

# Argumento de compilación para seleccionar el entorno (development, staging, production)
ARG ENVIRONMENT=production

# Copiar configuración base y la sobrescritura específica del entorno
COPY ../config/dab-config.json /App/dab-config.json
COPY ../config/dab-config.${ENVIRONMENT}.json /App/dab-config.${ENVIRONMENT}.json

# Variables de entorno de ejecución (la cadena de conexión se inyecta en runtime)
ENV DAB_ENVIRONMENT=${ENVIRONMENT}
ENV DATABASE_CONNECTION_STRING=""
ENV ASPNETCORE_URLS="http://+:5000"

EXPOSE 5000