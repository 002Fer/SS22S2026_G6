-- Proyecto 2 / Integrante 1: construcción de la tabla derivada.
-- Ejecutar una sola vez en BigQuery Studio con proyecto predeterminado correcto.
-- Si la tabla ya existe, NO volver a ejecutar CREATE TABLE: la tabla fue creada
-- y validada con 35,535,571 filas. Esta sentencia se conserva para reproducirla
-- en un proyecto/dataset nuevo o tras una decisión explícita de reconstrucción.
-- Dataset de destino: proyecto2_taxi, ubicación US.

-- Reglas: inicio en 2022 (UTC), fin posterior al inicio, distancia positiva,
-- tarifa no nula y no negativa. Las comparaciones también excluyen NULL de
-- pickup_datetime y dropoff_datetime. No se imputan valores inventados.
-- Se conservan las 20 columnas originales y se agregan fecha_viaje y
-- duracion_segundos para análisis y trabajo posterior de ML.
-- Partición diaria: fecha de pickup_datetime.
-- Clustering: pickup_location_id, dropoff_location_id (en ese orden).
CREATE TABLE `proyecto2_taxi.viajes_limpios`
PARTITION BY DATE(pickup_datetime)
CLUSTER BY pickup_location_id, dropoff_location_id
AS
SELECT
  *,
  DATE(pickup_datetime) AS fecha_viaje,
  TIMESTAMP_DIFF(
    dropoff_datetime, pickup_datetime, SECOND
  ) AS duracion_segundos
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2023-01-01 00:00:00+00'
  AND dropoff_datetime > pickup_datetime
  AND trip_distance > 0
  AND fare_amount >= 0;

-- Validación posterior: el valor esperado es 35,535,571.
SELECT COUNT(*) AS filas_limpias
FROM `proyecto2_taxi.viajes_limpios`;

-- Para ML: esta tabla contiene columnas medidas al finalizar el viaje,
-- como fare_amount, total_amount y duracion_segundos. El integrante 2 debe
-- definir el instante de predicción y excluir variables que causen leakage.
