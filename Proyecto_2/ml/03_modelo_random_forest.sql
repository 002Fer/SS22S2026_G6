
-- PROYECTO 2 - INTEGRANTE 2
-- Segundo modelo: Random Forest Regressor
-- Objetivo: predecir duracion_minutos.
-- Muestra reducida para controlar recursos.
-- Solo utiliza registros TRAIN.

CREATE MODEL
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.modelo_random_forest`

OPTIONS (
  MODEL_TYPE = 'RANDOM_FOREST_REGRESSOR',
  INPUT_LABEL_COLS = ['duracion_minutos'],
  DATA_SPLIT_METHOD = 'NO_SPLIT',
  NUM_PARALLEL_TREE = 10,
  MAX_TREE_DEPTH = 4,
  TREE_METHOD = 'HIST'
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
  conjunto = 'TRAIN'
  AND MOD(
    MOD(
      FARM_FINGERPRINT(
        TO_JSON_STRING(STRUCT(
          fecha_viaje,
          pickup_location_id,
          dropoff_location_id,
          hora_inicio,
          duracion_minutos
        ))
      ),
      10000
    ) + 10000,
    10000
  ) < 800;
