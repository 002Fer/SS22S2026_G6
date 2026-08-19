# Ejecucion completa con Docker Compose

## Requisito

Tener Docker Desktop abierto y configurado para utilizar contenedores Linux.

## Iniciar SQL Server y ejecutar el ETL

Desde la carpeta `Practica1`:

```powershell
docker compose up -d
```

El comando realiza automáticamente lo siguiente:

1. descarga e inicia SQL Server 2022 Developer;
2. crea el volumen persistente `practica1_vuelos_sqlserver_data`;
3. espera hasta que SQL Server acepte conexiones;
4. construye el contenedor Python con pandas, pyodbc y ODBC Driver 18;
5. ejecuta extracción y transformación del CSV;
6. crea o verifica la base `VuelosDW` y su modelo estrella;
7. carga los datos y valida que los hechos hayan sido insertados.

La carga es idempotente. Volver a ejecutar `docker compose up -d` no duplica los `record_id` existentes.

## Comprobar el resultado

```powershell
docker compose ps -a
docker compose logs etl
```

El servicio `sqlserver` debe aparecer como `healthy`. El servicio `etl` es un proceso de una sola ejecución, por lo que termina con código `0` después de cargar los datos.

Para consultar la cantidad cargada desde el propio contenedor:

```powershell
docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd `
  -S localhost -U sa -P "Practica1_G6_2026!" -C `
  -d VuelosDW -Q "SELECT COUNT(*) AS Registros FROM dbo.FactVuelo"
```

## Conexión desde una herramienta gráfica

- Servidor: `localhost,1433`
- Usuario: `sa`
- Contraseña predeterminada: `Practica1_G6_2026!`
- Base de datos: `VuelosDW`
- Confiar en el certificado del servidor: sí

El puerto se publica únicamente en `127.0.0.1`, por lo que SQL Server no queda expuesto a otros equipos de la red local.

La contraseña y el puerto pueden cambiarse creando un archivo `.env`:

```env
MSSQL_SA_PASSWORD=OtraClaveSegura123!
SQLSERVER_PORT=1433
```

## Detener o reiniciar

Detener los contenedores conservando la base de datos:

```powershell
docker compose down
```

Volver a iniciarlos:

```powershell
docker compose up -d
```

El volumen no se elimina con `docker compose down`, por lo que los datos permanecen disponibles.
