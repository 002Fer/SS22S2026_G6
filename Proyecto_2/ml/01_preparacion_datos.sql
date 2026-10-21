
-- ==========================================================
-- PROYECTO 2 - SEMINARIO DE SISTEMAS 2
-- INTEGRANTE 2: MACHINE LEARNING CON BIGQUERY ML
-- ARCHIVO: 01_preparacion_datos.sql
-- ==========================================================

-- OBJETIVO:
-- Verificar las columnas utilizadas para predecir
-- la duracion de los viajes de taxi en minutos.

-- No modifica ni elimina informacion de la tabla original.

SELECT
    column_name,
    data_type,
    is_nullable
FROM
    `project-2694859a-c78d-43b5-952.proyecto2_taxi.INFORMATION_SCHEMA.COLUMNS`
WHERE
    table_name = 'viajes_limpios'
    AND column_name IN (
        'pickup_datetime',
        'pickup_location_id',
        'dropoff_location_id',
        'passenger_count',
        'duracion_segundos',
        'fecha_viaje'
    )
ORDER BY
    ordinal_position;



-- ==========================================================
-- VERIFICACION DE PERIODOS PARA MACHINE LEARNING
-- ==========================================================

-- La tabla resumen_mensual_2022 ya fue creada
-- por el integrante 1 y contiene 11 meses.
-- Evitamos consultar nuevamente millones de registros.

SELECT
    *
FROM
    `project-2694859a-c78d-43b5-952.proyecto2_taxi.resumen_mensual_2022`
ORDER BY 1;



-- ==========================================================
-- CONSULTA 3: CREACION DEL DATASET PARA MACHINE LEARNING
-- ==========================================================
-- Objetivo: preparar una muestra reproducible de viajes
-- para entrenar y evaluar modelos de regresion.
--
-- Fuente: proyecto2_taxi.viajes_limpios
-- Destino: proyecto2_taxi.datos_ml
--
-- TRAIN: enero a agosto de 2022
-- VALIDATION: septiembre de 2022
-- TEST: octubre a noviembre de 2022
--
-- Diciembre se excluye por cobertura incompleta.
-- No se modifica la tabla original.

CREATE TABLE
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
AS
WITH preparacion AS (
  SELECT
    fecha_viaje,

    CAST(pickup_location_id AS STRING)
      AS pickup_location_id,

    CAST(dropoff_location_id AS STRING)
      AS dropoff_location_id,

    EXTRACT(HOUR FROM pickup_datetime)
      AS hora_inicio,

    EXTRACT(DAYOFWEEK FROM pickup_datetime)
      AS dia_semana,

    EXTRACT(MONTH FROM pickup_datetime)
      AS mes,

    CAST(duracion_segundos AS FLOAT64) / 60.0
      AS duracion_minutos,

    CASE
      WHEN fecha_viaje < DATE '2022-09-01'
        THEN 'TRAIN'
      WHEN fecha_viaje < DATE '2022-10-01'
        THEN 'VALIDATION'
      ELSE 'TEST'
    END AS conjunto

  FROM
    `project-2694859a-c78d-43b5-952.proyecto2_taxi.viajes_limpios`

  WHERE
    fecha_viaje >= DATE '2022-01-01'
    AND fecha_viaje < DATE '2022-12-01'

    -- Viajes entre 1 minuto y 3 horas.
    AND duracion_segundos BETWEEN 60 AND 10800

    -- Ubicaciones validas.
    AND pickup_location_id IS NOT NULL
    AND dropoff_location_id IS NOT NULL
),

muestra AS (
  SELECT *
  FROM preparacion

  -- Muestra determinista aproximada del 1 %.
  WHERE MOD(
    MOD(
      FARM_FINGERPRINT(
        TO_JSON_STRING(
          STRUCT(
            fecha_viaje,
            pickup_location_id,
            dropoff_location_id,
            hora_inicio,
            duracion_minutos
          )
        )
      ),
      10000
    ) + 10000,
    10000
  ) < 100
)

SELECT *
FROM muestra;




-- ==========================================================
-- CONSULTA 4: VALIDACION DEL DATASET ML
-- ==========================================================

SELECT
  conjunto,
  COUNT(*) AS total_registros,
  ROUND(AVG(duracion_minutos), 2)
    AS duracion_promedio_minutos,
  MIN(fecha_viaje) AS fecha_minima,
  MAX(fecha_viaje) AS fecha_maxima
FROM
  `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
GROUP BY
  conjunto
ORDER BY
  CASE conjunto
    WHEN 'TRAIN' THEN 1
    WHEN 'VALIDATION' THEN 2
    WHEN 'TEST' THEN 3
  END;
