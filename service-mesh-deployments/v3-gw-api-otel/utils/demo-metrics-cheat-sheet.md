# Cheat Sheet — Queries Prometheus para demo Bookinfo (v3-gw-api-otel)

**Uso:** Consola OpenShift → **Observe → Metrics**  
**Namespace:** `bookinfo`  
**Rango temporal recomendado:** Last 15 minutes  
**Tráfico previo:** F5 en `/productpage` o `./utils/generate-traffic.sh 20`

---

## Pre-requisitos

- User Workload Monitoring activo (`enableUserWorkload: true`)
- `PodMonitor` `istio-proxies-monitor` en namespace `bookinfo`
- Targets UP en **Observe → Targets**

---

## Descubrir nombres de workload (ejecutar una vez)

```promql
group by (destination_workload, destination_canonical_service) (
  istio_requests_total{namespace="bookinfo"}
)
```

```promql
group by (source_workload, destination_workload, destination_service_name) (
  istio_requests_total{namespace="bookinfo", reporter="source"}
)
```

---

## Escenario OK

### Q1 — Visitas entrantes a productpage (RPS)

*↔ Kiali: Traffic / volumen entrante*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination"
}[5m]))
```

---

### Q2 — Tasa de éxito entrante (%)

*↔ Kiali: indicador verde / Success*

```promql
100 *
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination",
  response_code!~"4..|5.."
}[5m]))
/
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination"
}[5m]))
```

> Incluye **2xx y 3xx** (p. ej. 304 Not Modified al recargar `/productpage`). Solo excluye 4xx/5xx, alineado con Kiali.

---

### Q3 — Errores entrantes (por código HTTP)

*↔ Kiali: Inbound Metrics → errores*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination",
  response_code=~"4..|5.."
}[5m])) by (response_code)
```

---

### Q4 — Latencia p95 entrante (ms)

*↔ Kiali: Inbound Metrics → latencia*

```promql
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket{
    namespace="bookinfo",
    destination_workload=~"productpage.*",
    reporter="destination"
  }[5m])) by (le)
)
```

---

### Q5 — Salida productpage → reviews (RPS)

*↔ Kiali: flecha productpage → reviews*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  source_workload=~"productpage.*",
  destination_workload=~"reviews.*",
  reporter="source"
}[5m]))
```

---

### Q6 — Salida productpage → details (RPS)

*↔ Kiali: flecha productpage → details*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  source_workload=~"productpage.*",
  destination_workload=~"details.*",
  reporter="source"
}[5m]))
```

---

### Q7 — Todas las salidas de productpage (mini grafo)

*↔ Kiali: flechas salientes en Traffic*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  source_workload=~"productpage.*",
  reporter="source"
}[5m])) by (destination_workload)
```

---

### Q8 — Entrada desde el ingress

*↔ Kiali: tráfico externo hacia productpage*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination",
  source_workload=~"istio-ingress.*"
}[5m]))
```

Si no devuelve datos:

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination"
}[5m])) by (source_workload)
```

---

## Escenario FALLO — ratings caído

**Comandos (notas del presentador):**

```bash
# Romper
oc scale deployment ratings-v1 -n bookinfo --replicas=0

# Recuperar
oc scale deployment ratings-v1 -n bookinfo --replicas=1
```

Generar tráfico tras el fallo: F5 × 10 o `./utils/generate-traffic.sh 20`

---

### Q9 — Errores reviews → ratings (causa raíz)

*↔ Kiali: flecha roja reviews → ratings en Traffic Graph*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  source_workload=~"reviews.*",
  destination_workload=~"ratings.*",
  reporter="source",
  response_code=~"4..|5.."
}[5m])) by (response_code)
```

---

