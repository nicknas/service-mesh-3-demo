#!/bin/bash

# Genera tráfico en el mesh llamando a los endpoints:
#   - /productpage
#   - /api/v1/products
HOSTNAME=bookinfo.rabadillo.tia.com

echo -e "Usando hostname: $HOSTNAME\n"

# Comprobar que se ha pasado un argumento
if [ $# -ne 1 ]; then
  echo "Uso: $0 <numero_de_iteraciones>"
  exit 1
fi

ITERACIONES=$1

# Validar que es un número entero positivo
if ! [[ "$ITERACIONES" =~ ^[0-9]+$ ]]; then
  echo "Error: el parámetro debe ser un número entero positivo."
  exit 1
fi

# Validar que es mayor que 0
if [ "$ITERACIONES" -le 0 ]; then
  echo "Error: el número debe ser mayor que 0."
  exit 1
fi

# Bucle
for ((i=1; i<=ITERACIONES; i++)); do
  echo -n "Iteración $i... "
#  curl -s http://$HOSTNAME/productpage > /dev/null
  http_code_page=$(curl -sk -w "%{http_code}" -o /dev/null http://$HOSTNAME/productpage)
  sleep 0.5
  http_code_json=$(curl -sk -w "%{http_code}" -o /dev/null http://$HOSTNAME/api/v1/products)
  echo -e "(${http_code_page}/${http_code_json})"
done

echo "Ejecución completada."
