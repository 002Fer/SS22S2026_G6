# Proyecto 1 - Seminario de Sistemas 2

## Integrantes

- Integrante 1: Python y fuentes de datos - Carnet `202000774`
- Integrante 2: PostgreSQL y dbt
- Integrante 3: Airflow e integración

---

## Descripción general

Este proyecto implementa un flujo ELT (Extract, Load, Transform) moderno para la empresa SG-Food utilizando Python, PostgreSQL, dbt Core y Apache Airflow.

El pipeline realiza la extracción desde una base transaccional y archivos CSV externos, carga los datos sin transformaciones de negocio en el esquema `raw` de un Data Warehouse en PostgreSQL, y deja los datos disponibles para los modelos dimensionales en dbt y la orquestación en Airflow.

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
├── docs/                       # Documentación del proyecto y catálogo de insumos
├── logs/                       # Bitácora de ejecución del cargador Python
├── sql/
│   ├── create_raw.sql          # DDL del esquema raw y definición de tablas de carga
│   └── validate_raw.sql        # Consultas de validación de conteo de registros en raw
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
├── docker-compose.yml          # Orquestación de contenedores (BD Fuente, DW y Loader)
├── Dockerfile                  # Contenedor de ejecución del pipeline Python
├── requirements.txt            # Dependencias Python
└── README.md
```

---

## Componente de Python y Fuentes de Datos (Integrante 1)

### Responsabilidad y alcance

El componente de Python tiene como único propósito la extracción técnica y carga estructurada hacia el esquema `raw` del Data Warehouse:

1. Extraer los datos desde la base de datos relacional transaccional (PostgreSQL OLTP).
2. Leer y validar los archivos planos delimitados (CSV).
3. Asegurar la consistencia de tipos de datos básicos y número de registros.
4. Cargar los datos crudos hacia las tablas del esquema `raw` en PostgreSQL Data Warehouse.
5. Gestionar el control de errores, reintentos de conexión y trazabilidad.

No realiza transformaciones de negocio ni reglas analíticas, las cuales corresponden a la fase de dbt (Integrante 2).

---

### Fuentes integradas y mapeo a raw

El proceso integra un total de 12 tablas en el esquema `raw`:

#### 1. Base transaccional PostgreSQL (`oltp_sgfood`)

| Tabla fuente | Tabla destino | Columnas | Registros esperados |
|---|---|---|---:|
| `sucursal` | `raw.sucursal` | `id_sucursal`, `nombre`, `ciudad`, `departamento` | 6 |
| `categoria` | `raw.categoria` | `id_categoria`, `nombre` | 8 |
| `marca` | `raw.marca` | `id_marca`, `nombre` | 10 |
| `producto` | `raw.producto` | `id_producto`, `sku`, `nombre`, `id_categoria`, `id_marca`, `unidad_medida`, `costo_base`, `precio_lista`, `activo` | 80 |
| `cliente` | `raw.cliente` | `id_cliente`, `nit`, `nombre`, `tipo_cliente`, `municipio`, `departamento`, `fecha_alta` | 250 |
| `venta` | `raw.venta` | `id_venta`, `fecha`, `id_cliente`, `id_sucursal`, `canal`, `metodo_pago`, `estado` | 1,200 |
| `venta_detalle` | `raw.venta_detalle` | `id_detalle`, `id_venta`, `id_producto`, `cantidad`, `precio_unitario`, `descuento`, `subtotal` | 3,209 |

#### 2. Archivos CSV externos (`data/csv/`)

| Archivo | Tabla destino | Columnas | Registros esperados |
|---|---|---|---:|
| `inventario_bodega.csv` | `raw.inventario_bodega` | `fecha_corte`, `id_sucursal`, `id_producto`, `stock_disponible`, `stock_minimo`, `stock_maximo`, `lote`, `fecha_vencimiento` | 3,840 |
| `proveedores_precios.csv` | `raw.proveedores_precios` | `id_proveedor`, `proveedor`, `id_producto`, `costo_proveedor`, `plazo_dias`, `fecha_vigencia` | 103 |
| `promociones.csv` | `raw.promociones` | `id_promocion`, `nombre`, `fecha_inicio`, `fecha_fin`, `id_categoria`, `porcentaje_descuento` | 30 |
| `metas_ventas.csv` | `raw.metas_ventas` | `periodo`, `id_sucursal`, `meta_ventas`, `meta_unidades` | 48 |
| `devoluciones.csv` | `raw.devoluciones` | `id_devolucion`, `fecha`, `id_venta`, `id_producto`, `cantidad`, `motivo` | 80 |

*Nota:* El archivo `data/quality/casos_calidad_opcionales.csv` contiene 10 registros diseñados para validaciones de calidad de datos y no se carga en las tablas operativas de `raw`.

---

### Funcionamiento técnico del pipeline

1. **Auditoría y linaje:**
   A cada registro cargado en `raw` se le agregan automáticamente tres columnas de control técnico:
   - `_loaded_at`: Timestamp UTC del momento exacto de inserción.
   - `_source`: Identificador de origen (`postgresql_oltp` o `csv:<nombre_archivo>`).
   - `_batch_id`: UUID único generado por corrida de extracción.

2. **Carga masiva eficiente (`COPY`):**
   La inserción de registros utiliza el protocolo nativo `COPY FROM STDIN` de PostgreSQL a través del cursor de psycopg, evitando inserciones individuales lentas (`INSERT INTO ... VALUES`) y permitiendo una carga de alto rendimiento.

3. **Atomicidad y manejo transaccional:**
   La carga de cada grupo (OLTP y CSV) se realiza bajo una transacción de base de datos. Si ocurre un fallo en cualquier tabla o registro, se ejecuta un `ROLLBACK` automático, garantizando que el esquema `raw` no quede en un estado inconsistente o parcialmente cargado.

4. **Tolerancia a fallos de conexión:**
   El módulo `database.py` implementa un mecanismo de reintentos con intervalo configurable (`DB_CONNECT_ATTEMPTS` y `DB_CONNECT_DELAY_SECONDS`) para esperar a que los servicios de base de datos estén completamente disponibles antes de iniciar.

5. **Validación de paridad:**
   Al finalizar, la función `validate_raw` compara automáticamente los conteos obtenidos en `raw` contra los conteos reales de la base transaccional y los registros esperados de los CSV. Si se detecta alguna discrepancia, el proceso lanza un error y retorna código de salida `1`.

---

### Guía de uso

#### Requisitos previos

- Docker y Docker Compose instalados.
- Python 3.11+ (opcional para pruebas locales).

#### 1. Ejecución completa con Docker Compose

Para levantar las bases de datos transaccional (`source_db`), el Data Warehouse (`warehouse_db`) y ejecutar la carga completa de datos:

```bash
docker compose up --build
```

#### 2. Ejecución modular de tareas (para integración con Airflow)

El script `src.main` expone comandos individuales mediante interfaz CLI. Pueden ejecutarse a través del contenedor o en entorno local:

- **Cargar solo fuentes OLTP:**
  ```bash
  docker compose run --rm python_loader load-oltp
  ```
- **Cargar solo fuentes CSV:**
  ```bash
  docker compose run --rm python_loader load-csv
  ```
- **Validar conteos de tablas raw:**
  ```bash
  docker compose run --rm python_loader validate
  ```
- **Inspeccionar casos de calidad opcionales:**
  ```bash
  docker compose run --rm python_loader quality-cases
  ```
- **Ejecutar todo el flujo de carga y validación:**
  ```bash
  docker compose run --rm python_loader run-all
  ```

#### 3. Ejecución directa con Python (entorno local)

Si se desea ejecutar sin Docker, configurar las variables en el archivo `.env` o exportarlas en la terminal:

```bash
pip install -r requirements.txt
python -m src.main run-all
```

#### 4. Ejecución de pruebas unitarias

El proyecto incluye pruebas unitarias para validar los conversores de tipos, consistencia de archivos CSV y esquemas:

```bash
python -m unittest discover -s tests -v
```

#### 5. Limpieza y reinicio de datos

Para reiniciar los volúmenes de las bases de datos y comenzar desde cero:

```bash
docker compose down -v
```

---

## Guía de integración para el Integrante 2 (PostgreSQL y dbt)

Esta sección contiene los parámetros técnicos, esquemas y relaciones que el Integrante 2 necesita para configurar su proyecto dbt y diseñar los modelos analíticos.

### 1. Conexión al Data Warehouse (`profiles.yml`)

Para configurar la conexión de dbt hacia la base de datos Data Warehouse en PostgreSQL:

```yaml
sgfood_dw:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost       # O "warehouse_db" si dbt corre dentro de la red Docker
      port: 5434            # 5432 si corre dentro de Docker
      user: sgfood
      pass: sgfood_dw_2026
      dbname: sgfood_dw
      schema: public
      threads: 4
