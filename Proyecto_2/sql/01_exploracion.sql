-- Proyecto 2 / Integrante 1: exploración de NYC Yellow Taxi Trips 2022.
-- Ejecutar cada sentencia por separado en BigQuery Studio. El proyecto de
-- ejecución debe ser el que contiene el dataset proyecto2_taxi (ubicación US).
-- Fuente: bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022

-- 1. Estructura de la tabla pública.
SELECT column_name, data_type
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'tlc_yellow_trips_2022'
ORDER BY ordinal_position;

-- 2. Volumen original. Resultado observado: 36,256,539 filas.
SELECT COUNT(*) AS total_registros
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- 3. Diagnóstico de calidad previo a cualquier eliminación.
-- Resultados observados: 0 fechas nulas; 30,368 duraciones no positivas;
-- 511,442 distancias nulas/no positivas; 225,608 tarifas nulas/negativas;
-- 556 fechas de inicio fuera de 2022. Estas categorías pueden superponerse.
SELECT
  COUNT(*) AS total_registros,
  COUNTIF(pickup_datetime IS NULL) AS pickup_nulo,
  COUNTIF(dropoff_datetime IS NULL) AS dropoff_nulo,
  COUNTIF(dropoff_datetime <= pickup_datetime) AS duracion_no_positiva,
  COUNTIF(trip_distance IS NULL OR trip_distance <= 0) AS distancia_invalida,
  COUNTIF(fare_amount IS NULL OR fare_amount < 0) AS tarifa_invalida,
  COUNTIF(
    pickup_datetime < TIMESTAMP '2022-01-01 00:00:00+00'
    OR pickup_datetime >= TIMESTAMP '2023-01-01 00:00:00+00'
  ) AS pickup_fuera_de_2022,
  MIN(pickup_datetime) AS primera_fecha,
  MAX(pickup_datetime) AS ultima_fecha
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- 4. Filas que cumplen simultáneamente las reglas de limpieza.
-- Resultado observado: 35,535,571 filas válidas (720,968 excluidas).
SELECT COUNT(*) AS viajes_validos
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2023-01-01 00:00:00+00'
  AND dropoff_datetime > pickup_datetime
  AND trip_distance > 0
  AND fare_amount >= 0;

-- 5. Viajes, distancia y tarifa promedio por mes en la tabla preparada.
-- Diciembre muestra solo 57 viajes; no compararlo con meses completos.
SELECT
  DATE_TRUNC(DATE(pickup_datetime), MONTH) AS mes,
  COUNT(*) AS viajes,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `proyecto2_taxi.viajes_limpios`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2023-01-01 00:00:00+00'
GROUP BY mes
ORDER BY mes;

-- 6. Verificación de diciembre en el origen: también contiene 57 viajes.
-- La caída de diciembre no fue causada por las reglas de limpieza.
SELECT COUNT(*) AS viajes_diciembre_original
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= TIMESTAMP '2022-12-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2023-01-01 00:00:00+00';

-- 7. Diez ubicaciones de origen con mayor volumen, enero-noviembre.
SELECT
  pickup_location_id,
  COUNT(*) AS viajes,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `proyecto2_taxi.viajes_limpios`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2022-12-01 00:00:00+00'
  AND pickup_location_id IS NOT NULL
GROUP BY pickup_location_id
ORDER BY viajes DESC
LIMIT 10;

-- 8. Esquema de la tabla pública que traduce zone_id a nombre y borough.
SELECT column_name, data_type
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'taxi_zone_geom'
ORDER BY ordinal_position;

-- 9. Top 10 de orígenes con nombre de zona. Agregar antes del JOIN evita
-- incluir la geometría en el cálculo de viajes y mantiene el resultado pequeño.
WITH zonas_principales AS (
  SELECT
    pickup_location_id,
    COUNT(*) AS viajes,
    ROUND(AVG(fare_amount), 2) AS tarifa_promedio
  FROM `proyecto2_taxi.viajes_limpios`
  WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
    AND pickup_datetime < TIMESTAMP '2022-12-01 00:00:00+00'
    AND pickup_location_id IS NOT NULL
  GROUP BY pickup_location_id
  ORDER BY viajes DESC
  LIMIT 10
)
SELECT
  p.pickup_location_id,
  z.zone_name,
  z.borough,
  p.viajes,
  p.tarifa_promedio
FROM zonas_principales AS p
LEFT JOIN `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom` AS z
  ON p.pickup_location_id = z.zone_id
ORDER BY p.viajes DESC;

-- 10. Contraste de JFK Airport (132) y Upper East Side South (237).
-- JFK: 16.21 de distancia, 43.34 minutos y tarifa 47.05 en promedio.
-- Upper East Side South: 2.89, 12.90 minutos y tarifa 9.90.
SELECT
  pickup_location_id,
  COUNT(*) AS viajes,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio,
  ROUND(AVG(duracion_segundos) / 60, 2) AS minutos_promedio,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `proyecto2_taxi.viajes_limpios`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2022-12-01 00:00:00+00'
  AND pickup_location_id IN ('132', '237')
GROUP BY pickup_location_id
ORDER BY viajes DESC;

-- 11. Distribución por código de pago. La función de ventana calcula el
-- porcentaje sobre todos los viajes de enero-noviembre de la tabla limpia.
-- Diccionario TLC: 1=tarjeta, 2=efectivo, 0=Flex Fare.
-- https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf
SELECT
  COALESCE(payment_type, 'SIN_DATO') AS tipo_pago,
  COUNT(*) AS viajes,
  ROUND(SAFE_DIVIDE(COUNT(*) * 100, SUM(COUNT(*)) OVER ()), 2)
    AS porcentaje_viajes,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `proyecto2_taxi.viajes_limpios`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2022-12-01 00:00:00+00'
GROUP BY tipo_pago
ORDER BY viajes DESC;
