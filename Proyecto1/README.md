# Proyecto 1 - Seminario de Sistemas 2 (SG-Food)

## Integrantes

- **Integrante 1:** Python y fuentes de datos - Carnet `202000774`
- **Integrante 2:** PostgreSQL y dbt - Carnet `202001950`
- **Integrante 3:** Airflow e integración - Carnet `201602659`

---

## Descripción general

Este proyecto implementa una solución ELT (Extract, Load, Transform) completa e integral para la empresa **SG-Food** utilizando Python, PostgreSQL, dbt Core y Apache Airflow.

El pipeline realiza la extracción desde una base transaccional OLTP y archivos CSV externos, carga los datos sin transformaciones de negocio en el esquema `raw` de un Data Warehouse en PostgreSQL, construye un modelo analítico dimensional en esquema Estrella mediante modelos dbt en los esquemas `staging`, `intermediate` y `marts`, y orquesta el flujo de inicio a fin utilizando Apache Airflow.

```text
+----------------------------+
|  PostgreSQL OLTP (Fuente)  |---+
+----------------------------+   |
                                 v
+----------------------------+  Python   +----------------------------+  dbt   +----------------------------+
|        Archivos CSV        |---------->|  PostgreSQL Data Warehouse |------->|  staging / intermediate /  |
|         (Externos)         |           |       (Esquema raw)        |        |           marts            |
+----------------------------+           +----------------------------+        +----------------------------+
                                                       ^
                                                       |
                                            Apache Airflow (DAG)
```

---

## Estructura del repositorio

```text
Proyecto1/
├── dags/
│   └── sgfood_elt_dag.py       # DAG principal de Apache Airflow
├── data/
│   ├── csv/                    # Archivos CSV de fuentes externas
│   ├── oltp/                   # Script DDL y datos de la BD transaccional (sgfood_oltp.sql)
│   └── quality/                # Casos de prueba de calidad de datos opcionales
├── dbt/
│   └── sgfood_dbt/             # Proyecto dbt Core (staging, intermediate, marts, tests)
│       ├── macros/
│       ├── models/
│       │   ├── staging/        # 12 modelos stg_*.sql y sources.yml
│       │   ├── intermediate/   # 3 modelos int_*.sql
│       │   └── marts/          # Dimensiones (dim_*) y Hechos (fct_*)
│       ├── tests/              # Pruebas singulares de calidad
│       ├── dbt_project.yml
│       └── profiles.yml
├── docs/                       # Documentación del proyecto por integrante
│   ├── integrante1.md          # Documentación técnica de Python y fuentes raw
│   ├── integrante2.md          # Documentación técnica de PostgreSQL, dbt y Data Warehouse
│   ├── integrante3.md          # Documentación técnica de Apache Airflow e integración
│   └── catalogo_insumos_sgfood.xlsx
├── logs/                       # Bitácora de ejecución del cargador Python
├── sql/
│   ├── create_schemas.sql      # Definición de esquemas raw, staging, intermediate, marts
│   ├── create_raw.sql          # DDL del esquema raw
│   ├── validate_raw.sql        # Consultas de validación de conteo en raw
│   ├── validate_marts.sql      # Consultas de validación de conteo en marts
│   └── analytical_queries.sql  # 5 Consultas analíticas de inteligencia de negocios
├── src/
│   ├── __init__.py
│   ├── config.py               # Carga de variables de entorno y configuración de conexión
│   ├── database.py             # Conexión con reintentos y ejecución de scripts SQL
│   ├── main.py                 # Punto de entrada CLI para ejecución modular
│   ├── pipeline.py             # Lógica de extracción, carga por streaming y validación
│   └── sources.py              # Definición de fuentes, esquemas, conversores y parseo
├── tests/
│   └── test_sources.py         # Pruebas unitarias de parseo, conversores y fuentes
├── .env.example                # Plantilla de variables de entorno
├── docker-compose.yml          # Orquestación de contenedores (BD Fuente, DW, Loader, dbt)
├── Dockerfile                  # Contenedor de ejecución del pipeline Python
├── requirements.txt            # Dependencias Python
└── README.md
```