```

### 2. Declaración de fuentes en dbt (`models/staging/sources.yml`)

El Integrante 2 debe configurar dbt para leer desde el esquema `raw`:

```yaml
version: 2

sources:
  - name: raw
    schema: raw
    description: "Tablas crudas cargadas por Python desde OLTP y archivos CSV."
    tables:
      - name: sucursal
      - name: categoria
      - name: marca
      - name: producto
      - name: cliente
      - name: venta
      - name: venta_detalle
      - name: inventario_bodega
      - name: proveedores_precios
      - name: promociones
      - name: metas_ventas
      - name: devoluciones
```

Cada tabla en `raw` cuenta además con las columnas `_loaded_at`, `_source` y `_batch_id` para control de auditoría.

### 3. Mapa de relaciones entre tablas para el modelo dimensional

Para diseñar el esquema estrella (tablas de dimensiones y hechos en `marts`):

```text
Entidades y relaciones clave:
• venta (id_venta) <--- venta_detalle (id_venta)
• cliente (id_cliente) <--- venta (id_cliente)
• sucursal (id_sucursal) <--- venta (id_sucursal), inventario_bodega (id_sucursal), metas_ventas (id_sucursal)
• categoria (id_categoria) <--- producto (id_categoria), promociones (id_categoria)
• marca (id_marca) <--- producto (id_marca)
• producto (id_producto) <--- venta_detalle (id_producto), inventario_bodega (id_producto), 
                              proveedores_precios (id_producto), devoluciones (id_producto)
• venta (id_venta) + producto (id_producto) <--- devoluciones (id_venta, id_producto)
```

### 4. Estructura sugerida para los modelos dbt

- `models/staging/`: Modelos `stg_*.sql` que limpian tipos de datos, eliminan espacios en blanco y renombran columnas usando `{{ source('raw', 'nombre_tabla') }}`.
- `models/intermediate/`: Modelos `int_*.sql` para métricas intermedias, consolidación de costos o cálculo de líneas de venta.
- `models/marts/`:
  - **Dimensiones:** `dim_clientes.sql`, `dim_productos.sql`, `dim_sucursales.sql`, `dim_fecha.sql`.
  - **Hechos:** `fct_ventas.sql`, `fct_inventario.sql`, `fct_metas.sql`, `fct_devoluciones.sql`.
- **Pruebas de calidad (`tests`):** Pruebas de `unique`, `not_null`, `relationships` en los archivos `.yml` de cada modelo.

