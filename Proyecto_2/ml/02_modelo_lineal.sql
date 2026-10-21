


-- MODELO 1: REGRESION LINEAL

-- Predecir la duracion de un viaje de taxi en minutos.


CREATE MODEL
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_lineal`

OPTIONS (
    MODEL_TYPE = 'LINEAR_REG',
    INPUT_LABEL_COLS = ['duracion_minutos'],
    DATA_SPLIT_METHOD = 'NO_SPLIT',
    MAX_ITERATIONS = 20,
    L2_REG = 1.0
)

AS
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
    conjunto = 'TRAIN';
