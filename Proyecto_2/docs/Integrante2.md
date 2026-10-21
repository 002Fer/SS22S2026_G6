# Proyecto 2 — Procesamiento y Análisis Exploratorio de Datos Masivos en BigQuery

## Integrante 2 — Desarrollo de modelos predictivos con BigQuery ML

**Curso:** Seminario de Sistemas 2  
**Universidad:** Universidad de San Carlos de Guatemala — Facultad de Ingeniería  
**Integrante:** Fernando Misael Morales Ortiz - 202001950  
**Grupo:** 9 
**Estado:** Dos modelos entrenados y evaluados; predicciones preparadas para visualización.


## 1. Resumen 

Se implementó un flujo de aprendizaje automático en **Google BigQuery ML** para estimar la **duración de viajes de taxis de Nueva York, expresada en minutos**, utilizando la tabla limpia creada previamente por el integrante 1. Se preparó una muestra de **353,941 registros** de enero a noviembre de 2022 y se aplicó una separación temporal para evitar utilizar observaciones futuras en el entrenamiento.

Se entrenaron dos modelos de regresión: **regresión lineal** (`LINEAR_REG`) y **bosque aleatorio** (`RANDOM_FOREST_REGRESSOR`). El modelo de regresión lineal utilizó **255,838 viajes** de entrenamiento; el bosque aleatorio utilizó una submuestra reducida de aproximadamente **20 mil viajes**, para controlar la carga computacional y el consumo de recursos.

Los dos modelos se evaluaron sobre los mismos datos de validación (septiembre) y prueba final (octubre–noviembre). En la evaluación final, la regresión lineal obtuvo **MAE = 7.0924 minutos**, **RMSE = 10.0382 minutos** y **R² = 0.4180**, frente a **MAE = 7.4615 minutos**, **RMSE = 10.6342 minutos** y **R² = 0.3468** del bosque aleatorio. En las configuraciones utilizadas, la regresión lineal obtuvo el menor error.

Finalmente, se creó la tabla `predicciones_ml`, con **10,000 filas de predicciones**: 5,000 de cada modelo sobre una misma muestra de 5,000 viajes de prueba. Estos datos quedan disponibles para integrarlos en un dashboard de Looker Studio.

## 2. Objetivo y problema predictivo

**Objetivo general:** desarrollar, evaluar y comparar dos modelos de regresión con BigQuery ML para predecir la duración de un viaje de taxi utilizando características conocidas o asumidas como conocidas al comenzar el recorrido.

 ¿cuántos minutos durará un viaje a partir de su ubicación de origen, destino previsto y características temporales?

**Variable objetivo:** `duracion_minutos`, obtenida dividiendo `duracion_segundos` entre 60.

**Instante de predicción supuesto:** antes de comenzar el viaje. Esto implica que el destino debe ser conocido previamente. Si no se dispone de esa información al inicio, `dropoff_location_id` no debería usarse como variable predictora en una aplicación real.

### 2.1 Variables utilizadas

| Campo | Tipo / tratamiento | Función | Justificación |
|---|---|---|---|
| `pickup_location_id` | `STRING`, categórica | Entrada | Las duraciones pueden variar según el origen. |
| `dropoff_location_id` | `STRING`, categórica | Entrada | El destino previsto permite modelar recorridos diferentes. |
| `hora_inicio` | Entero, derivado de `pickup_datetime` | Entrada | Considera diferencias entre horas de baja y alta demanda. |
| `dia_semana` | Entero, derivado de `pickup_datetime` | Entrada | Permite captar diferencias entre días. |
| `mes` | Entero, derivado de `pickup_datetime` | Entrada | Incorpora efectos temporales y de estacionalidad. |
| `duracion_minutos` | `FLOAT64`, derivada | **Objetivo** | Duración real del viaje en minutos. |
| `fecha_viaje` | `DATE` | Control de split | Se usa para dividir periodos, no como predictor en los modelos ejecutados. |
| `conjunto` | `STRING` | Control de split | Identifica TRAIN, VALIDATION o TEST; no entra al modelo. |

