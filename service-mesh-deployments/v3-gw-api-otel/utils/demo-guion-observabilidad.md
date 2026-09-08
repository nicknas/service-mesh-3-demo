# Guión de demo — Métricas, trazas y logs en OpenShift

**Entorno:** v3-gw-api-otel  
**Aplicación:** Bookinfo  
**Duración:** ~25 min  
**Público:** no técnico

Consulta también:

* [demo-metrics-cheat-sheet.md](demo-metrics-cheat-sheet.md) — queries PromQL de **Observe → Metrics**
* [README.adoc](../README.adoc) — arquitectura del stack de logging (Loki + Alloy)

---

## La historia (30 segundos de intro)

> "Bookinfo es una tienda online de libros. Cuando un cliente abre la página
> de un producto, la aplicación pide datos a varios equipos internos: los
> detalles del libro, las reseñas de lectores y las valoraciones con estrellas.
> OpenShift nos permite ver en tiempo real cómo viajan esas visitas, si algo
> falla y dónde exactamente."

**Flujo simplificado:**

```
Cliente → Página del producto → Detalles del libro
                              → Reseñas → Valoraciones (estrellas)
```

---

## Pre-flight (antes de la audiencia)

- [ ] Bookinfo accesible: `https://bookinfo.<cluster>/productpage`
- [ ] Menú **Service Mesh** visible en consola
- [ ] Generar tráfico previo: `./utils/generate-traffic.sh 20` o 15× F5
- [ ] Grafana accesible con datasources **Prometheus**, **Tempo** y **Loki**
- [ ] Pods de logging en ejecución: `oc get pods -n logging-system` → `logging-loki` y `logging-alloy` Running
- [ ] Tener a mano (segunda pantalla / notas):
  - Comando fallo: `oc scale deployment ratings-v1 -n bookinfo --replicas=0`
  - Comando recuperación: `oc scale deployment ratings-v1 -n bookinfo --replicas=1`
- [ ] Capturas de respaldo: `images/trafico-kiali.png`, `images/trazas-kiali.png`

---

## ACTO 1 — "Todo funciona" (~6 min)

### 1.1 Mostrar la aplicación (1 min)

1. Abrir Bookinfo en el navegador → `/productpage`
2. Recargar 3–4 veces
3. Señalar que a veces las reseñas cambian de aspecto (versiones distintas)

> "Hay varias versiones del servicio de reseñas funcionando a la vez;
> el sistema reparte las visitas entre ellas."

### 1.2 Mapa de tráfico global (2 min)

**Ruta:** Service Mesh → **Traffic Graph** → namespace `bookinfo`

Señalar:

- Nodos: productpage, reviews, details, ratings
- Flechas verdes = tráfico sano
- Panel derecho: **Success ~100%**, **Error ~0%**

> "Cada caja es un equipo. Cada flecha es tráfico real. El grosor indica
> volumen; el color, si va bien o mal."

### 1.3 Métricas de la página del producto (2 min)

**Ruta:** Workloads → `bookinfo` → `productpage-v1` → pestaña **Service Mesh**

Recorrer subpestañas:

| Subpestaña | Qué decir |
|------------|-----------|
| **Traffic** | "Visitas a esta página y hacia quién llama" |
| **Inbound Metrics** | "Cuántas entran y si responden bien" (2xx y 3xx cuentan como éxito; 304 es caché al recargar) |
| **Outbound Metrics** | "A quién pide datos (reseñas, detalles)" |

### 1.4 Grafana — métricas y logs (2 min)

**Ruta:** Grafana → carpeta **Bookinfo**

| Dashboard / vista | Cuándo usarlo | Qué muestra |
|-------------------|---------------|-------------|
| **Bookinfo — Escenario OK** | Tráfico normal | Queries Q1–Q8 (métricas) |
| **Bookinfo — Escenario Fallo** | Tras apagar ratings | Queries Q9–Q13 (métricas) |
| **Bookinfo — Logs** | Siempre que haya tráfico reciente | Logs de productpage, reviews, details, ratings |

En **Bookinfo — Logs**:

1. Variable **Service**: `productpage`, `reviews`, `details` o `ratings`
2. Variable **Version**: `v1`, `v2`, `v3` (reviews) o *All*
3. Campo **Search**: texto libre (p. ej. `GET`, `error`, `503`)

> "Además de métricas y trazas, centralizamos los logs de cada equipo
> en un solo sitio. No hace falta entrar pod a pod con `oc logs`."

**Alternativa rápida:** Grafana → **Explore** → **Logs** → datasource **Loki**:

```logql
{namespace="bookinfo", app="productpage"}
```

