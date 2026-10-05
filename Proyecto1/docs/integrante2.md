# Integrante 2 - PostgreSQL y dbt

Carnet: `202001950`

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