No se utilizaron como variables de entrada `dropoff_datetime`, `fare_amount`, `total_amount`, `tip_amount` ni `duracion_segundos`. La última es la fuente de la etiqueta y no debe emplearse simultáneamente como predictor. La hora de finalización y los importes finales pueden incorporar información no disponible antes del viaje, causando **fuga de información (data leakage)**.



## 3. Entorno y origen de los datos

| Elemento | Identificación |
|---|---|
| Plataforma | Google Cloud / BigQuery / BigQuery ML |
| ID del proyecto | `project-2694859a-c78d-43b5-952` |
| Dataset de trabajo | `proyecto2_taxi` |
| Región del dataset | Multirregión `US` |
| Fuente pública original | `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` |
| Fuente depurada (integrante 1) | `proyecto2_taxi.viajes_limpios` |
| Resumen exploratorio (integrante 1) | `proyecto2_taxi.resumen_mensual_2022` |
| Tabla de preparación del integrante 2 | `proyecto2_taxi.datos_ml` |
| Modelos | `proyecto2_taxi.modelo_lineal` y `proyecto2_taxi.modelo_random_forest` |
| Tabla de predicciones | `proyecto2_taxi.predicciones_ml` |

El integrante 1 reportó **36,256,539 registros** en la fuente original y **35,535,571 registros** en `viajes_limpios`, luego de aplicar criterios de calidad. La tabla de viajes limpios está particionada por fecha de inicio y clusterizada por identificadores de origen y destino. No se reconstruyó ni modificó durante el desarrollo de Machine Learning.

**Limitación temporal de la fuente:** diciembre de 2022 presenta únicamente 57 viajes con inicio en ese mes; por lo tanto, se excluyó del flujo de modelado para evitar tratarlo como un periodo mensual comparable.

## 4. Preparación y exploración de variables

**Archivo:** `ml/01_preparacion_datos.sql`.

### 4.1 Comprobación del esquema

Se consultó `INFORMATION_SCHEMA.COLUMNS` y se verificó la existencia de seis campos relevantes:

| Campo | Tipo confirmado |
|---|---|
| `pickup_datetime` | `TIMESTAMP` |
| `passenger_count` | `INT64` |
| `pickup_location_id` | `STRING` |
| `dropoff_location_id` | `STRING` |
| `fecha_viaje` | `DATE` |
| `duracion_segundos` | `INT64` |

**Evidencia 01 — Variables disponibles**  
![Esquema de columnas para Machine Learning](../Integrante2_evidencias/01_columnas_ml.png)

### 4.2 Distribución mensual

Se revisó `resumen_mensual_2022`, tabla de 11 filas preparada por el integrante 1, para comprobar la cobertura de enero a noviembre sin repetir una exploración costosa de la tabla fuente. El resumen mostró variaciones de volumen y duración media por mes; por ello se eligió una división temporal en lugar de una separación completamente aleatoria.

**Evidencia 02 — Resumen mensual**  
![Distribución mensual de viajes](../Integrante2_evidencias/02_distribucion_mensual.png)

### 4.3 Construcción de `datos_ml`

Se creó una tabla independiente a partir de `viajes_limpios` con las siguientes operaciones:

1. Restricción a fechas desde el 1 de enero hasta antes del 1 de diciembre de 2022.
2. Restricción de duración a un intervalo de **60 a 10,800 segundos** (1 minuto a 3 horas) para evitar duraciones extremas dentro del experimento. Es un criterio analítico adicional y no modifica la tabla limpia del integrante 1.
3. Exclusión de registros sin ubicación de origen o destino.
4. Transformación de duración a minutos y extracción de hora, día de la semana y mes.
5. Creación del campo `conjunto` mediante fechas fijas.
6. Muestreo determinista aproximado del **1 %** mediante `FARM_FINGERPRINT`, para reducir el volumen de entrenamiento y costo.

Este procedimiento produjo **353,941 registros**. El hash utilizado se deriva de una combinación de características del viaje; por tanto, hace reproducible la selección para los mismos datos, pero **no constituye un identificador único por viaje** y puede seleccionar juntos registros con la misma combinación. Esto se debe considerar si posteriormente se realizan análisis de duplicados.