Los nombres legibles en Explore son `productpage`, `reviews`, `details`, `ratings`
(etiqueta `service_name`). Si ves `loki.source.kubernetes.bookinfo`, son logs
antiguos: acota el rango temporal a *Last 5 minutes*.

---

## ACTO 2 — "Seguir una visita concreta" (~4 min)

### 2.1 Generar tráfico fresco

F5 en `/productpage` × 10 (o script en background)

### 2.2 Trazas en productpage

**Ruta:** Workloads → `productpage-v1` → Service Mesh → **Traces**

1. Scatterplot: cada punto azul = una visita
2. Clic en un punto reciente
3. Panel inferior: "X Spans", "Y Apps involved" → **solo indicadores, no botones**
4. Pestaña **Span Details** → cascada/waterfall

Recorrer de arriba abajo:

> "Esta visita concreta entró por aquí, pasó por la página del producto,
> pidió detalles y reseñas, y las reseñas consultaron las valoraciones.
> Las trazas muestran el recorrido; los logs (Grafana → Bookinfo — Logs)
> muestran qué escribió cada equipo en ese momento."

**No usar:** clic en "5 Apps involved" (no es interactivo).

### 2.3 Logs de la misma visita (1 min)

**Ruta:** Grafana → **Bookinfo — Logs** (o Explore → Logs → Loki)

1. Filtrar **Service** = `productpage`
2. Rango temporal: *Last 5 minutes*
3. Señalar líneas de gunicorn / peticiones HTTP

> "Cada microservicio escribe en su propio log. Si algo falla, podemos
> correlacionar: primero la traza (dónde), luego el log (qué dijo el proceso)."

**Opcional:** desde Tempo, abrir una traza y usar el enlace a logs relacionados
(configurado en el datasource Tempo → Loki).

---

## ACTO 3 — "Algo se rompe" (~6 min)

### 3.1 Provocar el fallo (notas presentador)

```bash
oc scale deployment ratings-v1 -n bookinfo --replicas=0
```

> "Vamos a simular que el servicio de valoraciones (estrellas) deja de funcionar."

### 3.2 Efecto en el navegador (1 min)

Recargar `/productpage` varias veces:

- La ficha puede cargar parcialmente
- Reseñas/estrellas fallan o tardan

### 3.3 Mapa con errores (2 min)

**Ruta:** Service Mesh → Traffic Graph

Señalar:

- Flecha **reviews → ratings** en rojo o con % de error
- Panel derecho: Success baja

> "El mapa detecta el problema antes de que alguien abra un ticket.
> El fallo no está en la puerta de entrada, está en esta dependencia."

### 3.4 Métricas del fallo (2 min)

**Opción A — Kiali:**

- Service Mesh → **Traffic Graph** → flecha **reviews → ratings** en rojo (503)

**Opción B — Grafana:**

- Carpeta **Bookinfo** → **Bookinfo — Escenario Fallo**
- **Q9/Q10:** errores `503 UH` en reviews→ratings (usa `destination_service_name=ratings`)
- **Q12:** baja la tasa de éxito reviews→ratings (no la de productpage, que sigue en 200)

**Opción C — Observe → Metrics:**

- **Q9** o **Q10** (reviews→ratings con errores 503 UH)
- **Q12** (tasa de éxito reviews→ratings baja)

> "Las métricas confirman el fallo en reviews→ratings. La página productpage
> puede seguir respondiendo 200 aunque las valoraciones no estén disponibles."

### 3.5 Trazas con error (1 min)

**Ruta:** productpage-v1 → Service Mesh → Traces → punto con error (si aparece rojo) → **Span Details**

Señalar el span en rojo (ratings o reviews→ratings)

> "Esta visita concreta falló exactamente aquí."

### 3.6 Logs del fallo (1 min)

**Ruta:** Grafana → **Bookinfo — Logs**

1. **Service** = `reviews` → buscar mensajes de error al llamar a ratings
2. **Service** = `productpage` → suele seguir en INFO (la página responde aunque ratings esté caído)

> "Las métricas dicen *cuántos* errores hay; los logs dicen *qué* vio
> el proceso cuando intentó llamar al servicio caído."

---

## ACTO 4 — "Recuperación" (~2 min)

```bash
oc scale deployment ratings-v1 -n bookinfo --replicas=1
```

1. Recargar Bookinfo → página OK
2. Traffic Graph → todo verde de nuevo (esperar 30–60 s)
3. (Opcional) Q2 del cheat sheet → vuelve a ~100%

> "Arreglamos el servicio y la consola lo confirma al momento."

---

## ACTO 5 — Cierre (~2 min)

**Mensajes clave:**

