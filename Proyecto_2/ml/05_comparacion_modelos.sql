
-- ==========================================================
-- PROYECTO 2 - INTEGRANTE 2
-- ARCHIVO: 05_comparacion_modelos.sql
-- ==========================================================

-- Objetivo:
-- Comparar regresion lineal y Random Forest.
-- Ambos modelos se evaluan con los mismos registros
-- de septiembre de 2022 (VALIDATION).
--
-- Esta consulta NO entrena modelos nuevos.
-- Los registros TEST siguen reservados.

WITH evaluacion_lineal AS (
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
            WHERE conjunto = 'VALIDATION'
        )
    )
),

evaluacion_forest AS (
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
            WHERE conjunto = 'VALIDATION'
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
    SELECT * FROM evaluacion_lineal
    UNION ALL
    SELECT * FROM evaluacion_forest
)
ORDER BY mae ASC;
