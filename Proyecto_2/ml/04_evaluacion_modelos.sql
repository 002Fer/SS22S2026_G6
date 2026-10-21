
-- 04_evaluacion_modelos.sql


SELECT
    mean_absolute_error AS mae,
    SQRT(mean_squared_error) AS rmse,
    mean_squared_error AS mse,
    r2_score AS r2
FROM ML.EVALUATE(
    MODEL
      `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_lineal`,
    (
        SELECT
            pickup_location_id,
            dropoff_location_id,
            hora_inicio,
            dia_semana,
            mes,
            duracion_minutos
        FROM
            `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
        WHERE
            conjunto = 'VALIDATION'
    )
);



-- EVALUACION DEL MODELO RANDOM FOREST

-- Metricas:
-- MAE, RMSE, MSE y R2.

SELECT
    ROUND(mean_absolute_error, 4) AS mae,
    ROUND(SQRT(mean_squared_error), 4) AS rmse,
    ROUND(mean_squared_error, 4) AS mse,
    ROUND(r2_score, 4) AS r2
FROM ML.EVALUATE(
    MODEL
      `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_random_forest`,
    (
        SELECT
            pickup_location_id,
            dropoff_location_id,
            hora_inicio,
            dia_semana,
            mes,
            duracion_minutos
        FROM
            `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
        WHERE
            conjunto = 'VALIDATION'
    )
);



-- ==========================================================
-- CONSULTA 3: EVALUACION FINAL CON TEST
-- ==========================================================
-- Periodo: octubre y noviembre de 2022.
-- Cantidad esperada: 66,939 registros.
--
-- Los registros TEST no participaron en entrenamiento
-- ni validacion.
--
-- No vuelve a entrenar los modelos.

WITH lineal AS (
  SELECT
    'Regresion Lineal' AS modelo,
    mean_absolute_error AS mae,
    SQRT(mean_squared_error) AS rmse,
    mean_squared_error AS mse,
    r2_score AS r2
  FROM ML.EVALUATE(
    MODEL
      `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_lineal`,
    (
      SELECT
        pickup_location_id,
        dropoff_location_id,
        hora_inicio,
        dia_semana,
        mes,
        duracion_minutos
      FROM
        `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
      WHERE conjunto = 'TEST'
    )
  )
),

forest AS (
  SELECT
    'Random Forest' AS modelo,
    mean_absolute_error AS mae,
    SQRT(mean_squared_error) AS rmse,
    mean_squared_error AS mse,
    r2_score AS r2
  FROM ML.EVALUATE(
    MODEL
      `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_random_forest`,
    (
      SELECT
        pickup_location_id,
        dropoff_location_id,
        hora_inicio,
        dia_semana,
        mes,
        duracion_minutos
      FROM
        `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
      WHERE conjunto = 'TEST'
    )
  )
)

SELECT
  modelo,
  ROUND(mae, 4) AS mae,
  ROUND(rmse, 4) AS rmse,
  ROUND(mse, 4) AS mse,
  ROUND(r2, 4) AS r2
FROM (
  SELECT * FROM lineal
  UNION ALL
  SELECT * FROM forest
)
ORDER BY mae ASC;
