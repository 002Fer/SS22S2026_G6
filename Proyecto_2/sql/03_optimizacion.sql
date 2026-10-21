-- Proyecto 2 / Integrante 1: validación de diseño y comparación de consultas.
-- Ejecutar cada SELECT por separado, con resultados almacenados en caché
-- desactivados. El filtro de fecha y ubicación es idéntico en ambas consultas;
-- la fuente de datos cambia de la tabla pública a la tabla limpia optimizada.
-- Los resultados observados de ambas: 87,351 viajes; tarifa promedio 10.38.

-- A. Evidencia de particiones reales (la consola mostró inicialmente 0).
SELECT partition_id, total_rows
FROM `proyecto2_taxi.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = 'viajes_limpios'
ORDER BY partition_id
LIMIT 10;

-- B. Evidencia de configuración: pickup_datetime es partición; los campos
-- pickup_location_id y dropoff_location_id tienen orden de clustering 1 y 2.
SELECT
  column_name,
  is_partitioning_column,
  clustering_ordinal_position
FROM `proyecto2_taxi.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'viajes_limpios'
  AND (
    is_partitioning_column = 'YES'
    OR clustering_ordinal_position IS NOT NULL
  )
ORDER BY clustering_ordinal_position;

-- C. Consulta estándar sobre el origen público.
SELECT
  COUNT(*) AS viajes,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2022-02-01 00:00:00+00'
  AND dropoff_datetime > pickup_datetime
  AND trip_distance > 0
  AND fare_amount >= 0
  AND pickup_location_id = '161';

-- D. Misma consulta sobre la tabla particionada y clusterizada.
SELECT
  COUNT(*) AS viajes,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `proyecto2_taxi.viajes_limpios`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2022-02-01 00:00:00+00'
  AND dropoff_datetime > pickup_datetime
  AND trip_distance > 0
  AND fare_amount >= 0
  AND pickup_location_id = '161';

-- Mediciones de Información del trabajo (caché desactivada):
-- Corrida 1: estándar 1.78 GB / 538 ms; optimizada 113.91 MB / 559 ms.
-- Corrida 2: estándar 1.78 GB / 372 ms; optimizada 113.91 MB / 268 ms.
-- Reducción aproximada de bytes procesados: 93.6 % (~15.6 veces menos).
-- El tiempo no fue estable: una corrida fue 21 ms más lenta y otra 104 ms
-- más rápida. No afirmar una mejora consistente de duración con estos datos.
-- La comparación mide el efecto conjunto de materializar/limpiar, particionar
-- y clusterizar. No aísla la contribución de cada técnica por separado.
