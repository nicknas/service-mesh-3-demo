#!/bin/bash

# Genera tráfico en el mesh llamando a los endpoints:
#   - /productpage
#   - /api/v1/products
HOSTNAME=productpage.bookinfo.svc.cluster.local:9080
iteraciones=0

echo -e "Usando hostname: $HOSTNAME\n"

# Bucle
while true; do
  ((iteraciones++))
  echo -n "Iteración $iteraciones... "
#  curl -s http://$HOSTNAME/productpage > /dev/null
  http_code_page=$(curl -sk -w "%{http_code}" -o /dev/null http://$HOSTNAME/productpage)
  sleep 0.5
  http_code_json=$(curl -sk -w "%{http_code}" -o /dev/null http://$HOSTNAME/api/v1/products)
  echo -e "(${http_code_page}/${http_code_json})"
done

echo "Ejecución completada."