### Q10 — reviews → ratings: éxito vs error (comparativa)

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  source_workload=~"reviews.*",
  destination_workload=~"ratings.*",
  reporter="source"
}[5m])) by (response_code)
```

---

### Q11 — Errores productpage → reviews

*↔ Kiali: Outbound Metrics de productpage*

```promql
sum(rate(istio_requests_total{
  namespace="bookinfo",
  source_workload=~"productpage.*",
  destination_workload=~"reviews.*",
  reporter="source",
  response_code=~"4..|5.."
}[5m])) by (response_code)
```

---

### Q12 — Tasa de éxito entrante a productpage (baja con fallo)

*↔ Kiali: nodo productpage deja de estar 100% verde*

```promql
100 *
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination",
  response_code!~"4..|5.."
}[5m]))
/
sum(rate(istio_requests_total{
  namespace="bookinfo",
  destination_workload=~"productpage.*",
  reporter="destination"
}[5m]))
```

---

### Q13 — Latencia p95 de productpage (sube con timeouts)

*↔ Kiali: Inbound Metrics → latencia (comparar antes/después)*

```promql
histogram_quantile(0.95,
  sum(rate(istio_request_duration_milliseconds_bucket{
    namespace="bookinfo",
    destination_workload=~"productpage.*",
    reporter="destination"
  }[5m])) by (le)
)
```

---

## Diagnóstico rápido

### Q14 — Top 20 flujos activos con códigos HTTP

```promql
topk(20,
  sum(rate(istio_requests_total{namespace="bookinfo"}[5m])) by (
    source_workload,
    destination_workload,
    response_code
  )
)
```

---

## Correlación Observe ↔ Kiali (productpage-v1)

| Query | Dónde verlo en Kiali |
|-------|---------------------|
| Q1, Q2, Q3, Q4, Q12, Q13 | Workloads → `productpage-v1` → Service Mesh → **Inbound Metrics** / **Traffic** |
| Q5, Q6, Q7, Q11 | Misma ruta → **Outbound Metrics** / **Traffic** |
| Q8 | Service Mesh → **Traffic Graph** (origen ingress) |
| Q9, Q10 | Service Mesh → **Traffic Graph** (flecha reviews → ratings) |

---

## Orden sugerido en demo

| Paso | Query | Momento |
|------|-------|---------|
| 1 | Q1 | Todo OK — volumen entrante |
| 2 | Q7 | Todo OK — salidas por destino |
| 3 | Q2 | Todo OK — % éxito ~100% |
| 4 | *(apagar ratings)* | Fallo |
| 5 | Q10 | Fallo — reviews→ratings por código |
| 6 | Q9 | Fallo — errores reviews→ratings |
| 7 | Q11 | Fallo — productpage→reviews |
| 8 | Q12 | Fallo — % éxito baja |
| 9 | *(encender ratings)* | Recuperación |
| 10 | Q2 | Recuperación — vuelve a ~100% |

---

## Accesos rápidos en consola

| Recurso | Ruta |
|---------|------|
| Métricas Prometheus | **Observe → Metrics** |
| Targets de scrape | **Observe → Targets** → `istio-proxies-monitor` |
| Mapa de tráfico | **Service Mesh → Traffic Graph** (namespace `bookinfo`) |
| Métricas de productpage | **Workloads → productpage-v1 → Service Mesh** |
| Trazas | Misma ruta → **Traces → Span Details** |
| Bookinfo | `https://bookinfo.<cluster-hostname>/productpage` |
| Grafana — Escenario OK | Carpeta **Bookinfo** → *Bookinfo — Escenario OK* |
| Grafana — Escenario Fallo | Carpeta **Bookinfo** → *Bookinfo — Escenario Fallo* |

---

## Tips

1. Vista **Graph** para series temporales; **Table** para valores actuales.
2. Puedes añadir varias queries en el mismo gráfico (ej. Q5 + Q6).
3. Si no hay datos: genera tráfico, espera 1–2 min y comprueba **Observe → Targets**.
4. Si los nombres de workload no coinciden, usa la query de descubrimiento al inicio.
