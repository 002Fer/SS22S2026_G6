CREATE OR REPLACE TABLE
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.dashboard_tipos_pago` AS
SELECT
  payment_type,
  COUNT(*) AS cantidad_viajes,
  ROUND(
    SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100,
    2
  ) AS porcentaje
FROM
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.viajes_limpios`
GROUP BY
  payment_type
ORDER BY
  cantidad_viajes DESC;


CREATE OR REPLACE TABLE
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.dashboard_tipos_pago` AS
SELECT
  CASE CAST(payment_type AS STRING)
    WHEN '1' THEN 'Tarjeta de crédito'
    WHEN '2' THEN 'Efectivo'
    WHEN '3' THEN 'Sin cargo'
    WHEN '4' THEN 'Disputa'
    WHEN '5' THEN 'Desconocido'
    WHEN '6' THEN 'Viaje anulado'
    ELSE ('Otro')
  END AS tipo_pago,
  COUNT(*) AS cantidad_viajes,
  ROUND(
    SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100,
    2
  ) AS porcentaje
FROM
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.viajes_limpios`
GROUP BY
  tipo_pago
ORDER BY
  cantidad_viajes DESC;