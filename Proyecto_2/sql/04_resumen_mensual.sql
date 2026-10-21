-- Proyecto 2 / Integrante 1: segunda tabla derivada para el dashboard.
-- Ejecutar la sentencia CREATE TABLE una sola vez en BigQuery Studio.
-- Proyecto: project-2694859a-c78d-43b5-952; dataset: proyecto2_taxi; región: US.
-- Enero-noviembre de 2022: diciembre tiene solo 57 registros en la fuente.

CREATE TABLE `project-2694859a-c78d-43b5-952.proyecto2_taxi.resumen_mensual_2022`
AS
SELECT
  DATE_TRUNC(fecha_viaje, MONTH) AS mes,
  COUNT(*) AS viajes,
  ROUND(AVG(trip_distance), 2) AS distancia_promedio,
  ROUND(AVG(duracion_segundos) / 60, 2) AS minutos_promedio,
  ROUND(AVG(fare_amount), 2) AS tarifa_promedio
FROM `project-2694859a-c78d-43b5-952.proyecto2_taxi.viajes_limpios`
WHERE pickup_datetime >= TIMESTAMP '2022-01-01 00:00:00+00'
  AND pickup_datetime < TIMESTAMP '2022-12-01 00:00:00+00'
GROUP BY mes;

-- Ejecutar esta consulta DESPUÉS de crear la tabla. Deben aparecer 11 meses
-- de enero a noviembre; la suma observada fue 35,535,514 viajes.
SELECT
  mes,
  viajes,
  distancia_promedio,
  minutos_promedio,
  tarifa_promedio
FROM `project-2694859a-c78d-43b5-952.proyecto2_taxi.resumen_mensual_2022`
ORDER BY mes;

-- Validación observada: 11 filas y 35,535,514 viajes.
SELECT
  COUNT(*) AS meses,
  SUM(viajes) AS viajes_enero_noviembre
FROM `project-2694859a-c78d-43b5-952.proyecto2_taxi.resumen_mensual_2022`;
