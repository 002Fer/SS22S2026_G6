CREATE OR REPLACE TABLE
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.dashboard_zonas_top10` AS
SELECT
  pickup_location_id,
  COUNT(*) AS cantidad_viajes
FROM
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.viajes_limpios`
WHERE
  pickup_location_id IS NOT NULL
GROUP BY
  pickup_location_id
ORDER BY
  cantidad_viajes DESC
LIMIT 10;