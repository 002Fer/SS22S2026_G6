# Proyecto 1
## Laboratorio de seminario de sistemas 2
## Grupo 6
## Implementación de un flujo moderno de datos con Python, Apache Airflow, dbt y PostgreSQL
| Nombre        | Carnet          |
|---------------|--------------|
| Gerson David Otoniel González Morales   | 202000774 |
| Fernando Misael Morales Ortiz   | 202001950 |
| María Cecilia Cotzajay López  | 201602659 |


# Python y fuentes de datos


## Responsabilidad

Esta parte implementa la extracción desde PostgreSQL transaccional, la lectura de las fuentes CSV y la carga técnica al schema `raw` del Data Warehouse en PostgreSQL.

El proceso no contiene transformaciones de negocio. Los modelos `staging`, `intermediate` y `marts` corresponden a dbt.

## Fuentes

### PostgreSQL transaccional

Schema `oltp_sgfood`:

| Tabla | Registros esperados |
|---|---:|
| sucursal | 6 |
| categoria | 8 |
| marca | 10 |
| producto | 80 |
| cliente | 250 |
| venta | 1,200 |
| venta_detalle | 3,209 |

### CSV cargados en la corrida principal

| Archivo | Registros esperados |
|---|---:|
| inventario_bodega.csv | 3,840 |
| proveedores_precios.csv | 103 |
| promociones.csv | 30 |
| metas_ventas.csv | 48 |
| devoluciones.csv | 80 |

`casos_calidad_opcionales.csv` contiene datos inválidos intencionales y no se carga en la corrida principal.

## Tablas de salida

Las doce fuentes se cargan en tablas homónimas dentro del schema `raw`. Cada tabla incluye:

- `_loaded_at`: fecha y hora UTC de carga.
- `_source`: fuente del registro.
- `_batch_id`: identificador del lote.

La carga es de tipo snapshot completo. Antes de cargar cada grupo de fuentes se vacían sus tablas dentro de una transacción. Si ocurre un error, PostgreSQL ejecuta rollback y conserva el estado anterior.

## Comandos

Levantar las bases y ejecutar toda la carga:

```bash
docker compose up --build
```

Ejecutar tareas individuales para Airflow:

```bash
docker compose run --rm python_loader load-oltp
docker compose run --rm python_loader load-csv
docker compose run --rm python_loader validate
docker compose run --rm python_loader quality-cases
```

El comando `quality-cases` solamente informa cuántos casos existen; no los inserta.

## Interfaz para Airflow

Orden recomendado:

1. `load-oltp`
2. `load-csv`
3. `validate`
4. `dbt run`
5. `dbt test`

Los comandos Python terminan con código `0` cuando tienen éxito y `1` cuando ocurre un error. Los mensajes se envían a la salida estándar y al archivo `logs/python_raw_load.log`.

## Pruebas locales

```bash
python -m unittest discover -s tests -v
```

## Reinicio completo

Este comando elimina las dos bases de datos locales y sus volúmenes:

```bash
docker compose down -v
```

Después se puede ejecutar nuevamente `docker compose up --build`.



# PostgreSQL y dbt



## Responsabilidad y alcance

Esta sección cubre el diseño del Data Warehouse dimensional en PostgreSQL y la implementación de los modelos dbt para transformar los datos crudos del esquema `raw` hacia un modelo analítico robusto (esquema Estrella) en los esquemas `staging`, `intermediate` y `marts`.

---

## Arquitectura del Data Warehouse

El Data Warehouse en PostgreSQL utiliza cuatro esquemas claramente delimitados:

1. **`raw`**: Carga directa de fuentes OLTP y CSV realizada por el Integrante 1.
2. **`staging`**: Modelos de limpieza inicial, estandarización de nombres, tipado explícito y eliminación de espacios en blanco (`stg_*.sql`). Materializados como `view`.
3. **`intermediate`**: Consolidación de reglas de negocio complejas, unión de encabezados con detalles de transacciones, cálculo de importes monetarios y costos de inventario (`int_*.sql`). Materializados como `view`.
4. **`marts`**: Modelo dimensional final en Estrella (Star Schema) compuesto por tablas de dimensiones y hechos (`dim_*.sql` y `fct_*.sql`). Materializados como `table`.

---

## Modelo Multidimensional (Esquema Estrella)

```text
                                  +-------------------+
                                  |    dim_fecha      |
                                  +-------------------+
                                  | fecha_sk (PK)     |
                                  +-------------------+
                                            |
                                            |
   +-------------------+          +-------------------+          +-------------------+
   |   dim_clientes    |          |    fct_ventas     |          |  dim_sucursales   |
   +-------------------+          +-------------------+          +-------------------+
   | cliente_sk (PK)   |<---------| venta_linea_sk(PK)|--------->| sucursal_sk (PK)  |
   +-------------------+          | cliente_sk (FK)   |          +-------------------+
                                  | sucursal_sk (FK)  |                    ^
                                  | producto_sk (FK)  |                    |
   +-------------------+          | fecha_sk (FK)     |                    |
   |   dim_productos   |          | cantidad          |          +-------------------+
   +-------------------+          | monto_neto        |          | fct_inventario /  |
   | producto_sk (PK)  |<---------| utilidad          |--------->| fct_metas_ventas /|
   +-------------------+          +-------------------+          | fct_devoluciones  |
                                                                 +-------------------+
```

### Tablas de Dimensiones (`marts/dimensions/`)