**Evidencia 03 — Creación de tabla ML**  
![Creación de datos_ml](../Integrante2_evidencias/03_creacion_datos_ml.png)

### 4.4 División temporal y prevención de fuga de información

| Conjunto | Fechas | Registros | Promedio de duración |
|---|---|---:|---:|
| TRAIN | Enero–agosto de 2022 | 255,838 | 15.37 min |
| VALIDATION | Septiembre de 2022 | 31,164 | 17.46 min |
| TEST | Octubre–noviembre de 2022 | 66,939 | 16.85 min |
| **TOTAL** | Enero–noviembre | **353,941** | — |

Se utilizaron exclusivamente registros TRAIN en `CREATE MODEL`. Para evitar que BigQuery repartiera los datos aleatoriamente, ambos entrenamientos se configuraron con `DATA_SPLIT_METHOD = 'NO_SPLIT'`. Posteriormente `ML.EVALUATE` recibió explícitamente VALIDATION o TEST. Se reservó TEST para la evaluación final, después de examinar los resultados de VALIDATION.

Una separación temporal ayuda a evaluar la generalización hacia periodos posteriores, aunque por sí misma no garantiza ausencia absoluta de leakage: también deben controlarse las variables disponibles en el instante de predicción y el modo en que se generó cada característica.

**Evidencia 04 — Validación del split**  
![Recuento temporal TRAIN VALIDATION TEST](../Integrante2_evidencias/04_validacion_split.png)

## 5. Modelo 1: regresión lineal

**Archivo:** `ml/02_modelo_lineal.sql`.  
**Modelo en BigQuery:** `proyecto2_taxi.modelo_lineal`.

Se eligió la regresión lineal como modelo de referencia por su sencillez, porque ofrece una comparación inicial frente a un algoritmo basado en árboles y porque es apropiada para una variable objetivo numérica continua.

**Parámetros empleados:**

| Opción | Valor | Motivo |
|---|---|---|
| `MODEL_TYPE` | `LINEAR_REG` | Regresión con objetivo continuo. |
| `INPUT_LABEL_COLS` | `['duracion_minutos']` | Identifica la etiqueta. |
| `DATA_SPLIT_METHOD` | `NO_SPLIT` | Respeta la separación externa por fecha. |
| `MAX_ITERATIONS` | `20` | Limita las iteraciones del algoritmo. |
| `L2_REG` | `1.0` | Regularización para moderar la magnitud de los coeficientes. |

Se entrenó con **255,838 registros TRAIN**. Las variables incluidas fueron los dos ID de ubicación como categorías y las tres características temporales. La consola confirmó la creación exitosa del modelo.

**Evidencia 05 — Entrenamiento de regresión lineal**  
![Creación del modelo lineal](../Integrante2_evidencias/05_modelo_lineal_entrenamiento.png)

**Evidencia 06 — Detalles del modelo lineal**  
![Detalles y verificación del modelo lineal](../Integrante2_evidencias/06_modelo_lineal_verificacion.png)

> Nota sobre la verificación: una consulta inicial a `proyecto2_taxi.INFORMATION_SCHEMA.MODELS` produjo error. El modelo sí existía; su creación se verificó en la interfaz de BigQuery y mediante el éxito de `ML.EVALUATE`. La consulta de metadatos incorrecta no es necesaria para reproducir el entrenamiento.

## 6. Segundo modelo: Random Forest Regressor

**Archivo:** `ml/03_modelo_random_forest.sql`.  
**Modelo en BigQuery:** `proyecto2_taxi.modelo_random_forest`.

Se eligió Random Forest como alternativa no lineal para modelar posibles interacciones entre ubicaciones y tiempo. Se utilizó la misma variable objetivo y las mismas entradas del modelo lineal.

**Parámetros empleados:**

| Opción | Valor | Motivo |
|---|---|---|
| `MODEL_TYPE` | `RANDOM_FOREST_REGRESSOR` | Algoritmo de regresión basado en árboles. |
| `INPUT_LABEL_COLS` | `['duracion_minutos']` | Misma etiqueta que la regresión lineal. |
| `DATA_SPLIT_METHOD` | `NO_SPLIT` | Respeta TRAIN definido externamente. |
| `NUM_PARALLEL_TREE` | `10` | Limita la cantidad de árboles. |
| `MAX_TREE_DEPTH` | `4` | Reduce la complejidad de cada árbol. |
| `TREE_METHOD` | `HIST` | Método de construcción basado en histogramas. |

