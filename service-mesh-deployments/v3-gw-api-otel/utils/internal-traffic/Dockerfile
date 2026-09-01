# Base ligera Alpine
FROM alpine:3.20

# Información del mantenedor
LABEL maintainer="raul@nostro.es"

# Instalar netcat y openssl sin dejar cache
RUN apk add --no-cache \
    netcat-openbsd \
    openssl \
    curl \
    bash

# Crear usuario no root compatible con OpenShift
RUN adduser -D -u 1001 -h /home/appuser -s /bin/bash appuser && \
    mkdir /app && \
    chown -R appuser:appuser /app

# Cambiar al usuario no root
USER appuser

# Establecer directorio de trabajo
WORKDIR /app

# Copiamos el script que lanza las peticiones a la aplicación 'bookinfo'
COPY generate-traffic.sh .

# Comando por defecto
ENTRYPOINT ["/app/generate-traffic.sh"]