- **`dim_clientes`**: Dimensión de clientes registrada con clave surrogada `cliente_sk` (MD5 de `id_cliente`), identificador natural `id_cliente`, NIT, nombre, tipo de cliente, municipio y departamento.
- **`dim_productos`**: Dimensión de catálogo desnormalizada que incluye jerarquía de categoría y marca, SKU, nombre del producto, unidad de medida, costo base y precio de lista.
- **`dim_sucursales`**: Dimensión de puntos de distribución de SG-Food con ciudad y departamento.
- **`dim_fecha`**: Dimensión de calendario generada en SQL que abarca desde 2024 hasta 2026, incluyendo atributos de año, mes, día, trimestre, nombre de día/mes e indicador de fin de semana.

### Tablas de Hechos (`marts/facts/`)

- **`fct_ventas`**: Hecho granular a nivel de línea de detalle de venta. Contiene claves foráneas hacia todas las dimensiones y métricas de cantidad, precio unitario, monto bruto, descuento, monto neto, costo total y utilidad bruta.
- **`fct_inventario`**: Snapshots de inventario en bodega por fecha de corte y sucursal. Incluye stock disponible, stock mínimo/máximo, lote, vencimiento, costo unitario y valoración total de inventario a costo.
- **`fct_metas_ventas`**: Metas mensuales de ventas en Quetzales y volumen de unidades por sucursal.
- **`fct_devoluciones`**: Registro de devoluciones de producto enlazadas con la sucursal, producto, cliente y fecha de ocurrencia.

---

## Estructura del proyecto dbt (`dbt/sgfood_dbt/`)

```text
dbt/sgfood_dbt/
├── macros/
│   └── generate_schema_name.sql    # Sobrescribe el nombre por defecto para mantener schemas limpios
├── models/
│   ├── staging/                    # 12 modelos stg_*.sql y sources.yml
│   │   ├── sources.yml
│   │   ├── stg_sucursales.sql
│   │   ├── stg_categorias.sql
│   │   ├── stg_marcas.sql
│   │   ├── stg_productos.sql
│   │   ├── stg_clientes.sql
│   │   ├── stg_ventas.sql
│   │   ├── stg_ventas_detalle.sql
│   │   ├── stg_inventario_bodega.sql
│   │   ├── stg_proveedores_precios.sql
│   │   ├── stg_promociones.sql
│   │   ├── stg_metas_ventas.sql
│   │   ├── stg_devoluciones.sql
│   │   └── stg_models.yml
│   ├── intermediate/               # Modelos int_*.sql
│   │   ├── int_ventas_lineas.sql
│   │   ├── int_inventario_costos.sql
│   │   ├── int_devoluciones_detalle.sql
│   │   └── int_models.yml
│   └── marts/                      # Dimensiones y hechos
│       ├── dimensions/
│       │   ├── dim_clientes.sql
│       │   ├── dim_productos.sql
│       │   ├── dim_sucursales.sql
│       │   └── dim_fecha.sql
│       ├── facts/
│       │   ├── fct_ventas.sql
│       │   ├── fct_inventario.sql
│       │   ├── fct_metas_ventas.sql
│       │   └── fct_devoluciones.sql
│       └── marts_models.yml
├── tests/                           # Pruebas singulares de calidad
│   ├── assert_ventas_monto_positivo.sql
│   ├── assert_stock_no_negativo.sql
│   └── assert_devoluciones_validas.sql
├── dbt_project.yml
└── profiles.yml
```

---

## Pruebas de Calidad de Datos (dbt tests)

El proyecto cuenta con un suite integral de pruebas automáticas:

1. **Pruebas Genéricas (`not_null`, `unique`, `relationships`):**
   - Garantía de unicidad y no nulos en claves primarias y surrogadas (`*_sk`).
   - Verificación de integridad referencial entre las tablas de hechos (`fct_ventas`, `fct_inventario`, `fct_devoluciones`) y las dimensiones (`dim_clientes`, `dim_productos`, `dim_sucursales`, `dim_fecha`).
2. **Pruebas Singulares Personalizadas (`tests/*.sql`):**
   - `assert_ventas_monto_positivo.sql`: Confirma que ningún ítem de venta registre un monto neto negativo.
   - `assert_stock_no_negativo.sql`: Asegura que el stock disponible en bodega sea mayor o igual a cero.
   - `assert_devoluciones_validas.sql`: Valida que las cantidades devueltas sean estrictamente superiores a cero.

---

## Guía de ejecución con dbt

### 1. Ejecución mediante Docker (Recomendada con Airflow)

```bash
docker compose run --rm dbt dbt run --project-dir dbt/sgfood_dbt --profiles-dir dbt/sgfood_dbt
docker compose run --rm dbt dbt test --project-dir dbt/sgfood_dbt --profiles-dir dbt/sgfood_dbt
```

### 2. Ejecución local en terminal

```bash
cd dbt/sgfood_dbt
dbt run --profiles-dir .
dbt test --profiles-dir .
```

### 3. Generación de Documentación y Linaje en dbt

```bash
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .
```

---

## Validaciones y Consultas Analíticas (`sql/`)

Se incluyeron dos scripts SQL clave en el repositorio:

- **`sql/validate_marts.sql`**: Script para verificar los conteos finales en cada esquema (`staging` y `marts`).
- **`sql/analytical_queries.sql`**: 5 consultas de Inteligencia de Negocios para SG-Food:
  1. Rendimiento y margen de utilidad bruta por sucursal y departamento.
  2. Top 10 productos líderes en ingresos y unidades.
  3. Porcentaje de cumplimiento de metas mensuales por sucursal.
  4. Monitoreo de inventarios en nivel crítico (por debajo del mínimo).
  5. Tasa y motivos de devoluciones de producto por sucursal.


# Airflow e Integración


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
