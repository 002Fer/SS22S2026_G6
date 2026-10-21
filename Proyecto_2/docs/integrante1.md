# Integrante 1: ingeniería de datos y SQL

## Fuente y destino

- Fuente: `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`.
- Destinos: `proyecto2_taxi.viajes_limpios` y `proyecto2_taxi.resumen_mensual_2022`, en la multirregión `US`.
- Fuente original: **36,256,539** filas. Tabla limpia: **35,535,571** filas (**720,968** excluidas, aproximadamente **1.99 %**).
- Almacenamiento lógico mostrado para la tabla limpia: **7.37 GB**.

## Diagnóstico y limpieza

El diagnóstico previo registró 0 fechas nulas, 30,368 duraciones no positivas, 511,442 distancias nulas o no positivas, 225,608 tarifas nulas o negativas y 556 fechas de inicio fuera de 2022. Las categorías se superponen, por lo que no deben sumarse para obtener los viajes excluidos.

Se conservaron viajes iniciados entre el 1 de enero y el 31 de diciembre de 2022 (UTC), con `dropoff_datetime > pickup_datetime`, `trip_distance > 0` y `fare_amount >= 0`. Se añadieron `fecha_viaje` y `duracion_segundos`. La tabla se particionó diariamente con `DATE(pickup_datetime)` y se clusterizó por `pickup_location_id`, seguido de `dropoff_location_id`. La configuración y las particiones se verificaron mediante `INFORMATION_SCHEMA`.

**Cobertura temporal:** tanto la tabla pública como la tabla limpia contienen solo **57 viajes con inicio en diciembre de 2022**. Los análisis comparativos mensuales usan enero-noviembre; diciembre debe marcarse como incompleto. Esta limitación importa para el split temporal y cualquier pronóstico del integrante 2.

## Comparación de procesamiento

Las consultas estándar y optimizada aplicaron los mismos filtros: enero de 2022, ubicación de origen `161`, duración positiva, distancia positiva y tarifa no negativa. Ambas devolvieron **87,351 viajes** y tarifa promedio **10.38**. Se desactivó la caché.

| Corrida | Consulta | Bytes procesados | Duración |
| --- | --- | ---: | ---: |
| 1 | Estándar | 1.78 GB | 538 ms |
| 1 | Optimizada | 113.91 MB | 559 ms |
| 2 | Estándar | 1.78 GB | 372 ms |
| 2 | Optimizada | 113.91 MB | 268 ms |

La reducción observada fue de aproximadamente **93.6 % de bytes procesados** (1.78 GB frente a 113.91 MB). Los tiempos variaron entre corridas y no permiten afirmar una mejora consistente de duración. La comparación mide el efecto combinado de materialización/limpieza y organización física; no aísla cuánto aporta cada técnica.

## Hallazgos para visualización

- El máximo volumen mensual de enero-noviembre fue octubre (**3,589,854 viajes**); enero registró **2,421,913**. Diciembre no es comparable por la cobertura incompleta de la fuente.
- JFK Airport (`132`) registró **1,680,894** viajes, distancia promedio **16.21**, duración promedio **43.34 minutos** y tarifa promedio **47.05**. Upper East Side South (`237`) registró **1,678,160** viajes, distancia **2.89**, duración **12.90 minutos** y tarifa **9.90**. La diferencia de distancia y duración ayuda a interpretar el contraste de tarifa, pero no prueba causalidad.
- El código de pago `1` concentró **76.74 %** de los viajes de enero-noviembre y el `2`, **19.50 %**. El [diccionario de viajes amarillos de NYC TLC](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf) los define como tarjeta de crédito y efectivo, respectivamente.

## Entrega al integrante 2

La tabla preparada contiene las columnas originales y dos derivadas. Antes de entrenar, se debe definir el objetivo y el momento de predicción: `fare_amount`, `total_amount`, `tip_amount`, `dropoff_datetime` y `duracion_segundos` pueden provocar fuga de información según el objetivo. Diciembre de 2022 no constituye un mes de evaluación representativo en este dataset.

## Segunda tabla derivada para visualización

El script [`sql/04_resumen_mensual.sql`](../sql/04_resumen_mensual.sql) creó `proyecto2_taxi.resumen_mensual_2022` a partir de `viajes_limpios`. Agrupa enero-noviembre de 2022 por mes y calcula cantidad de viajes, distancia promedio, duración promedio en minutos y tarifa promedio. Se excluye diciembre porque la fuente solo contiene 57 viajes de ese mes. La tabla se verificó en BigQuery: contiene **11 filas y 35,535,514 viajes** en total. La consulta de lectura de esta tabla pequeña muestra una estimación de **616 B**; la validación de cantidad de meses y viajes muestra **88 B**.

