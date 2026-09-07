# Guión de demo — Métricas y trazabilidad en OpenShift

**Entorno:** v3-gw-api-otel  
**Aplicación:** Bookinfo  
**Duración:** ~20 min  
**Público:** no técnico

Consulta también: [demo-metrics-cheat-sheet.md](demo-metrics-cheat-sheet.md) para las queries PromQL de **Observe → Metrics**.

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
| **Inbound Metrics** | "Cuántas entran y si responden bien" |
| **Outbound Metrics** | "A quién pide datos (reseñas, detalles)" |

### 1.4 (Opcional) Métricas en Observe → Metrics (1 min)

**Ruta:** Observe → Metrics → pegar **Q1** y **Q7** del [cheat sheet](demo-metrics-cheat-sheet.md)

> "Esto es la misma información que Kiali, pero en datos brutos.
> Kiali la convierte en mapas y gráficos."

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
> Sin esto habría que revisar logs de cada equipo por separado."

**No usar:** clic en "5 Apps involved" (no es interactivo).

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

- Workloads → productpage-v1 → Service Mesh → **Outbound Metrics** (errores hacia reviews)

**Opción B — Observe → Metrics:**

- **Q10** o **Q9** (reviews→ratings con errores)
- **Q11** (productpage→reviews con errores)

> "Las métricas confirman: las valoraciones no responden, y eso afecta
> a las reseñas y, en cascada, a la experiencia del cliente."

### 3.5 Trazas con error (1 min)

**Ruta:** productpage-v1 → Service Mesh → Traces → punto con error (si aparece rojo) → **Span Details**

Señalar el span en rojo (ratings o reviews→ratings)

> "Esta visita concreta falló exactamente aquí."

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
3. Todo visible **dentro de OpenShift**, sin tocar código de la aplicación
4. Detectar fallos en **dependencias ocultas** (valoraciones) antes que el usuario

**Frase de cierre:**

> "Con Service Mesh y observabilidad integrada en OpenShift, vemos el
> comportamiento real de la aplicación: tráfico sano, errores en cadena
> y el recorrido exacto de cada visita, todo desde la misma consola."

---

## Referencia rápida de navegación

| Quiero mostrar… | Ruta en consola |
|-----------------|-----------------|
| Mapa completo Bookinfo | Service Mesh → Traffic Graph |
| Métricas de productpage | Workloads → productpage-v1 → Service Mesh → Traffic / Inbound / Outbound |
| Una visita paso a paso | Misma ruta → Traces → Span Details |
| Métricas Prometheus raw | Observe → Metrics ([cheat sheet](demo-metrics-cheat-sheet.md)) |
| Comprobar scrape sidecars | Observe → Targets |

---

## Si algo falla en directo

| Problema | Solución |
|----------|----------|
| Grafo/trazas vacíos | Más F5; ampliar a Last 15m |
| No aparece Traces | Verificar tráfico reciente; refrescar consola |
| Queries sin datos | Observe → Targets; comprobar PodMonitor UP |
| ratings no afecta mucho | Alternativa: apagar reviews-v1,v2,v3 (más dramático) |

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
```
