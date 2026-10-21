
-- ==========================================================
-- PROYECTO 2 - INTEGRANTE 2
-- ARCHIVO: 06_predicciones.sql
-- ==========================================================
-- Objetivo:
-- Generar predicciones de los dos modelos sobre
-- viajes reservados en el conjunto TEST.
--
-- Se seleccionan hasta 5000 viajes para el dashboard.
-- No se vuelve a entrenar ningun modelo.

CREATE TABLE
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.predicciones_ml`
AS
WITH datos_prueba AS (
  SELECT
    fecha_viaje,
    pickup_location_id,
    dropoff_location_id,
    hora_inicio,
    dia_semana,
    mes,
    duracion_minutos
  FROM
    `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
  WHERE conjunto = 'TEST'
  ORDER BY FARM_FINGERPRINT(
    TO_JSON_STRING(
      STRUCT(
        fecha_viaje,
        pickup_location_id,
        dropoff_location_id,
        hora_inicio,
        duracion_minutos
      )
    )
  )
  LIMIT 5000
),

pred_lineal AS (
  SELECT
    'Regresion Lineal' AS modelo,
    fecha_viaje,
    duracion_minutos AS duracion_real,
    predicted_duracion_minutos AS duracion_predicha
  FROM ML.PREDICT(
    MODEL
      `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_lineal`,
    (SELECT * FROM datos_prueba)
  )
),

pred_forest AS (
  SELECT
    'Random Forest' AS modelo,
    fecha_viaje,
    duracion_minutos AS duracion_real,
    predicted_duracion_minutos AS duracion_predicha
  FROM ML.PREDICT(
    MODEL
      `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_random_forest`,
    (SELECT * FROM datos_prueba)
  )
)

SELECT
  modelo,
  fecha_viaje,
  ROUND(duracion_real, 2) AS duracion_real,
  ROUND(duracion_predicha, 2) AS duracion_predicha,
  ROUND(
    ABS(duracion_real - duracion_predicha), 2
  ) AS error_absoluto
FROM pred_lineal

UNION ALL

SELECT
  modelo,
  fecha_viaje,
  ROUND(duracion_real, 2),
  ROUND(duracion_predicha, 2),
  ROUND(ABS(duracion_real - duracion_predicha), 2)
FROM pred_forest;



-- Verificar las predicciones generadas.

SELECT
  modelo,
  COUNT(*) AS total_predicciones,
  ROUND(AVG(duracion_real), 2)
    AS promedio_real,
  ROUND(AVG(duracion_predicha), 2)
    AS promedio_predicho,
  ROUND(AVG(error_absoluto), 2)
    AS error_absoluto_promedio
FROM
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.predicciones_ml`
GROUP BY modelo
ORDER BY modelo;



-- ======================================================
-- VALIDACION DE PREDICCIONES POR MES Y MODELO
-- ======================================================
-- No crea tablas ni entrena modelos.
-- Permite analizar la variacion de errores por mes.

SELECT
    modelo,
    DATE_TRUNC(fecha_viaje, MONTH) AS mes,
    COUNT(*) AS cantidad_predicciones,
    ROUND(AVG(duracion_real), 2) AS duracion_real_promedio,
    ROUND(AVG(duracion_predicha), 2) AS duracion_predicha_promedio,
    ROUND(AVG(error_absoluto), 2) AS mae_aproximado
FROM
    `project-2694859a-c78d-43b5-952.proyecto2_taxi.predicciones_ml`
GROUP BY modelo, mes
ORDER BY mes, modelo;