Se aplicó una muestra determinista adicional de aproximadamente **8 % de TRAIN** (alrededor de 20,000 registros), con el objetivo de contener el uso de recursos. El tamaño exacto de esa muestra no se validó mediante un conteo independiente en las evidencias disponibles; por eso se documenta como aproximado.

### 6.1 Cambio respecto a la propuesta original

Inicialmente se intentó entrenar un `BOOSTED_TREE_REGRESSOR` con 20 iteraciones, profundidad máxima de 6 y un conjunto mucho mayor. El trabajo registró consumo de recursos y no mostraba iteraciones completadas durante el monitoreo. Se decidió utilizar Random Forest con una configuración y muestra más pequeñas. **No se dispone en estas evidencias de una confirmación final del estado de cancelación del trabajo original; verificar el historial de trabajos si se requiere documentar ese detalle.**

Esta modificación respondió a una restricción práctica de costo y capacidad de entrenamiento, no a un hallazgo de que Random Forest sea intrínsecamente más eficiente.

**Evidencia 08 — Entrenamiento de Random Forest**  
![Creación del modelo Random Forest](../Integrante2_evidencias/08_modelo_random_forest_entrenamiento.png)

**Evidencia opcional — Intento de Boosted Trees**  
![Monitoreo del intento inicial Boosted Trees](../Integrante2_evidencias/08_boosted_intento_inicial.png)

## 7. Evaluación en VALIDATION (septiembre de 2022)

**Archivo:** `ml/04_evaluacion_modelos.sql`.

Para comparar los modelos, se ejecutó `ML.EVALUATE` sobre los mismos **31,164 registros de septiembre**. Las métricas fueron:

- **MAE** (mean absolute error): promedio del valor absoluto del error, en minutos.
- **RMSE**: raíz del error cuadrático medio, en minutos; penaliza más los errores elevados.
- **MSE**: error cuadrático medio, en minutos al cuadrado.
- **R²**: proporción de variabilidad explicada respecto a una referencia basada en el promedio; valores más altos suelen indicar mejor ajuste.

| Métrica | Regresión lineal | Random Forest | Mejor resultado |
|---|---:|---:|---|
| MAE | **7.4896** | 7.8870 | Regresión lineal |
| RMSE | **10.9595** | 11.5528 | Regresión lineal |
| MSE | **120.1114** | 133.4678 | Regresión lineal |
| R² | **0.4034** | 0.3371 | Regresión lineal |

El modelo lineal obtuvo mejor desempeño bajo las configuraciones probadas. La diferencia aproximada de MAE es **0.3974 minutos** a favor de la regresión lineal.

**Evidencia 07 — Evaluación del modelo lineal**  
![Evaluación de regresión lineal en VALIDATION](../Integrante2_evidencias/07_evaluacion_lineal_validacion.png)

**Evidencia 09 — Evaluación de Random Forest**  
![Evaluación de Random Forest en VALIDATION](../Integrante2_evidencias/09_evaluacion_random_forest_validacion.png)

## 8. Comparación conjunta de modelos

**Archivo:** `ml/05_comparacion_modelos.sql`.

Se integraron dos llamadas a `ML.EVALUATE` con `UNION ALL` para obtener una sola tabla comparativa reproducible, ordenada por MAE. Se utilizó el mismo conjunto VALIDATION y los mismos campos de entrada para ambos modelos.

**Evidencia 10 — Comparación conjunta de VALIDATION**  
![Comparación de modelos en validación](../Integrante2_evidencias/10_comparacion_modelos_validacion.png)

### 8.1 Justificación de la selección

La regresión lineal se selecciona como **mejor configuración observada** porque obtuvo MAE y RMSE menores y R² mayor tanto en la validación como posteriormente en TEST. No obstante, **la comparación no es un experimento controlado sobre el algoritmo solamente**, porque Random Forest se entrenó con muchos menos registros y una configuración deliberadamente limitada. La diferencia no puede atribuirse exclusivamente a la elección de regresión lineal frente a bosque aleatorio.

