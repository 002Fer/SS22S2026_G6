# Proyecto 1 - Seminario de Sistemas 2 (SG-Food)

## Integrantes

- **Integrante 1:** Python y fuentes de datos - Carnet `202000774`
- **Integrante 2:** PostgreSQL y dbt - Carnet `202001950`
- **Integrante 3:** Airflow e integración

---

## Descripción general

Este proyecto implementa una solución ELT (Extract, Load, Transform) completa e integral para la empresa **SG-Food** utilizando Python, PostgreSQL, dbt Core y Apache Airflow.

El pipeline realiza la extracción desde una base transaccional OLTP y archivos CSV externos, carga los datos sin transformaciones de negocio en el esquema `raw` de un Data Warehouse en PostgreSQL, y construye un modelo analítico dimensional en esquema Estrella mediante modelos dbt en los esquemas `staging`, `intermediate` y `marts`.

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
El componente de Python tiene como único propósito la extracción técnica y carga estructurada hacia el esquema `raw` del Data Warehouse:

1. Extraer los datos desde la base de datos relacional transaccional (PostgreSQL OLTP).
2. Leer y validar los archivos planos delimitados (CSV).
3. Asegurar la consistencia de tipos de datos básicos y número de registros.
4. Cargar los datos crudos hacia las tablas del esquema `raw` en PostgreSQL Data Warehouse.
5. Gestionar el control de errores, reintentos de conexión y trazabilidad con auditoría (`_loaded_at`, `_source`, `_batch_id`).

Para más detalle técnico, ver [`docs/integrante1.md`](file:///c:/Users/compu/Desktop/SS22S2026_G6/Proyecto1/docs/integrante1.md).

---

## Componente 2: PostgreSQL y dbt (Integrante 2)

### Responsabilidad y alcance
El componente de PostgreSQL y dbt tiene a su cargo la arquitectura del Data Warehouse, la definición del modelo dimensional en esquema Estrella y la transformación de datos mediante dbt Core:

1. **Diseño de Esquemas:** Separación estricta de capas (`raw`, `staging`, `intermediate`, `marts`).
2. **Capa Staging (`models/staging/`):** Modelos `stg_*.sql` que leen de `raw`, limpian tipos de datos, eliminan espacios en blanco y renombran atributos de forma estándar.
3. **Capa Intermedia (`models/intermediate/`):** Modelos `int_*.sql` que consolidan encabezados con detalles, calculan ingresos brutos/netos, descuentos, costos y márgenes de utilidad.
4. **Capa Marts (`models/marts/`):**
   - **Dimensiones:** `dim_clientes`, `dim_productos` (con jerarquía de categoría y marca), `dim_sucursales`, `dim_fecha`.
   - **Hechos:** `fct_ventas` (grano por ítem de venta), `fct_inventario` (snapshots de stock y valoración a costo), `fct_metas_ventas` (cumplimiento de objetivos), `fct_devoluciones` (incidencias de producto).
5. **Pruebas de Calidad de Datos:** Validaciones automáticas `not_null`, `unique`, `relationships` e inventario de pruebas singulares (`tests/*.sql`).
6. **Consultas Analíticas (`sql/analytical_queries.sql`):** Reportes de ventas, márgenes, metas, stock crítico y devoluciones.

Para más detalle técnico, ver [`docs/integrante2.md`](file:///c:/Users/compu/Desktop/SS22S2026_G6/Proyecto1/docs/integrante2.md).

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

### 2. Ejecución Local de dbt

```bash
cd dbt/sgfood_dbt
dbt run --profiles-dir .
dbt test --profiles-dir .
```

---

## Verificación de Resultados

- **Validación de Tablas Raw:** `docker compose run --rm python_loader validate`
- **Validación de Marts en DW:** `psql -h localhost -p 5434 -U sgfood -d sgfood_dw -f sql/validate_marts.sql`
- **Ejecución de Consultas Analíticas:** `psql -h localhost -p 5434 -U sgfood -d sgfood_dw -f sql/analytical_queries.sql`