## Archivos

- `sql/01_exploracion.sql`: esquema, calidad, tendencias, zonas y pagos.
- `sql/02_limpieza.sql`: creación y validación de la tabla limpia.
- `sql/03_optimizacion.sql`: metadatos y consultas comparadas.
- `sql/04_resumen_mensual.sql`: creación y validación del resumen mensual para el dashboard.
- `Integrante1_evidencias/`: capturas recopiladas durante la ejecución en BigQuery.

## Evidencias revisadas

Se inspeccionó el contenido de cada imagen y se asignó un nombre acorde a lo que realmente muestra. Las capturas son evidencia de ejecuciones en BigQuery; los SQL completos están en `sql/`.

| Captura | Qué muestra |
| --- | --- |
| [esquema_fuente_columnas_1_10.png](../Integrante1_evidencias/esquema_fuente_columnas_1_10.png) | Primeras diez de las veinte columnas de la fuente pública y sus tipos. Es una vista parcial del esquema. |
| [conteo_registros.png](../Integrante1_evidencias/conteo_registros.png) | `COUNT(*)` de la fuente: 36,256,539 filas. |
| [diagnostico_calidad.png](../Integrante1_evidencias/diagnostico_calidad.png) | Fechas nulas, duraciones, distancias, tarifas y fechas fuera de 2022. |
| [conteo_viajes_validos.png](../Integrante1_evidencias/conteo_viajes_validos.png) | Consulta con todas las reglas de limpieza: 35,535,571 filas válidas. |
| [creacion_tabla_particion_cluster.png](../Integrante1_evidencias/creacion_tabla_particion_cluster.png) | `CREATE TABLE` completado, con `PARTITION BY` y `CLUSTER BY` visibles. |
| [tabla_particionada_esquema.png](../Integrante1_evidencias/tabla_particionada_esquema.png) | La consola identifica `viajes_limpios` como tabla particionada y muestra su esquema. No muestra por sí sola los campos de clustering. |
| [consulta_estandar_resultado.png](../Integrante1_evidencias/consulta_estandar_resultado.png) | Consulta sobre la fuente pública: 87,351 viajes y tarifa promedio 10.38. |
| [consulta_estandar_trabajo.png](../Integrante1_evidencias/consulta_estandar_trabajo.png) | Segunda corrida estándar: 1.78 GB procesados y 372 ms. |
| [consulta_optimizada_resultado.png](../Integrante1_evidencias/consulta_optimizada_resultado.png) | Misma consulta sobre `viajes_limpios`: 87,351 viajes y tarifa promedio 10.38. |
| [consulta_optimizada_trabajo.png](../Integrante1_evidencias/consulta_optimizada_trabajo.png) | Segunda corrida optimizada: 113.91 MB procesados y 268 ms. |
| [tendencias_mensuales.png](../Integrante1_evidencias/tendencias_mensuales.png) | Viajes, distancia y tarifa promedio por mes; diciembre tiene 57 viajes. |
| [ubicaciones_origen_top10.png](../Integrante1_evidencias/ubicaciones_origen_top10.png) | Los diez ID de origen más frecuentes y su tarifa promedio. |
| [zonas_origen_top10.png](../Integrante1_evidencias/zonas_origen_top10.png) | Los mismos orígenes con nombre de zona y borough obtenido de `taxi_zone_geom`. |
| [tipos_pago.png](../Integrante1_evidencias/tipos_pago.png) | Distribución de `payment_type`, porcentajes y tarifa promedio. |
| [resumen_mensual_2022.png](../Integrante1_evidencias/resumen_mensual_2022.png) | Tabla `resumen_mensual_2022` existente en BigQuery, con sus cinco columnas visibles. Esta imagen muestra el esquema, no el mensaje de creación. |
| [resumen_mensual_resultados.png](../Integrante1_evidencias/resumen_mensual_resultados.png) | Consulta sobre la segunda tabla derivada: 11 meses de enero a noviembre y sus indicadores. |
| [resumen_mensual_validacion.png](../Integrante1_evidencias/resumen_mensual_validacion.png) | Validación de la segunda tabla: 11 meses y 35,535,514 viajes. |

Las consultas de verificación de particiones y orden de clustering están en `sql/03_optimizacion.sql`. No hay una captura local de esos dos resultados de metadatos, aunque sí se verificaron durante la sesión en BigQuery; la captura de creación muestra la configuración declarada.