### 8.2 Límite del ajuste de hiperparámetros

Se definieron hiperparámetros explícitos para ambos modelos, pero **no se ejecutó una búsqueda sistemática ni se compararon varias configuraciones de un mismo algoritmo en condiciones idénticas**. Por ello no se afirma haber encontrado los hiperparámetros óptimos. El intento inicial de Boosted Trees se considera una decisión de ingeniería orientada al costo, no una prueba de optimización concluyente. Este punto queda como posible mejora conforme al criterio de hiperparámetros de la rúbrica.

## 9. Evaluación final en TEST (octubre y noviembre de 2022)

Una vez obtenida la comparación de VALIDATION, se ejecutó `ML.EVALUATE` sobre los **66,939 registros TEST**. Los modelos no fueron reentrenados para esta evaluación.

| Métrica | Regresión lineal | Random Forest | Mejor resultado |
|---|---:|---:|---|
| MAE | **7.0924** | 7.4615 | Regresión lineal |
| RMSE | **10.0382** | 10.6342 | Regresión lineal |
| MSE | **100.7650** | 113.0854 | Regresión lineal |
| R² | **0.4180** | 0.3468 | Regresión lineal |

En TEST, la regresión lineal logró un MAE de **7.09 minutos**, esto es, un error absoluto promedio cercano a siete minutos por viaje. El R² de **0.4180** indica que el modelo explicó alrededor del **41.8 %** de la variabilidad de duración observada en esta partición de prueba.

**Evidencia 11 — Evaluación final TEST**  
![Resultados finales en TEST](../Integrante2_evidencias/11_evaluacion_final_test.png)

**Advertencia metodológica:** después de observar TEST, no se deben modificar hiperparámetros y volver a reportar sobre ese mismo conjunto como si fuera una evaluación completamente nueva e independiente. Si se hiciera un ajuste posterior, se necesitaría otra partición final no consultada para una nueva evaluación imparcial.

## 10. Predicciones individuales y preparación para el dashboard

**Archivo:** `ml/06_predicciones.sql`.  
**Tabla:** `proyecto2_taxi.predicciones_ml`.

Se ejecutó `ML.PREDICT` para cada modelo sobre una **misma muestra de hasta 5,000 viajes** tomada de TEST y se combinaron ambos resultados con `UNION ALL`. La ejecución devolvió **5,000 filas por modelo, 10,000 en total**.

La tabla final contiene:

| Campo | Significado |
|---|---|
| `modelo` | Identifica regresión lineal o Random Forest. |
| `fecha_viaje` | Fecha de inicio del viaje. |
| `duracion_real` | Duración observada del viaje, en minutos. |
| `duracion_predicha` | Duración estimada por el modelo, en minutos. |
| `error_absoluto` | Diferencia absoluta entre duración real y predicha, en minutos. |

### 10.1 Validación del resumen de predicciones

| Indicador | Regresión lineal | Random Forest |
|---|---:|---:|
| Predicciones | 5,000 | 5,000 |
| Promedio de duración real | 16.92 min | 16.92 min |
| Promedio de duración estimada | 16.82 min | 15.73 min |
| Promedio de error absoluto | **7.02 min** | 7.33 min |

La tabla para el dashboard fue construida a partir de una submuestra de TEST; **sus errores promedios no sustituyen las métricas de la evaluación final sobre los 66,939 casos**. Los valores de predicción y error fueron redondeados a dos decimales para la visualización.

**Evidencia 12 — Creación de tabla de predicciones**  
![Creación de predicciones_ml](../Integrante2_evidencias/12_creacion_predicciones_ml.png)

**Evidencia 13 — Resumen de predicciones**  
![Comprobación de cinco mil predicciones por modelo](../Integrante2_evidencias/13_resultados_predicciones_ml.png)

### 10.2 Resumen mensual de predicciones

La consulta final agrupó los resultados por mes y modelo:

