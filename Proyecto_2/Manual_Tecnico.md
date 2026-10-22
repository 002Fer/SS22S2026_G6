# Manual técnico general — Proyecto 2

## NYC Yellow Taxi Trips 2022: ingeniería de datos, Machine Learning y visualización

**Proyecto:** Proyecto 2 — análisis de viajes de taxis amarillos de Nueva York, año 2022  
**Plataforma de datos:** Google Cloud BigQuery  
**Proyecto de Google Cloud:** `project-2694859a-c78d-43b5-952`  
**Dataset:** `proyecto2_taxi`  
**Repositorio:** [https://github.com/002Fer/SS22S2026_G6](https://github.com/002Fer/SS22S2026_G6)  
**Dashboard:** [Agregar enlace compartido de Looker Studio](https://datastudio.google.com/u/4/reporting/75bae33d-f682-4a09-8436-ba599f8e2afb/page/FGqBG/edit)

> Este informe integra las tres etapas del trabajo: preparación y optimización de datos, construcción y evaluación de modelos predictivos, y visualización de resultados. Los archivos `integrante1.md` e `Integrante2.md` conservan el detalle específico de sus respectivas implementaciones. Las capturas se enlazan desde las carpetas de evidencia para que puedan consultarse directamente desde el repositorio.

## 1. Resumen ejecutivo

El proyecto desarrolla un flujo analítico sobre los registros de viajes de taxis amarillos de Nueva York correspondientes a 2022. Primero se exploró y limpió la fuente pública en BigQuery, después se prepararon datos y se entrenaron dos modelos de regresión con BigQuery ML para estimar la duración de los viajes, y finalmente se organizaron indicadores para su consulta y visualización en Looker Studio.

El proceso de ingeniería de datos materializó una tabla de viajes válidos y optimizó su organización mediante particionamiento por fecha y clustering por ubicación de origen y destino. La etapa de Machine Learning comparó regresión lineal y Random Forest, con separación temporal de entrenamiento, validación y prueba. La etapa de visualización reúne indicadores de evolución mensual, distribución por tipo de pago, zonas de recogida con mayor volumen y comparación de duración real frente a duración predicha.

## 2. Objetivos

### 2.1 Objetivo general

Construir un flujo reproducible de análisis de datos que transforme registros de viajes de taxi en información útil mediante limpieza, optimización de consultas, modelos predictivos y visualizaciones.

### 2.2 Objetivos específicos

- Explorar la fuente pública y diagnosticar problemas de calidad de datos.
- Aplicar reglas de limpieza y conservar una tabla reutilizable por el resto del equipo.
- Evaluar el efecto de la organización física de BigQuery sobre el volumen de datos procesados.
- Preparar una muestra analítica y entrenar modelos de regresión para estimar la duración de los viajes.
- Comparar los modelos con métricas de error y generar predicciones para su análisis visual.
- Crear tablas agregadas y un dashboard que facilite la interpretación de tendencias y resultados.
- Mantener scripts, documentación técnica y evidencias funcionales dentro del repositorio.

## 3. Alcance y distribución del trabajo

| Integrante | Responsabilidad | Productos principales |
|---|---|---|
| Integrante 1 | Ingeniería de datos y SQL | Exploración, diagnóstico de calidad, limpieza, particionamiento, clustering, comparación de consultas y resumen mensual. |
| Integrante 2 | Machine Learning | Preparación de datos para ML, división temporal, entrenamiento de regresión lineal y Random Forest, evaluación y predicciones. |
| Integrante 3 | Visualización y documentación final | Tablas agregadas para el dashboard, visualizaciones de Looker Studio, integración de resultados y evidencias del dashboard. |

## 4. Tecnologías y recursos

- **Google Cloud / BigQuery:** almacenamiento, ejecución de consultas SQL y procesamiento de los datos.
- **BigQuery ML:** entrenamiento, evaluación y predicción mediante modelos de regresión.
- **Looker Studio:** visualización de los indicadores y resultados del proyecto.
- **SQL:** exploración, transformación, agregación, evaluación y generación de tablas para consumo analítico.
- **GitHub:** organización y control de versiones del código, scripts, documentación y evidencia.

### 4.1 Fuente de datos

La fuente utilizada es la tabla pública `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`. El dataset de trabajo es `project-2694859a-c78d-43b5-952.proyecto2_taxi`, ubicado en la multirregión `US`.

## 5. Arquitectura y flujo general

```text
Fuente pública NYC Yellow Taxi Trips 2022
                  |
                  v
      Exploración y diagnóstico SQL
                  |
                  v
         Limpieza y validación
                  |
                  v
       proyecto2_taxi.viajes_limpios
                  |
          +-------+--------+
          |                |
          v                v
 resumen_mensual_2022   Preparación de datos ML
          |                |
          |                v
          |        TRAIN / VALIDATION / TEST
          |                |
          |        +-------+--------+
          |        |                |
          |        v                v
          |   Regresión lineal   Random Forest
          |        |                |
          |        +-------+--------+
          |                v
          |       Evaluación y predicciones
          |                |
          +-------+--------+
                  v
       Tablas agregadas para dashboard
                  |
                  v
       Looker Studio: visualizaciones
```

El diagrama representa el flujo lógico. Las tablas de entrada y los scripts concretos se describen en las secciones siguientes.

## 6. Integrante 1 — Ingeniería de datos y SQL

### 6.1 Exploración y calidad

La fuente original contiene **36,256,539 registros**. El diagnóstico identificó valores con duración no positiva, distancias nulas o no positivas, tarifas nulas o negativas y fechas de inicio fuera de 2022. Estas categorías pueden superponerse, por lo que sus conteos no deben sumarse como si representaran filas distintas.

### 6.2 Reglas de limpieza

Se creó `proyecto2_taxi.viajes_limpios`, conservando viajes iniciados durante 2022 y aplicando estas condiciones:

- `dropoff_datetime > pickup_datetime`.
- `trip_distance > 0`.
- `fare_amount >= 0`.
- Fecha de inicio dentro del intervalo de 2022.
- Creación de `fecha_viaje` y `duracion_segundos` como campos derivados.

La tabla limpia quedó con **35,535,571 registros**; se excluyeron **720,968** registros, aproximadamente **1.99 %** de la fuente. La tabla se particionó por `DATE(pickup_datetime)` y se clusterizó por `pickup_location_id` y `dropoff_location_id`.

**Limitación temporal:** diciembre contiene únicamente **57 viajes** en la fuente y en la tabla limpia. Por ello, las comparaciones mensuales se interpretan de enero a noviembre, y diciembre no se considera un mes completo o comparable.

### 6.3 Optimización medida

Se comparó una consulta con los mismos filtros aplicada a la fuente pública y a `viajes_limpios`, para enero de 2022 y la ubicación de origen `161`. Ambas consultas devolvieron **87,351 viajes** y una tarifa promedio de **10.38**. Con la caché desactivada, los bytes procesados bajaron de **1.78 GB** a **113.91 MB**, una reducción aproximada del **93.6 %**. Los tiempos variaron entre corridas, por lo que no se afirma una mejora constante en duración.

### 6.4 Tabla mensual

Se creó `proyecto2_taxi.resumen_mensual_2022`, que contiene **11 filas** correspondientes a enero-noviembre y resume cantidad de viajes, distancia promedio, duración promedio y tarifa promedio. La suma reportada es de **35,535,514 viajes** para esos once meses.

### 6.5 Scripts asociados

- [`sql/01_exploracion.sql`](sql/01_exploracion.sql): esquema, calidad, tendencias, zonas y métodos de pago.
- [`sql/02_limpieza.sql`](sql/02_limpieza.sql): reglas y creación de la tabla limpia.
- [`sql/03_optimizacion.sql`](sql/03_optimizacion.sql): metadatos y comparación de consultas.
- [`sql/04_resumen_mensual.sql`](sql/04_resumen_mensual.sql): resumen mensual.
- [Documentación detallada del integrante 1](docs/integrante1.md)

### 6.6 Evidencias del integrante 1

| Evidencia | Captura |
|---|---|
| Conteo de registros de la fuente | ![Conteo original](Integrante1_evidencias/conteo_registros.png) |
| Diagnóstico de calidad | ![Diagnóstico de calidad](Integrante1_evidencias/diagnostico_calidad.png) |
| Conteo después de la limpieza | ![Viajes válidos](Integrante1_evidencias/conteo_viajes_validos.png) |
| Creación de tabla particionada y clusterizada | ![Creación de tabla](Integrante1_evidencias/creacion_tabla_particion_cluster.png) |
| Consulta estándar: resultado | ![Consulta estándar](Integrante1_evidencias/consulta_estandar_resultado.png) |
| Consulta optimizada: resultado | ![Consulta optimizada](Integrante1_evidencias/consulta_optimizada_resultado.png) |
| Tendencias mensuales | ![Tendencias mensuales](Integrante1_evidencias/tendencias_mensuales.png) |
| Zonas de origen más frecuentes | ![Top zonas](Integrante1_evidencias/zonas_origen_top10.png) |
| Distribución por tipo de pago | ![Tipos de pago](Integrante1_evidencias/tipos_pago.png) |
| Resultados del resumen mensual | ![Resumen mensual](Integrante1_evidencias/resumen_mensual_resultados.png) |
| Validación del resumen mensual | ![Validación mensual](Integrante1_evidencias/resumen_mensual_validacion.png) |

La descripción completa de las capturas, incluidas las de esquema y trabajos de consulta, se encuentra en `docs/integrante1.md`.

## 7. Integrante 2 — Machine Learning

### 7.1 Preparación de datos

A partir de `viajes_limpios` se creó `proyecto2_taxi.datos_ml` con registros de enero a noviembre de 2022, duración entre 60 y 10,800 segundos, ubicaciones de origen y destino presentes, duración convertida a minutos y características temporales derivadas. Se utilizó un muestreo determinista aproximado del 1 % para reducir el volumen de procesamiento. La tabla resultante contiene **353,941 registros**.

La separación temporal fue:

| Conjunto | Periodo | Registros |
|---|---|---:|
| TRAIN | Enero–agosto de 2022 | 255,838 |
| VALIDATION | Septiembre de 2022 | 31,164 |
| TEST | Octubre–noviembre de 2022 | 66,939 |
| **Total** | Enero–noviembre de 2022 | **353,941** |

La división cronológica evita mezclar aleatoriamente periodos futuros con los usados para entrenamiento. Aun así, la selección de variables debe corresponder a la información disponible en el instante real en que se desea predecir.

### 7.2 Modelos entrenados

Se entrenaron dos modelos de BigQuery ML:

- **Regresión lineal** (`LINEAR_REG`), almacenada como `proyecto2_taxi.modelo_lineal`.
- **Random Forest Regressor** (`RANDOM_FOREST_REGRESSOR`), almacenado como `proyecto2_taxi.modelo_random_forest`.

La variable objetivo fue `duracion_minutos`. Se utilizaron características geográficas de origen y destino y variables temporales derivadas. Random Forest se entrenó con una submuestra aproximada de 20 mil registros para controlar el uso de recursos.

### 7.3 Resultados de evaluación

En VALIDATION (septiembre), la regresión lineal obtuvo MAE **7.4896**, RMSE **10.9595**, MSE **120.1114** y R² **0.4034**. Random Forest obtuvo MAE **7.8870**, RMSE **11.5528**, MSE **133.4678** y R² **0.3371**.

En la evaluación final sobre TEST (octubre-noviembre):

| Métrica | Regresión lineal | Random Forest | Mejor resultado en esta prueba |
|---|---:|---:|---|
| MAE (minutos) | **7.0924** | 7.4615 | Regresión lineal |
| RMSE (minutos) | **10.0382** | 10.6342 | Regresión lineal |
| MSE | **100.7650** | 113.0854 | Regresión lineal |
| R² | **0.4180** | 0.3468 | Regresión lineal |

Bajo las configuraciones probadas, la regresión lineal tuvo menor error y mayor R². El MAE de 7.0924 minutos significa que, en promedio, la magnitud del error absoluto fue de alrededor de siete minutos por viaje en el conjunto de prueba. Estos resultados son una línea base experimental y no una garantía de precisión para cada viaje futuro.

### 7.4 Predicciones

Se creó `proyecto2_taxi.predicciones_ml` con **10,000 filas**, 5,000 predicciones por modelo sobre una misma muestra de viajes de prueba. Entre sus campos están `modelo`, `fecha_viaje`, `duracion_real`, `duracion_predicha` y `error_absoluto`. Esta tabla se utiliza como insumo de comparación visual.

Los promedios de error calculados para la submuestra del dashboard no sustituyen las métricas de `ML.EVALUATE` sobre el conjunto TEST completo.

### 7.5 Scripts asociados

- [`ml/01_preparacion_datos.sql`](ml/01_preparacion_datos.sql)
- [`ml/02_modelo_lineal.sql`](ml/02_modelo_lineal.sql)
- [`ml/03_modelo_random_forest.sql`](ml/03_modelo_random_forest.sql)
- [`ml/04_evaluacion_modelos.sql`](ml/04_evaluacion_modelos.sql)
- [`ml/05_comparacion_modelos.sql`](ml/05_comparacion_modelos.sql)
- [`ml/06_predicciones.sql`](ml/06_predicciones.sql)
- [Documentación detallada del integrante 2](docs/integrante2.md)

### 7.6 Evidencias del integrante 2

| Evidencia | Captura |
|---|---|
| Columnas utilizadas para ML | ![Columnas ML](Integrante2_evidencias/01_columnas_ml.png) |
| Distribución mensual | ![Distribución mensual](Integrante2_evidencias/02_distribucion_mensual.png) |
| Creación de datos_ml | ![Creación de datos ML](Integrante2_evidencias/03_creacion_datos_ml.png) |
| Validación de TRAIN, VALIDATION y TEST | ![Separación temporal](Integrante2_evidencias/04_validacion_split.png) |
| Entrenamiento de regresión lineal | ![Modelo lineal](Integrante2_evidencias/05_modelo_lineal_entrenamiento.png) |
| Verificación del modelo lineal | ![Verificación lineal](Integrante2_evidencias/06_modelo_lineal_verificacion.png) |
| Evaluación de regresión lineal | ![Evaluación lineal](Integrante2_evidencias/07_evaluacion_lineal_validacion.png) |
| Entrenamiento de Random Forest | ![Random Forest](Integrante2_evidencias/08_modelo_random_forest_entrenamiento.png) |
| Evaluación de Random Forest | ![Evaluación Random Forest](Integrante2_evidencias/09_evaluacion_random_forest_validacion.png) |
| Comparación en VALIDATION | ![Comparación de modelos](Integrante2_evidencias/10_comparacion_modelos_validacion.png) |
| Evaluación final TEST | ![Evaluación final](Integrante2_evidencias/11_evaluacion_final_test.png) |
| Creación de predicciones_ml | ![Creación de predicciones](Integrante2_evidencias/12_creacion_predicciones_ml.png) |
| Validación de 5,000 predicciones por modelo | ![Resultados de predicciones](Integrante2_evidencias/13_resultados_predicciones_ml.png) |
| Predicciones mensuales por modelo | ![Predicciones por mes](Integrante2_evidencias/14_predicciones_por_mes.png) |

## 8. Integrante 3 — Dashboard y visualización

### 8.1 Objetivo de la visualización

Integrar indicadores de la tabla limpia, el resumen mensual y las predicciones para permitir explorar patrones del volumen de viajes y comparar la estimación de duración de los modelos.

### 8.2 Tablas preparadas para el dashboard

Se crearon las siguientes tablas derivadas en `proyecto2_taxi`:

| Tabla | Contenido | Uso visual |
|---|---|---|
| `dashboard_tipos_pago` | Cantidad y porcentaje de viajes por `payment_type` | Distribución de métodos de pago. |
| `dashboard_zonas_top10` | Diez identificadores de origen con más viajes | Ranking de zonas de recogida por volumen. |
| `dashboard_comparacion_modelos` | Promedios de duración real, duración predicha y error absoluto por modelo | Comparación visual de las predicciones. |
| `resumen_mensual_2022` | Cantidad de viajes y promedios mensuales | Evolución mensual de viajes en 2022. |

Los scripts SQL que crean las tres tablas `dashboard` deben mantenerse en `sql/dashboard/`:

- [01_dashboard_tipos_pago.sql](dashboard\01_dashboard_tipos_pago.sql)
- [02_dashboard_zonas_top10.sql](dashboard\02_dashboard_zonas_top10.sql)
- [03_dashboard_comparacion_modelos.sql](dashboard\03_dashboard_comparacion_modelos.sql)
- [Documentación detallada del integrante 3](docs/integrante3.md)

### 8.3 Visualizaciones reportadas

El dashboard de Looker Studio contiene las siguientes visualizaciones:

1. **Evolución mensual de viajes (2022):** muestra el comportamiento mensual usando `resumen_mensual_2022`. La interpretación comparativa se centra en enero-noviembre debido a la cobertura incompleta de diciembre.
2. **Tipos de pago:** presenta los viajes por código de `payment_type`. Los códigos se conservan tal como están en los datos utilizados.
3. **Top 10 zonas de recogida con más viajes:** ordena las zonas por `cantidad_viajes` en orden descendente.
4. **Comparación de duración real y predicha:** compara `duracion_real_promedio` y `duracion_predicha_promedio` por modelo. `error_absoluto_promedio` complementa la lectura de la precisión.

**Enlace al dashboard:** [Agregar aquí el enlace compartido de Looker Studio].

### 8.4 Evidencias del integrante 3

Las capturas finales del dashboard y de las consultas de creación/validación deben guardarse en `Integrante3_evidencias/`. Insertar los archivos reales y reemplazar o completar esta tabla antes de entregar:

| Evidencia | Captura |
|---|---|
| Dashboard completo en Looker Studio | ![dashboard_completo](Integrante3_evidencias/1.png)|
| Evolución mensual | ![01_evolucion_mensual.png](Integrante3_evidencias/7.png) |
| Distribución por tipo de pago | ![02_tipos_pago.png](Integrante3_evidencias/8.png) |
| Top 10 zonas de recogida | ![03_top10_zonas.png](Integrante3_evidencias/9.png) |
| Comparación de duración real y predicha | ![04_comparacion_modelos.png](Integrante3_evidencias/10.png) |
| Resultado de creación de `dashboard_tipos_pago` | ![05_sql_tipos_pago.png](Integrante3_evidencias/4.png) |
| Resultado de creación de `dashboard_zonas_top10` | ![06_sql_zonas_top10.png](Integrante3_evidencias/3.png) |
| Resultado de creación de `dashboard_comparacion_modelos` | ![07_sql_comparacion_modelos.png](Integrante3_evidencias/5.png) |
| Listado de tablas del dataset `proyecto2_taxi` | ![08_tablas_bigquery.png](Integrante3_evidencias/6.png) |


## 9. Resultados integrados y discusión

- La limpieza dejó una tabla común de **35.5 millones de registros**, que sirve como base para los análisis posteriores.
- La comparación de consultas mostró una reducción aproximada del **93.6 %** en bytes procesados al consultar la tabla preparada en lugar de la fuente pública bajo los filtros evaluados.
- El resumen mensual ofrece una tabla pequeña para analizar enero-noviembre sin repetir consultas costosas sobre la tabla completa.
- La regresión lineal superó a Random Forest en las métricas registradas de VALIDATION y TEST, con MAE final de **7.0924 minutos**.
- Las predicciones se almacenaron en una tabla común para facilitar la comparación y la visualización.
- El dashboard une indicadores descriptivos y resultados predictivos, pero la muestra utilizada para sus promedios no debe confundirse con la evaluación final completa del modelo.

## 10. Guía de reproducción

### 10.1 Requisitos previos

1. Tener acceso al proyecto de Google Cloud indicado y permisos para ejecutar consultas y crear tablas/modelos en BigQuery.
2. Seleccionar el proyecto `project-2694859a-c78d-43b5-952` y usar la ubicación `US`.
3. Confirmar que existe el dataset `proyecto2_taxi`.
4. Revisar cuotas, facturación y bytes estimados antes de ejecutar consultas costosas o entrenamientos.
5. Ejecutar los scripts en el orden que corresponde a sus dependencias.

### 10.2 Orden 

1. `sql/01_exploracion.sql`: revisar esquema y calidad.
2. `sql/02_limpieza.sql`: crear `viajes_limpios` si se necesita reconstruir la tabla.
3. `sql/03_optimizacion.sql`: repetir la comparación de consultas.
4. `sql/04_resumen_mensual.sql`: crear `resumen_mensual_2022`.
5. `ml/01_preparacion_datos.sql`: construir `datos_ml` y validar los conjuntos temporales.
6. `ml/02_modelo_lineal.sql` y `ml/03_modelo_random_forest.sql`: entrenar los modelos.
7. `ml/04_evaluacion_modelos.sql` y `ml/05_comparacion_modelos.sql`: evaluar y comparar.
8. `ml/06_predicciones.sql`: generar `predicciones_ml`.
9. Ejecutar los tres scripts de `sql/dashboard/` para crear las tablas agregadas.
10. Abrir el informe de Looker Studio y verificar que cada visualización use la tabla y los campos esperados.

No volver a crear tablas ni modelos existentes sin confirmar primero que se desea reemplazarlos. En particular, las sentencias `CREATE OR REPLACE` sustituyen el objeto de destino.

## 11. Organización del repositorio

```text
Proyecto_2/
├── dashboard/
│   ├── 01_dashboard_tipos_pago.sql
│   ├── 02_dashboard_zonas_top10.sql
│   └── 03_dashboard_comparacion_modelos.sql
├── sql/
│   ├── 01_exploracion.sql
│   ├── 02_limpieza.sql
│   ├── 03_optimizacion.sql
│   ├── 04_resumen_mensual.sql
├── ml/
│   ├── 01_preparacion_datos.sql
│   ├── 02_modelo_lineal.sql
│   ├── 03_modelo_random_forest.sql
│   ├── 04_evaluacion_modelos.sql
│   ├── 05_comparacion_modelos.sql
│   └── 06_predicciones.sql
├── docs/
│   ├── integrante1.md
│   ├── Integrante2.md
│   ├── Integrante3.md
├── Manual_Tecnico.md
├── Integrante1_evidencias/
├── Integrante2_evidencias/
└── Integrante3_evidencias/
└── README.md
```

La estructura es la organización objetivo del proyecto. Si alguno de los archivos aún no está incorporado al repositorio, debe agregarse antes de la entrega.


## 12. Conclusiones

El proyecto implementó un flujo de análisis desde la preparación de los registros hasta su consumo mediante visualizaciones. La tabla limpia y la organización física de BigQuery permiten reutilizar los datos y reducir los bytes procesados en la consulta comparada. Los modelos de regresión aportan una estimación experimental de duración, y la evaluación registrada favorece a la regresión lineal frente a Random Forest bajo las configuraciones utilizadas. Por último, las tablas agregadas y el dashboard integran tendencias descriptivas y comparación de predicciones en una presentación accesible.

Los resultados deben interpretarse dentro de sus límites: diciembre de 2022 tiene cobertura incompleta; la precisión predictiva es moderada y depende de las variables y particiones utilizadas; y los indicadores del dashboard basados en una muestra no reemplazan las métricas de evaluación calculadas sobre el conjunto TEST completo.

## 13. Referencias y documentación relacionada

- [Documentación del integrante 1](docs/integrante1.md)
- [Documentación del integrante 2](docs/integrante2.md)
- [Documentación del integrante 3](docs/integrante3.md)
- [README del proyecto](README.md)
- [Diccionario de datos de NYC TLC para viajes de taxi amarillo](https://www.nyc.gov/assets/tlc/downloads/pdf/data_dictionary_trip_records_yellow.pdf)
