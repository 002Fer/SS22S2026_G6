# Proyecto 2 — NYC Yellow Taxi Trips 2022

Repositorio del análisis de viajes de taxi de Nueva York en BigQuery. Este README reúne el trabajo de ingeniería de datos del integrante 1 y deja los insumos para los integrantes de Machine Learning y visualización. Las secciones de modelos y dashboard se completarán con sus respectivas entregas.

## Tabla preparada

| Recurso | Valor |
| --- | --- |
| Proyecto de Google Cloud | `project-2694859a-c78d-43b5-952` |
| Dataset propio | `proyecto2_taxi` |
| Tabla para el equipo | `project-2694859a-c78d-43b5-952.proyecto2_taxi.viajes_limpios` |
| Ubicación | `US` |
| Fuente pública | `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` |
| Filas originales / preparadas | 36,256,539 / 35,535,571 |

La tabla conserva las columnas de la fuente y agrega `fecha_viaje` y `duracion_segundos`. Se filtraron viajes con inicio fuera de 2022, fecha final no posterior al inicio, distancia no positiva o tarifa nula/negativa. Está particionada por `DATE(pickup_datetime)` y clusterizada por `pickup_location_id`, `dropoff_location_id`. Los [scripts de limpieza](sql/02_limpieza.sql), [comparación](sql/03_optimizacion.sql) y la [documentación del integrante 1](docs/integrante1.md) describen la implementación y sus resultados.

Para el dashboard se creó una segunda tabla derivada, `project-2694859a-c78d-43b5-952.proyecto2_taxi.resumen_mensual_2022`, mediante el [script de resumen mensual](sql/04_resumen_mensual.sql). Contiene **11 filas**, una por mes de enero a noviembre, y suma **35,535,514 viajes**. Su existencia, contenido y total están respaldados por las [capturas de evidencia](docs/integrante1.md#evidencias-revisadas).

> **Cobertura temporal:** la fuente pública contiene solo **57 viajes con inicio en diciembre de 2022**; la tabla limpia conserva esos mismos 57. Enero-noviembre son el intervalo utilizado para comparar tendencias. Diciembre debe tratarse como un mes incompleto al preparar modelos o visualizaciones.

## Instrucciones para el equipo

Todos los integrantes usan la misma cuenta de Google Cloud, por lo que pueden abrir la tabla indicada arriba en BigQuery Studio.

### Integrante 2 — Machine Learning

1. Leer `proyecto2_taxi.viajes_limpios` como fuente de entrenamiento y evaluación.
2. Definir el objetivo y el instante en que se pretende predecir. Excluir de las entradas cualquier columna conocida solo después de ese instante. Según el objetivo, `fare_amount`, `total_amount`, `tip_amount`, `dropoff_datetime` o `duracion_segundos` pueden causar *data leakage*.
3. Definir y justificar el split de entrenamiento/evaluación teniendo en cuenta que diciembre contiene solo 57 viajes. No tratar ese mes como un periodo completo.
4. Guardar los scripts de modelos, métricas y predicciones en el repositorio e informar al integrante 3 qué tablas/resultados puede visualizar.

### Integrante 3 — Visualización y documentación final

1. Usar `proyecto2_taxi.resumen_mensual_2022` para series mensuales; las consultas de [exploración](sql/01_exploracion.sql) sirven para zonas de origen y métodos de pago.
2. Para tendencias comparables, mostrar enero-noviembre de 2022 o señalar explícitamente la cobertura incompleta de diciembre.
3. Incorporar los hallazgos y la [evidencia del integrante 1](docs/integrante1.md#evidencias-revisadas) al informe final; completar este README con los modelos, métricas, predicciones y enlace al dashboard.

## Optimización medida

Se comparó una consulta de enero de 2022 y origen `161` sobre la fuente pública y sobre la tabla preparada, con los mismos filtros y la caché desactivada. Ambas devolvieron **87,351 viajes** y tarifa promedio **10.38**. Los bytes procesados bajaron de **1.78 GB** a **113.91 MB**, aproximadamente **93.6 % menos**. La duración varió entre dos corridas; las mediciones y sus límites están en [integrante1.md](docs/integrante1.md#comparación-de-procesamiento). Esta comparación refleja conjuntamente la materialización/limpieza y el diseño físico de la tabla.

## Archivos

```text
Proyecto_2/
├── README.md
├── sql/
│   ├── 01_exploracion.sql
│   ├── 02_limpieza.sql
│   ├── 03_optimizacion.sql
│   └── 04_resumen_mensual.sql
├── docs/
│   └── integrante1.md
└── Integrante1_evidencias/
    └── *.png
```

Los bloques SQL de exploración y optimización se ejecutan por separado. La tabla `viajes_limpios` ya fue creada; `02_limpieza.sql` conserva la sentencia de creación para reproducir el proceso en un dataset nuevo. Las capturas están identificadas y enlazadas en la [sección de evidencias](docs/integrante1.md#evidencias-revisadas).

## Dashboard y visualización

El dashboard del proyecto se desarrolló con Looker Studio utilizando datos procesados en BigQuery.

Incluye:
- Evolución mensual de viajes.
- Distribución por tipo de pago.
- Top 10 zonas de recogida.
- Comparación de duración real y predicha de los modelos.

**Documentación técnica:** [`docs/Integrante3.md`](docs/integrante3.md)

**Dashboard:** [Abrir informe de Looker Studio](https://datastudio.google.com/u/4/reporting/75bae33d-f682-4a09-8436-ba599f8e2afb/page/FGqBG/edit)