---

## Componente 1: Python y Fuentes de Datos (Integrante 1)

### Responsabilidad y alcance
El componente de Python realiza la extracción técnica y carga estructurada hacia el esquema `raw` del Data Warehouse:

1. Extraer los datos desde la base de datos relacional transaccional (PostgreSQL OLTP).
2. Leer y validar los archivos planos delimitados (CSV).
3. Asegurar la consistencia de tipos de datos básicos y número de registros.
4. Cargar los datos crudos hacia las tablas del esquema `raw` en PostgreSQL Data Warehouse con auditoría (`_loaded_at`, `_source`, `_batch_id`).

Ver [`docs/integrante1.md`](file:///c:/Users/compu/Desktop/SS22S2026_G6/Proyecto1/docs/integrante1.md).

---

## Componente 2: PostgreSQL y dbt (Integrante 2)

### Responsabilidad y alcance
El componente de PostgreSQL y dbt define la arquitectura del Data Warehouse dimensional en Esquema Estrella y realiza las transformaciones mediante dbt Core:

1. **Diseño de Esquemas:** Separación estricta de capas (`raw`, `staging`, `intermediate`, `marts`).
2. **Capa Staging (`models/staging/`):** 12 modelos `stg_*.sql` que limpian y tipan los atributos.
3. **Capa Intermedia (`models/intermediate/`):** 3 modelos `int_*.sql` que aplican reglas de negocio, ventas netas, descuentos, costos y márgenes de utilidad.
4. **Capa Marts (`models/marts/`):**
   - **Dimensiones:** `dim_clientes`, `dim_productos`, `dim_sucursales`, `dim_fecha`.
   - **Hechos:** `fct_ventas`, `fct_inventario`, `fct_metas_ventas`, `fct_devoluciones`.
5. **Pruebas de Calidad:** Validaciones genéricas YML y 3 pruebas singulares (`tests/*.sql`).
6. **Consultas Analíticas (`sql/analytical_queries.sql`):** 5 reportes estratégicos de inteligencia de negocios.

Ver [`docs/integrante2.md`](file:///c:/Users/compu/Desktop/SS22S2026_G6/Proyecto1/docs/integrante2.md).

---

## Componente 3: Apache Airflow e Integración (Integrante 3)

### Responsabilidad y alcance
El componente de Apache Airflow orquesta el flujo ELT completo de inicio a fin:

1. **Definición del DAG (`dags/sgfood_elt_dag.py`):** Define las dependencias entre la extracción de datos Python (`load-oltp`, `load-csv`), la validación de paridad (`validate`), la construcción de modelos dbt (`dbt run`) y las pruebas de calidad (`dbt test`).
2. **Control de Ejecución:** Manejo de reintentos, logs de ejecución y calendarización diaria (`0 3 * * *`).

Ver [`docs/integrante3.md`](file:///c:/Users/compu/Desktop/SS22S2026_G6/Proyecto1/docs/integrante3.md).

---

## Guía de Ejecución

### 1. Ejecución Completa con Docker Compose

```bash
# Levantar bases de datos y cargador Python
docker compose up --build -d

# Ejecutar el modelo dimensional en dbt
docker compose run --rm dbt dbt run --project-dir dbt/sgfood_dbt --profiles-dir dbt/sgfood_dbt

# Ejecutar las pruebas de calidad dbt
docker compose run --rm dbt dbt test --project-dir dbt/sgfood_dbt --profiles-dir dbt/sgfood_dbt
```

### 2. Ejecución de Consultas Analíticas

```bash
psql -h localhost -p 5434 -U sgfood -d sgfood_dw -f sql/analytical_queries.sql
```
