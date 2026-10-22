CREATE OR REPLACE TABLE
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.dashboard_comparacion_modelos` AS
SELECT
  modelo,
  COUNT(*) AS total_predicciones,
  ROUND(AVG(duracion_real), 2) AS duracion_real_promedio,
  ROUND(AVG(duracion_predicha), 2) AS duracion_predicha_promedio,
  ROUND(AVG(error_absoluto), 2) AS error_absoluto_promedio
FROM
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.predicciones_ml`
GROUP BY
  modelo;