| Mes | Modelo | Predicciones | Duración real media | Duración predicha media | MAE aproximado |
|---|---|---:|---:|---:|---:|
| Octubre 2022 | Random Forest | 2,606 | 17.05 | 15.52 | 7.51 |
| Octubre 2022 | Regresión lineal | 2,606 | 17.05 | 16.60 | **7.06** |
| Noviembre 2022 | Random Forest | 2,394 | 16.77 | 15.95 | 7.13 |
| Noviembre 2022 | Regresión lineal | 2,394 | 16.77 | 17.06 | **6.98** |

En ambos meses de esta muestra, la regresión lineal presenta un menor error absoluto promedio. El valor denominado **MAE aproximado** fue calculado sobre errores absolutos previamente redondeados, por lo que no reemplaza la métrica original de `ML.EVALUATE`.

**Evidencia 14 — Predicciones por mes**  
![Predicciones mensuales por modelo](../Integrante2_evidencias/14_predicciones_por_mes.png)

## 11. Guía de ejecución y reproducción

### 11.1 Requisitos previos

1. Contar con acceso a Google Cloud y BigQuery, permisos para ejecutar consultas y crear modelos y tablas en el proyecto del grupo.
2. Verificar que el proyecto de ejecución sea `project-2694859a-c78d-43b5-952` o sustituirlo de manera consistente si se usa otro proyecto.
3. Configurar la ubicación de los trabajos en **`US`**, donde está el dataset.
4. Confirmar que existen las tablas del integrante 1: `proyecto2_taxi.viajes_limpios` y `proyecto2_taxi.resumen_mensual_2022`.
5. Comprobar permisos de facturación/cuotas y revisar las estimaciones de bytes y tarifas de BigQuery ML antes de entrenar.
6. Mantener los nombres y tipos de las columnas especificados anteriormente.

### 11.2 Orden recomendado de scripts

| Orden | Archivo | Acción | ¿Crea recursos? |
|---|---|---|---|
| 1 | `ml/01_preparacion_datos.sql` | Revisar esquema y meses; crear `datos_ml`; validar splits | **Sí**, `datos_ml` |
| 2 | `ml/02_modelo_lineal.sql` | Entrenar `modelo_lineal` usando TRAIN | **Sí**, un modelo |
| 3 | `ml/03_modelo_random_forest.sql` | Entrenar `modelo_random_forest` usando subconjunto TRAIN | **Sí**, un modelo |
| 4 | `ml/04_evaluacion_modelos.sql` | Evaluar ambos con VALIDATION y TEST | No |
| 5 | `ml/05_comparacion_modelos.sql` | Tabla comparativa sobre VALIDATION | No |
| 6 | `ml/06_predicciones.sql` | Crear y verificar `predicciones_ml`; resumen por mes | **Sí**, `predicciones_ml` |

**Importante:** los archivos agrupan varias sentencias. No es necesario ejecutarlos de una sola vez: en BigQuery Studio conviene seleccionar y ejecutar cada bloque en orden, sobre todo los `CREATE TABLE` y `CREATE MODEL`.

### 11.3 No ejecutar nuevamente las sentencias CREATE si los recursos existen

Los scripts originales utilizaron `CREATE TABLE` y `CREATE MODEL` (sin `OR REPLACE`). Si los recursos existen, repetirlos puede producir errores de “Already Exists”; recrearlos además ocasionaría procesamiento y entrenamiento innecesarios. Los scripts se conservan como evidencia reproducible, **no como instrucciones para ejecutarlos indiscriminadamente en un proyecto ya preparado**.

Para repetir el experimento en otro proyecto, crear primero el dataset de destino en `US`, ajustar el ID del proyecto en todos los scripts, revisar cuotas y ejecutar las sentencias en secuencia. Solo reconstruir objetos existentes tras decidir explícitamente la sustitución y conservar antes las evidencias.

### 11.4 Consultas de comprobación no destructivas

**Comprobar tamaño y separación de la tabla ML:**

```sql
SELECT
  conjunto,
  COUNT(*) AS total_registros,
  MIN(fecha_viaje) AS fecha_minima,
  MAX(fecha_viaje) AS fecha_maxima
FROM `project-2694859a-c78d-43b5-952.proyecto2_taxi.datos_ml`
GROUP BY conjunto
ORDER BY conjunto;
```

