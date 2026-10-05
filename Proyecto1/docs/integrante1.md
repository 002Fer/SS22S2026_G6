# Integrante 1 - Python y fuentes de datos

Carnet: `202000774`

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