1. **Métricas** = "cuántas visitas, cuántas fallan, cuánto tardan" (mapas y gráficos)
2. **Trazas** = "qué pasó en esta visita concreta" (Span Details)
3. **Logs** = "qué escribió cada equipo en ese momento" (Grafana → Bookinfo — Logs)
4. Todo visible **dentro de OpenShift**, sin tocar código de la aplicación
5. Detectar fallos en **dependencias ocultas** (valoraciones) antes que el usuario

**Frase de cierre:**

> "Con Service Mesh y observabilidad integrada en OpenShift, vemos el
> comportamiento real de la aplicación: tráfico sano, errores en cadena,
> el recorrido exacto de cada visita y los logs de cada equipo, todo desde
> la misma consola y Grafana."

---

## Referencia rápida de navegación

| Quiero mostrar… | Ruta en consola |
|-----------------|-----------------|
| Mapa completo Bookinfo | Service Mesh → Traffic Graph |
| Métricas de productpage | Workloads → productpage-v1 → Service Mesh → Traffic / Inbound / Outbound |
| Una visita paso a paso | Misma ruta → Traces → Span Details |
| Métricas Prometheus raw | Observe → Metrics o Grafana → Bookinfo ([cheat sheet](demo-metrics-cheat-sheet.md)) |
| Logs de un servicio | Grafana → Bookinfo — Logs o Explore → Loki (`{namespace="bookinfo", app="…"}`) |
| Comprobar scrape sidecars | Observe → Targets |
| Comprobar colector de logs | `oc get pods -n logging-system` |

---

## Si algo falla en directo

| Problema | Solución |
|----------|----------|
| Grafo/trazas vacíos | Más F5; ampliar a Last 15m |
| No aparece Traces | Verificar tráfico reciente; refrescar consola |
| Queries sin datos | Observe → Targets; comprobar PodMonitor UP |
| ratings no afecta mucho | Alternativa: apagar reviews-v1,v2,v3 (más dramático) |
| Logs vacíos en Grafana | Generar tráfico; rango *Last 15m*; `oc get pods -n logging-system` |
| Aparece `loki.source.kubernetes.bookinfo` | Logs viejos; filtrar por `app` o acotar a últimos 5 min |
| No sale dashboard Bookinfo — Logs | Sincronizar Argo apps `logging` y `grafana`; reiniciar deployment Grafana |

---

## Comandos del presentador (no mostrar en pantalla)

```bash
# Tráfico
./utils/generate-traffic.sh 30

# Fallo
oc scale deployment ratings-v1 -n bookinfo --replicas=0

# Recuperación
oc scale deployment ratings-v1 -n bookinfo --replicas=1

# Verificación rápida
oc get pods -n bookinfo
oc get podmonitor istio-proxies-monitor -n bookinfo
oc get pods -n logging-system
oc exec -n logging-system deploy/logging-loki -- \
  wget -qO- 'http://localhost:3100/loki/api/v1/label/app/values'
```

---

## Anexo — Qué se desplegó para logging (referencia presentador)

### Problema inicial

El stack solo tenía **métricas** (Prometheus/Kiali) y **trazas** (OTel → Tempo). Los logs de Bookinfo no se centralizaban: había que usar `oc logs` pod a pod. Además, `reviews` escribía en archivos (`/tmp/logs`) que ningún colector leía.

### Solución implementada

| Pieza | Fichero / chart | Función |
|-------|-----------------|---------|
| **Loki** | `helm-charts/logging` | Almacén de logs (PVC 5 GiB, retención 7 días) |
| **Grafana Alloy** | mismo chart | Lee stdout de pods `bookinfo` vía API Kubernetes |
| **Argo CD app** | `13-logging.yaml` | Despliega namespace `logging-system` |
| **Grafana Loki DS** | `helm-charts/grafana` | Consulta logs desde dashboards y Explore |
| **Dashboard logs** | `configmap-dashboard-bookinfo-logs.yaml` | Panel con filtros por servicio y versión |
| **Bookinfo fix** | `bookinfo-application.yaml` | Eliminado `LOG_DIR` en reviews → stdout |

### Flujo de datos

```
productpage / reviews / details / ratings (stdout)
    → Alloy (filtra istio-proxy, etiqueta app/version)
    → Loki
    → Grafana (Explore o dashboard Bookinfo — Logs)
```

### Orden de despliegue Argo

`11 observability` → `13 logging` → `12 grafana` (Grafana necesita la URL de Loki).

### Qué NO recoge (decisión de demo)

* Logs del sidecar Envoy (`istio-proxy`)
* OpenShift ClusterLogForwarder / operador de logging de plataforma
* Archivos en disco dentro del contenedor (solo stdout)

### Correlación trazas ↔ logs

El datasource **Tempo** en Grafana tiene `tracesToLogs` apuntando a **Loki** (namespace `bookinfo`), para saltar de una traza a logs del mismo intervalo.