**Comprobar la tabla de predicciones:**

```sql
SELECT
  modelo,
  COUNT(*) AS total_predicciones,
  ROUND(AVG(duracion_real), 2) AS promedio_real,
  ROUND(AVG(duracion_predicha), 2) AS promedio_predicho,
  ROUND(AVG(error_absoluto), 2) AS error_absoluto_promedio
FROM `project-2694859a-c78d-43b5-952.proyecto2_taxi.predicciones_ml`
GROUP BY modelo
ORDER BY modelo;
```

**Comprobar recursos de modelos:** en BigQuery Studio expandir el proyecto y el dataset `proyecto2_taxi`; abrir `modelo_lineal` y `modelo_random_forest` en la lista de recursos y revisar sus detalles. También se puede comprobar su funcionamiento con las consultas `ML.EVALUATE` guardadas en los scripts.

**Comprobar predicciones por mes:** ejecutar la última consulta de `06_predicciones.sql` y verificar las cuatro combinaciones de octubre/noviembre por modelo.

### 11.5 Evidencias y control de costos

- Registrar capturas de SQL ejecutado y de sus resultados, sin publicar información confidencial de facturación.
- Revisar los bytes estimados con BigQuery antes de ejecutar consultas grandes.
- Usar particiones y muestras para evitar lecturas o entrenamientos repetitivos sobre toda la fuente.
- Consultar los costos específicos de entrenamiento de los modelos basados en árboles.
- Un presupuesto con alertas informa del gasto, pero no constituye un límite automático de facturación.



## 14. Conclusiones

1. Se preparó un conjunto de **353,941 registros** con variables temporales y geográficas y una división cronológica explícita en entrenamiento, validación y prueba.
2. Se implementaron dos modelos distintos de regresión en BigQuery ML, ambos sobre la misma variable objetivo `duracion_minutos`.
3. Bajo las configuraciones empleadas, la regresión lineal obtuvo mejores resultados que Random Forest tanto en VALIDATION como en TEST.
4. La evaluación final de la regresión lineal produjo **MAE = 7.0924 minutos**, **RMSE = 10.0382 minutos** y **R² = 0.4180**. Estos resultados constituyen una línea base, no una garantía de precisión para todos los viajes futuros.
5. Se generó una tabla de **10,000 predicciones** listas para visualización, conservando una evaluación final separada de la muestra del dashboard.
6. El proyecto evidencia la utilidad de BigQuery ML para entrenar, evaluar y aplicar modelos con SQL, además de la importancia de documentar límites metodológicos, consumo de recursos y prevención de data leakage.

## 15. Estructura de archivos

```text
Proyecto_2/
├── sql/                                   # Integrante 1
│   ├── 01_exploracion.sql
│   ├── 02_limpieza.sql
│   ├── 03_optimizacion.sql
│   └── 04_resumen_mensual.sql
├── ml/                                    # Integrante 2
│   ├── 01_preparacion_datos.sql
│   ├── 02_modelo_lineal.sql
│   ├── 03_modelo_random_forest.sql
│   ├── 04_evaluacion_modelos.sql
│   ├── 05_comparacion_modelos.sql
│   └── 06_predicciones.sql
├── Integrante1_evidencias/
├── Integrante2_evidencias/
│   ├── 01_columnas_ml.png
│   ├── 02_distribucion_mensual.png
│   ├── 03_creacion_datos_ml.png
│   ├── 04_validacion_split.png
│   ├── 05_modelo_lineal_entrenamiento.png
│   ├── 06_modelo_lineal_verificacion.png
│   ├── 07_evaluacion_lineal_validacion.png
│   ├── 08_modelo_random_forest_entrenamiento.png
│   ├── 09_evaluacion_random_forest_validacion.png
│   ├── 10_comparacion_modelos_validacion.png
│   ├── 11_evaluacion_final_test.png
│   ├── 12_creacion_predicciones_ml.png
│   ├── 13_resultados_predicciones_ml.png
│   └── 14_predicciones_por_mes.png
└── README.md                              # README general del grupo
```


