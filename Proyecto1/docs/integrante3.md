# Integrante 3 - Airflow e Integración

Carnet: Integrante 3

## Responsabilidad y alcance

Esta sección cubre la orquestación del flujo ELT mediante Apache Airflow, la integración de los componentes desarrollados por el Integrante 1 (Extracción y carga Python a `raw`) y el Integrante 2 (Modelos analíticos dbt y pruebas en `marts`), así como la verificación global del pipeline.

---

## Arquitectura de Orquestación

El pipeline orquestado en Airflow sigue una topología acíclica dividida en 5 etapas secuenciales:

```text
                  +---------------------+
                  |   start_pipeline    |
                  +---------------------+
                             |
             +---------------+---------------+
             |                               |
             v                               v
  +---------------------+         +---------------------+
  |  load_oltp_to_raw   |         |   load_csv_to_raw   |
  +---------------------+         +---------------------+
             |                               |
             +---------------+---------------+
                             |
                             v
                  +---------------------+
                  |  validate_raw_data  |
                  +---------------------+
                             |
                             v
                  +---------------------+
                  |   dbt_run_models    |
                  +---------------------+
                             |
                             v
                  +---------------------+
                  |  dbt_test_quality   |
                  +---------------------+
                             |
                             v
                  +---------------------+
                  |    end_pipeline     |
                  +---------------------+
```

### Detalle de Tareas del DAG (`sgfood_elt_pipeline`)

1. **`start_pipeline` / `end_pipeline`:** Nodos de inicio y fin de control (`EmptyOperator`).
2. **`load_oltp_to_raw` (`BashOperator`):** Ejecuta `python -m src.main load-oltp` para extraer la base transaccional y cargar las 7 tablas en `raw`.
3. **`load_csv_to_raw` (`BashOperator`):** Ejecuta `python -m src.main load-csv` para cargar los 5 archivos CSV delimitados en `raw`.
4. **`validate_raw_data` (`BashOperator`):** Ejecuta `python -m src.main validate` para comprobar que el 100% de los registros esperados fueron insertados en `raw`.
5. **`dbt_run_models` (`BashOperator`):** Ejecuta `dbt run` construyendo las vistas de `staging` e `intermediate` y las tablas físicas de `marts` (`dim_*` y `fct_*`).
6. **`dbt_test_quality` (`BashOperator`):** Ejecuta `dbt test` corriendo las pruebas de integridad referencial, unicidad, no nulos y aserciones de negocio.

---

## Verificación de Funcionamiento

### 1. Comandos de Verificación Paso a Paso

```bash
# 1. Levantar la infraestructura completa con Docker Compose (incluyendo Airflow)
docker compose up --build -d

# 2. Verificar estado de los contenedores
docker compose ps

# 3. Probar la extracción y carga en raw (Python)
docker compose run --rm python_loader run-all

# 4. Probar las transformaciones de dbt
docker compose run --rm dbt dbt run --project-dir dbt/sgfood_dbt --profiles-dir dbt/sgfood_dbt

# 5. Probar las pruebas de calidad dbt
docker compose run --rm dbt dbt test --project-dir dbt/sgfood_dbt --profiles-dir dbt/sgfood_dbt

# 6. Probar la ejecución de las consultas analíticas en el Data Warehouse
psql -h localhost -p 5434 -U sgfood -d sgfood_dw -f sql/analytical_queries.sql
```

### 2. Criterios de Éxito según el Enunciado

- **Conteo de Registros:** 12 tablas cargadas en `raw` con 0 discrepancias de paridad.
- **Transformación:** Esquemas `staging`, `intermediate` y `marts` creados correctamente en PostgreSQL.
- **Calidad de Datos:** 100% de los dbt tests superados (*PASSED*) sin fallos ni alertas.
- **Orquestación Airflow:** Servidor web de Airflow activo en `http://localhost:8080`.
