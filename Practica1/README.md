# Práctica 1 - ETL de vuelos

Proyecto de ETL en Python con un modelo multidimensional en SQL Server.

## Modelo y carga

La parte de modelo y carga incluye:

- modelo estrella para los registros de vuelos;
- dimensiones de fecha, aerolínea, aeropuerto, pasajero, vuelo, estado y venta;
- tabla de hechos `FactVuelo`;
- historial Tipo 2 en `DimPasajero`;
- claves primarias, claves foráneas e índices;
- carga desde Python sin duplicar registros;
- ejecución de SQL Server y del ETL con Docker Compose;
- diagrama del modelo en `docs/diagrama_modelo.md`.

## Ejecución

Con Docker Desktop abierto, ejecutar desde esta carpeta:

```bash
docker compose up -d
```

Para revisar el resultado:

```bash
docker compose logs etl
```

La carga correcta finaliza con 10,000 registros verificados. El contenedor `etl` termina con código `0` y SQL Server permanece en ejecución.

## Conexión

```text
Servidor: localhost,1433
Base de datos: VuelosDW
Usuario: sa
Contraseña: Practica1_G6_2026!
```

El script de creación se encuentra en `sql/create_database.sql` y la carga en `src/load.py`.
