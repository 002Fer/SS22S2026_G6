# Proyecto 2 — NYC Taxi Trips 2022
## Integrante 3: Visualización y documentación

### 1. Objetivo

Desarrollar un dashboard interactivo para visualizar indicadores relevantes del análisis de viajes de taxis de Nueva York durante 2022, utilizando los datos procesados en BigQuery y presentando los resultados mediante Looker Studio.

El dashboard integra información sobre la evolución mensual de los viajes, los métodos de pago, las principales zonas de recogida y la comparación de los modelos predictivos desarrollados por el equipo.

### 2. Herramientas utilizadas

- **Google Cloud Platform:** entorno de trabajo en la nube.
- **Google BigQuery:** ejecución de consultas SQL y creación de tablas agregadas para la visualización.
- **Looker Studio:** construcción del dashboard y presentación gráfica de los indicadores.
- **SQL:** agrupación, conteo, cálculo de porcentajes y resumen de predicciones.

### 3. Fuente de datos

Se utilizó el dataset procesado del proyecto almacenado en BigQuery:

- **Proyecto:** `project-2694859a-c78d-43b5-952`
- **Dataset:** `proyecto2_taxi`
- **Tabla principal:** `viajes_limpios`
- **Tabla de resumen mensual:** `resumen_mensual_2022`
- **Tabla de predicciones:** `predicciones_ml`

La tabla `viajes_limpios` contiene los viajes preparados para el análisis. Las tablas derivadas permiten generar visualizaciones sin tener que construir nuevamente cada indicador directamente en el dashboard.

### 4. Tablas creadas para el dashboard

#### 4.1. `dashboard_tipos_pago`

Resume la cantidad de viajes agrupados por `payment_type` y calcula el porcentaje que representa cada categoría respecto del total.

**Campos principales:**
- `payment_type`: código del tipo de pago.
- `cantidad_viajes`: cantidad de viajes por categoría.
- `porcentaje`: participación porcentual de cada categoría.

Esta tabla permite visualizar la distribución de los viajes según el código de pago registrado.

**Nota:** los códigos se conservan como valores originales; su interpretación debe realizarse de acuerdo con la clasificación de tipos de pago utilizada por el dataset.

#### 4.2. `dashboard_zonas_top10`

Identifica las diez ubicaciones de recogida con mayor cantidad de viajes.

**Campos principales:**
- `pickup_location_id`: identificador de la zona de recogida.
- `cantidad_viajes`: total de viajes registrados para esa ubicación.

La consulta excluye los identificadores nulos, agrupa los viajes por ubicación y selecciona las diez zonas con mayor frecuencia.

#### 4.3. `dashboard_comparacion_modelos`

Resume las predicciones generadas por los modelos de Machine Learning.

**Campos principales:**
- `modelo`: nombre del modelo predictivo.
- `total_predicciones`: cantidad de predicciones disponibles.
- `duracion_real_promedio`: promedio de duración real de los viajes, en minutos.
- `duracion_predicha_promedio`: promedio de duración estimada, en minutos.
- `error_absoluto_promedio`: promedio del error absoluto, en minutos.

Esta tabla permite comparar las duraciones reales y estimadas, además de observar el error promedio de cada modelo.

### 5. Visualizaciones del dashboard

#### 5.1. Evolución mensual de viajes (2022)

Utiliza la tabla `resumen_mensual_2022` para presentar la cantidad de viajes por mes y facilitar la identificación de variaciones temporales.

La tabla de resumen disponible comprende enero a noviembre. Diciembre presenta un volumen de registros considerablemente menor en los datos del proyecto, por lo que no se considera un mes comparable en este resumen.

#### 5.2. Distribución por tipo de pago

Presenta la cantidad de viajes por código de pago. Esta visualización permite reconocer cuáles categorías concentran más registros dentro de los datos analizados.

#### 5.3. Top 10 zonas de recogida con más viajes

Muestra las diez ubicaciones de recogida más frecuentes mediante un gráfico de barras horizontales. Facilita la comparación entre las zonas según el volumen de viajes registrados.

Los identificadores corresponden a `pickup_location_id`; no representan nombres de barrios a menos que se relacionen con un catálogo geográfico.

#### 5.4. Comparación de duración real y predicha

Compara, por modelo, la duración promedio observada y la duración promedio estimada. También se dispone del error absoluto promedio como indicador complementario.

Para evaluar la precisión, debe prestarse especial atención al error absoluto promedio: un valor menor indica una diferencia absoluta promedio más baja entre las duraciones reales y las estimadas en la muestra utilizada.

Las métricas de esta visualización resumen las predicciones almacenadas y no sustituyen las métricas de evaluación completas de BigQuery ML.

### 6. Acceso al dashboard

**Nombre del informe:** Proyecto 2 - Dashboard de Viajes NYC Taxi 2022 - Integrante 3

**Enlace de Looker Studio:** [Agregar aquí el enlace compartido del informe]

El acceso depende de los permisos configurados en Looker Studio. Antes de la entrega, debe verificarse que el docente o evaluador pueda abrir el informe.

### 7. Organización de archivos

La documentación y los scripts relacionados con esta parte del proyecto se organizan de la siguiente manera:

- `README.md`: descripción general del proyecto y guía de navegación.
- `docs/integrante3_dashboard.md`: documentación del dashboard, indicadores y visualizaciones.
- `sql/05_indicadores_dashboard.sql`: consultas SQL de los indicadores, si los scripts se consolidan en este archivo.
- `Integrante3_evidencias/`: capturas de las consultas ejecutadas, tablas generadas y dashboard final.

Los nombres anteriores corresponden a la estructura prevista para organizar los entregables; debe comprobarse que los archivos estén presentes en el repositorio final.

### 8. Validación y evidencias

La validación de esta parte del proyecto comprende:

1. Comprobar la ejecución exitosa de las consultas SQL.
2. Verificar la existencia de las tablas `dashboard_tipos_pago`, `dashboard_zonas_top10` y `dashboard_comparacion_modelos` en BigQuery.
3. Confirmar que las visualizaciones de Looker Studio utilizan las fuentes de datos correctas.
4. Verificar que los gráficos muestran sus dimensiones y métricas correspondientes.
5. Guardar capturas de los resultados y del dashboard completo.
6. Confirmar que el informe se encuentra guardado y que su enlace permite acceder a él.

Las capturas de pantalla constituyen evidencia de la ejecución y presentación de los resultados.

### 9. Conclusión

El dashboard integra indicadores descriptivos de los viajes y una comparación resumida de los modelos predictivos desarrollados en el proyecto. La combinación de BigQuery y Looker Studio permite organizar los resultados en visualizaciones accesibles, facilitando su interpretación y presentación.

La documentación, las consultas SQL y las evidencias complementan el dashboard y permiten identificar las fuentes utilizadas, los indicadores calculados y las validaciones realizadas.