"""Carga el dataset limpio al modelo estrella de SQL Server.

La carga es transaccional e idempotente por ``record_id``. Las dimensiones
pequenas se actualizan como Tipo 1 y ``DimPasajero`` conserva historia Tipo 2.
"""

from __future__ import annotations

import argparse
import os
import re
from datetime import datetime
from pathlib import Path
from typing import Any

import pandas as pd


RAIZ_PROYECTO = Path(__file__).resolve().parent.parent
RUTA_CSV_PREDETERMINADA = RAIZ_PROYECTO / "datos" / "dataset_vuelos_limpio.csv"
RUTA_SQL_PREDETERMINADA = RAIZ_PROYECTO / "sql" / "create_database.sql"
FECHA_MAXIMA = datetime(9999, 12, 31, 23, 59, 59)

COLUMNAS_REQUERIDAS = {
    "record_id",
    "airline_code",
    "airline_name",
    "flight_number",
    "origin_airport",
    "destination_airport",
    "departure_datetime",
    "arrival_datetime",
    "duration_min",
    "status",
    "delay_min",
    "aircraft_type",
    "cabin_class",
    "seat",
    "passenger_id",
    "passenger_gender",
    "passenger_age",
    "passenger_nationality",
    "booking_datetime",
    "sales_channel",
    "payment_method",
    "ticket_price",
    "currency",
    "ticket_price_usd_est",
    "bags_total",
    "bags_checked",
}

MESES = (
    "ENERO", "FEBRERO", "MARZO", "ABRIL", "MAYO", "JUNIO",
    "JULIO", "AGOSTO", "SEPTIEMBRE", "OCTUBRE", "NOVIEMBRE", "DICIEMBRE",
)
DIAS = ("LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO", "DOMINGO")


def _cargar_archivo_env() -> None:
    """Carga .env cuando python-dotenv esta instalado; no es obligatorio."""
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    load_dotenv(RAIZ_PROYECTO / ".env")


def _importar_pyodbc():
    try:
        import pyodbc
    except ImportError as error:
        raise RuntimeError(
            "Falta pyodbc. Instale las dependencias con: "
            "py -m pip install -r requirements.txt"
        ) from error
    return pyodbc


def _seleccionar_driver(pyodbc: Any) -> str:
    configurado = os.getenv("SQLSERVER_DRIVER")
    if configurado:
        return configurado.strip("{}")

    disponibles = set(pyodbc.drivers())
    for candidato in (
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "SQL Server",
    ):
        if candidato in disponibles:
            return candidato

    raise RuntimeError(
        "No se encontro un controlador ODBC para SQL Server. "
        "Instale Microsoft ODBC Driver 18 o configure SQLSERVER_DRIVER."
    )


def _reemplazar_base_datos(cadena: str, base_datos: str) -> str:
    patron = re.compile(r"(?i)(Database|Initial Catalog)\s*=\s*[^;]*")
    if patron.search(cadena):
        return patron.sub(f"Database={base_datos}", cadena)
    return cadena.rstrip(";") + f";Database={base_datos};"


def obtener_cadena_conexion(base_datos: str | None = None) -> str:
    """Construye la conexion desde variables de entorno sin exponer secretos."""
    _cargar_archivo_env()
    base = base_datos or os.getenv("SQLSERVER_DATABASE", "VuelosDW")
    configurada = os.getenv("SQLSERVER_CONNECTION_STRING")
    if configurada:
        return _reemplazar_base_datos(configurada, base)

    pyodbc = _importar_pyodbc()
    driver = _seleccionar_driver(pyodbc)
    servidor = os.getenv("SQLSERVER_SERVER", "localhost")
    usuario = os.getenv("SQLSERVER_USER")
    clave = os.getenv("SQLSERVER_PASSWORD")
    cifrado = os.getenv("SQLSERVER_ENCRYPT", "yes")
    confiar = os.getenv("SQLSERVER_TRUST_CERT", "yes")

    partes = [
        f"DRIVER={{{driver}}}",
        f"SERVER={servidor}",
        f"DATABASE={base}",
        f"Encrypt={cifrado}",
        f"TrustServerCertificate={confiar}",
    ]
    if usuario and clave:
        partes.extend((f"UID={usuario}", f"PWD={clave}"))
    elif usuario or clave:
        raise ValueError("SQLSERVER_USER y SQLSERVER_PASSWORD deben definirse juntos.")
    else:
        partes.append("Trusted_Connection=yes")
    return ";".join(partes) + ";"


def abrir_conexion(base_datos: str | None = None, autocommit: bool = False):
    pyodbc = _importar_pyodbc()
    timeout = int(os.getenv("SQLSERVER_TIMEOUT", "30"))
    return pyodbc.connect(
        obtener_cadena_conexion(base_datos),
        autocommit=autocommit,
        timeout=timeout,
    )


def ejecutar_script_creacion(ruta_sql: Path = RUTA_SQL_PREDETERMINADA) -> None:
    """Ejecuta create_database.sql, separando los lotes delimitados por GO."""
    contenido = ruta_sql.read_text(encoding="utf-8")
    lotes = re.split(r"(?im)^\s*GO\s*;?\s*$", contenido)
    with abrir_conexion("master", autocommit=True) as conexion:
        cursor = conexion.cursor()
        for lote in lotes:
            if lote.strip():
                cursor.execute(lote)


def _texto(valor: Any, desconocido: str = "UNKNOWN") -> str:
    if pd.isna(valor):
        return desconocido
    texto = str(valor).strip()
    return texto if texto else desconocido


def _texto_clave(valor: Any, desconocido: str = "UNKNOWN") -> str:
    """Canoniza claves naturales para la intercalacion CI de SQL Server."""
    return _texto(valor, desconocido).upper()


def _entero_o_none(valor: Any) -> int | None:
    return None if pd.isna(valor) else int(valor)


def _numero_o_none(valor: Any) -> float | None:
    return None if pd.isna(valor) else float(valor)


def _datetime_o_none(valor: Any) -> datetime | None:
    if pd.isna(valor):
        return None
    if isinstance(valor, pd.Timestamp):
        return valor.to_pydatetime()
    return valor


def preparar_dataframe_carga(df: pd.DataFrame) -> pd.DataFrame:
    """Valida tipos y agrega campos tecnicos usados por el modelo."""
    faltantes = sorted(COLUMNAS_REQUERIDAS.difference(df.columns))
    if faltantes:
        raise ValueError(f"Faltan columnas requeridas: {', '.join(faltantes)}")

    datos = df.copy()
    datos["record_id"] = pd.to_numeric(datos["record_id"], errors="coerce")
    if datos["record_id"].isna().any():
        raise ValueError("record_id contiene valores nulos o no numericos.")
    if datos["record_id"].duplicated().any():
        raise ValueError("record_id debe ser unico para realizar una carga idempotente.")
    datos["record_id"] = datos["record_id"].astype("int64")

    for columna in ("departure_datetime", "arrival_datetime", "booking_datetime"):
        datos[columna] = pd.to_datetime(datos[columna], errors="coerce")

    for columna in (
        "duration_min", "delay_min", "passenger_age", "ticket_price",
        "ticket_price_usd_est", "bags_total", "bags_checked",
    ):
        datos[columna] = pd.to_numeric(datos[columna], errors="coerce")

    datos["fecha_referencia_pasajero"] = (
        datos["booking_datetime"]
        .fillna(datos["departure_datetime"])
        .fillna(pd.Timestamp("1900-01-01"))
    )
    salida_texto = datos["departure_datetime"].dt.strftime("%Y%m%dT%H%M%S").fillna("UNKNOWN")
    datos["ocurrencia_vuelo_id"] = (
        datos["airline_code"].map(_texto_clave)
        + "|" + datos["flight_number"].map(_texto_clave)
        + "|" + salida_texto
    ).str.slice(0, 100)
    return datos


def _activar_carga_rapida(cursor: Any) -> None:
    try:
        cursor.fast_executemany = True
    except AttributeError:
        pass


def _desactivar_carga_rapida(cursor: Any) -> None:
    """Las tablas temporales locales no son compatibles con todos los metodos de metadatos ODBC."""
    try:
        cursor.fast_executemany = False
    except AttributeError:
        pass


def _cargar_fechas(cursor: Any, datos: pd.DataFrame) -> dict[Any, int]:
    fechas = set()
    for columna in ("departure_datetime", "arrival_datetime", "booking_datetime"):
        fechas.update(valor.date() for valor in datos[columna].dropna())

    existentes = {fila[0] for fila in cursor.execute("SELECT FechaKey FROM dbo.DimFecha")}
    nuevas = []
    for fecha in sorted(fechas):
        clave = fecha.year * 10000 + fecha.month * 100 + fecha.day
        if clave not in existentes:
            nuevas.append((
                clave, fecha, fecha.day, fecha.month, MESES[fecha.month - 1],
                (fecha.month - 1) // 3 + 1, fecha.year, fecha.isoweekday(),
                DIAS[fecha.weekday()], int(fecha.weekday() >= 5),
            ))
    if nuevas:
        _activar_carga_rapida(cursor)
        cursor.executemany(
            """INSERT INTO dbo.DimFecha
               (FechaKey, Fecha, Dia, Mes, NombreMes, Trimestre, Anio,
                DiaSemana, NombreDia, EsFinDeSemana)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            nuevas,
        )
    return {fila[1]: fila[0] for fila in cursor.execute("SELECT FechaKey, Fecha FROM dbo.DimFecha")}


def _cargar_aerolineas(cursor: Any, datos: pd.DataFrame) -> dict[str, int]:
    fuente = {}
    for fila in datos[["airline_code", "airline_name"]].itertuples(index=False):
        fuente[_texto_clave(fila.airline_code)] = _texto(fila.airline_name, "DESCONOCIDA")

    existentes = {
        fila[1]: (fila[0], fila[2])
        for fila in cursor.execute("SELECT AerolineaKey, Codigo, Nombre FROM dbo.DimAerolinea")
    }
    insertar = [(codigo, nombre) for codigo, nombre in fuente.items() if codigo not in existentes]
    actualizar = [
        (nombre, codigo)
        for codigo, nombre in fuente.items()
        if codigo in existentes and existentes[codigo][1] != nombre
    ]
    if insertar:
        cursor.executemany("INSERT INTO dbo.DimAerolinea (Codigo, Nombre) VALUES (?, ?)", insertar)
    if actualizar:
        cursor.executemany("UPDATE dbo.DimAerolinea SET Nombre = ? WHERE Codigo = ?", actualizar)
    return {fila[1]: fila[0] for fila in cursor.execute("SELECT AerolineaKey, Codigo FROM dbo.DimAerolinea")}


def _cargar_dimension_simple(
    cursor: Any,
    tabla: str,
    columna_key: str,
    columnas: tuple[str, ...],
    valores: set[tuple[Any, ...]],
) -> dict[tuple[Any, ...], int]:
    columnas_sql = ", ".join(columnas)
    consulta = f"SELECT {columna_key}, {columnas_sql} FROM dbo.{tabla}"
    existentes = {tuple(fila[1:]): fila[0] for fila in cursor.execute(consulta)}
    nuevos = sorted(valores.difference(existentes))
    if nuevos:
        marcas = ", ".join("?" for _ in columnas)
        cursor.executemany(
            f"INSERT INTO dbo.{tabla} ({columnas_sql}) VALUES ({marcas})",
            nuevos,
        )
    return {tuple(fila[1:]): fila[0] for fila in cursor.execute(consulta)}


def _atributos_pasajero(fila: Any) -> tuple[str, int | None, str]:
    return (
        _texto_clave(fila.passenger_gender),
        _entero_o_none(fila.passenger_age),
        _texto_clave(fila.passenger_nationality),
    )


def _leer_versiones_pasajero(cursor: Any, pasajero_id: str) -> list[tuple[Any, ...]]:
    return list(cursor.execute(
        """SELECT PasajeroKey, Genero, Edad, Nacionalidad, FechaInicio, FechaFin, EsActual
           FROM dbo.DimPasajero
           WHERE PasajeroID = ?
           ORDER BY FechaInicio""",
        pasajero_id,
    ))


def _aplicar_observacion_scd2(
    cursor: Any,
    pasajero_id: str,
    atributos: tuple[str, int | None, str],
    fecha_referencia: datetime,
) -> None:
    versiones = _leer_versiones_pasajero(cursor, pasajero_id)
    for version in versiones:
        key, genero, edad, nacionalidad, inicio, fin, es_actual = version
        if inicio <= fecha_referencia < fin:
            if (genero, edad, nacionalidad) == atributos:
                return
            if fecha_referencia == inicio:
                cursor.execute(
                    """UPDATE dbo.DimPasajero
                       SET Genero = ?, Edad = ?, Nacionalidad = ?
                       WHERE PasajeroKey = ?""",
                    *atributos, key,
                )
                return
            cursor.execute(
                """UPDATE dbo.DimPasajero
                   SET FechaFin = ?, EsActual = 0
                   WHERE PasajeroKey = ?""",
                fecha_referencia, key,
            )
            cursor.execute(
                """INSERT INTO dbo.DimPasajero
                   (PasajeroID, Genero, Edad, Nacionalidad, FechaInicio, FechaFin, EsActual)
                   VALUES (?, ?, ?, ?, ?, ?, ?)""",
                pasajero_id, *atributos, fecha_referencia, fin, es_actual,
            )
            return

    siguiente = next((v for v in versiones if v[4] > fecha_referencia), None)
    fecha_fin = siguiente[4] if siguiente else FECHA_MAXIMA
    es_actual = int(siguiente is None)
    if es_actual:
        cursor.execute(
            "UPDATE dbo.DimPasajero SET EsActual = 0 WHERE PasajeroID = ? AND EsActual = 1",
            pasajero_id,
        )
    cursor.execute(
        """INSERT INTO dbo.DimPasajero
           (PasajeroID, Genero, Edad, Nacionalidad, FechaInicio, FechaFin, EsActual)
           VALUES (?, ?, ?, ?, ?, ?, ?)""",
        pasajero_id, *atributos, fecha_referencia, fecha_fin, es_actual,
    )


def _cargar_pasajeros(cursor: Any, datos: pd.DataFrame) -> dict[str, list[tuple[Any, ...]]]:
    existentes = {
        fila[0]
        for fila in cursor.execute("SELECT DISTINCT PasajeroID FROM dbo.DimPasajero")
    }
    observaciones = datos.sort_values("fecha_referencia_pasajero", kind="stable")
    nuevos = []

    for pasajero_id_valor, grupo in observaciones.groupby("passenger_id", sort=False, dropna=False):
        pasajero_id = _texto_clave(pasajero_id_valor)
        if pasajero_id == "UNKNOWN":
            continue

        por_fecha = {}
        for fila in grupo.itertuples(index=False):
            fecha = _datetime_o_none(fila.fecha_referencia_pasajero)
            por_fecha[fecha] = _atributos_pasajero(fila)
        secuencia = sorted(por_fecha.items())

        if pasajero_id not in existentes:
            cambios = []
            for fecha, atributos in secuencia:
                if not cambios or cambios[-1][1] != atributos:
                    cambios.append((fecha, atributos))
            for indice, (inicio, atributos) in enumerate(cambios):
                fin = cambios[indice + 1][0] if indice + 1 < len(cambios) else FECHA_MAXIMA
                nuevos.append((
                    pasajero_id, *atributos, inicio, fin,
                    int(indice == len(cambios) - 1),
                ))
        else:
            for fecha, atributos in secuencia:
                _aplicar_observacion_scd2(cursor, pasajero_id, atributos, fecha)

    if nuevos:
        _activar_carga_rapida(cursor)
        cursor.executemany(
            """INSERT INTO dbo.DimPasajero
               (PasajeroID, Genero, Edad, Nacionalidad, FechaInicio, FechaFin, EsActual)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            nuevos,
        )

    versiones: dict[str, list[tuple[Any, ...]]] = {}
    for fila in cursor.execute(
        """SELECT PasajeroKey, PasajeroID, Genero, Edad, Nacionalidad, FechaInicio, FechaFin
           FROM dbo.DimPasajero ORDER BY PasajeroID, FechaInicio"""
    ):
        versiones.setdefault(fila[1], []).append((fila[0], fila[2], fila[3], fila[4], fila[5], fila[6]))
    return versiones


def _resolver_pasajero_key(
    versiones: dict[str, list[tuple[Any, ...]]],
    pasajero_id: str,
    atributos: tuple[str, int | None, str],
    fecha: datetime,
) -> int:
    if pasajero_id == "UNKNOWN":
        return 0
    candidatas = versiones.get(pasajero_id, ())
    for key, genero, edad, nacionalidad, inicio, fin in candidatas:
        if inicio <= fecha < fin and (genero, edad, nacionalidad) == atributos:
            return int(key)
    for key, _, _, _, inicio, fin in candidatas:
        if inicio <= fecha < fin:
            return int(key)
    raise RuntimeError(f"No se encontro version SCD2 para el pasajero {pasajero_id}.")


def _fecha_key(valor: Any) -> int:
    if pd.isna(valor):
        return 0
    return valor.year * 10000 + valor.month * 100 + valor.day


def _cargar_dimensiones(cursor: Any, datos: pd.DataFrame) -> dict[str, Any]:
    mapas: dict[str, Any] = {}
    mapas["fecha"] = _cargar_fechas(cursor, datos)
    mapas["aerolinea"] = _cargar_aerolineas(cursor, datos)

    aeropuertos = {
        (_texto_clave(valor),)
        for columna in ("origin_airport", "destination_airport")
        for valor in datos[columna]
    }
    mapas["aeropuerto"] = _cargar_dimension_simple(
        cursor, "DimAeropuerto", "AeropuertoKey", ("Codigo",), aeropuertos,
    )
    vuelos = {
        (_texto_clave(fila.flight_number), _texto_clave(fila.aircraft_type))
        for fila in datos[["flight_number", "aircraft_type"]].itertuples(index=False)
    }
    mapas["vuelo"] = _cargar_dimension_simple(
        cursor, "DimVuelo", "VueloKey", ("NumeroVuelo", "TipoAeronave"), vuelos,
    )
    estados = {(_texto_clave(valor),) for valor in datos["status"]}
    mapas["estado"] = _cargar_dimension_simple(
        cursor, "DimEstadoVuelo", "EstadoVueloKey", ("Estado",), estados,
    )
    detalles = {
        (
            _texto_clave(fila.sales_channel), _texto_clave(fila.payment_method),
            _texto_clave(fila.currency), _texto_clave(fila.cabin_class),
        )
        for fila in datos[["sales_channel", "payment_method", "currency", "cabin_class"]].itertuples(index=False)
    }
    mapas["detalle"] = _cargar_dimension_simple(
        cursor,
        "DimDetalleVenta",
        "DetalleVentaKey",
        ("CanalVenta", "MetodoPago", "Moneda", "ClaseCabina"),
        detalles,
    )
    mapas["pasajero"] = _cargar_pasajeros(cursor, datos)
    return mapas


def _crear_filas_hecho(datos: pd.DataFrame, mapas: dict[str, Any]) -> list[tuple[Any, ...]]:
    filas = []
    for fila in datos.itertuples(index=False):
        pasajero_id = _texto_clave(fila.passenger_id)
        atributos = _atributos_pasajero(fila)
        fecha_ref = _datetime_o_none(fila.fecha_referencia_pasajero)
        filas.append((
            int(fila.record_id),
            fila.ocurrencia_vuelo_id,
            mapas["aerolinea"].get(_texto_clave(fila.airline_code), 0),
            mapas["vuelo"].get((_texto_clave(fila.flight_number), _texto_clave(fila.aircraft_type)), 0),
            mapas["aeropuerto"].get((_texto_clave(fila.origin_airport),), 0),
            mapas["aeropuerto"].get((_texto_clave(fila.destination_airport),), 0),
            _resolver_pasajero_key(mapas["pasajero"], pasajero_id, atributos, fecha_ref),
            _fecha_key(fila.departure_datetime),
            _fecha_key(fila.arrival_datetime),
            _fecha_key(fila.booking_datetime),
            mapas["estado"].get((_texto_clave(fila.status),), 0),
            mapas["detalle"].get((
                _texto_clave(fila.sales_channel), _texto_clave(fila.payment_method),
                _texto_clave(fila.currency), _texto_clave(fila.cabin_class),
            ), 0),
            _datetime_o_none(fila.departure_datetime),
            _datetime_o_none(fila.arrival_datetime),
            _datetime_o_none(fila.booking_datetime),
            None if pd.isna(fila.seat) else str(fila.seat),
            _entero_o_none(fila.duration_min),
            _entero_o_none(fila.delay_min),
            _numero_o_none(fila.ticket_price),
            _numero_o_none(fila.ticket_price_usd_est),
            _entero_o_none(fila.bags_total) or 0,
            _entero_o_none(fila.bags_checked) or 0,
            1,
        ))
    return filas


def _cargar_hechos(cursor: Any, filas: list[tuple[Any, ...]]) -> dict[str, int]:
    cursor.execute(
        """CREATE TABLE #CargaFactVuelo
        (
            RecordID BIGINT NOT NULL PRIMARY KEY,
            OcurrenciaVueloID VARCHAR(100) NOT NULL,
            AerolineaKey INT NOT NULL,
            VueloKey INT NOT NULL,
            AeropuertoOrigenKey INT NOT NULL,
            AeropuertoDestinoKey INT NOT NULL,
            PasajeroKey BIGINT NOT NULL,
            FechaSalidaKey INT NOT NULL,
            FechaLlegadaKey INT NOT NULL,
            FechaReservaKey INT NOT NULL,
            EstadoVueloKey INT NOT NULL,
            DetalleVentaKey INT NOT NULL,
            FechaHoraSalida DATETIME2(0) NULL,
            FechaHoraLlegada DATETIME2(0) NULL,
            FechaHoraReserva DATETIME2(0) NULL,
            Asiento VARCHAR(10) NULL,
            DuracionMinutos SMALLINT NULL,
            RetrasoMinutos SMALLINT NULL,
            PrecioTicketOriginal DECIMAL(12,2) NULL,
            PrecioTicketUSD DECIMAL(12,2) NULL,
            MaletasTotales SMALLINT NOT NULL,
            MaletasFacturadas SMALLINT NOT NULL,
            CantidadTickets SMALLINT NOT NULL
        );"""
    )
    # Evita el problema de metadatos de fast_executemany con tablas #temporales.
    _desactivar_carga_rapida(cursor)
    cursor.executemany(
        "INSERT INTO #CargaFactVuelo VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        filas,
    )
    existentes = cursor.execute(
        """SELECT COUNT(*) FROM dbo.FactVuelo AS f
           INNER JOIN #CargaFactVuelo AS c ON c.RecordID = f.RecordID"""
    ).fetchone()[0]

    cursor.execute(
        """UPDATE destino
           SET OcurrenciaVueloID = origen.OcurrenciaVueloID,
               AerolineaKey = origen.AerolineaKey,
               VueloKey = origen.VueloKey,
               AeropuertoOrigenKey = origen.AeropuertoOrigenKey,
               AeropuertoDestinoKey = origen.AeropuertoDestinoKey,
               PasajeroKey = origen.PasajeroKey,
               FechaSalidaKey = origen.FechaSalidaKey,
               FechaLlegadaKey = origen.FechaLlegadaKey,
               FechaReservaKey = origen.FechaReservaKey,
               EstadoVueloKey = origen.EstadoVueloKey,
               DetalleVentaKey = origen.DetalleVentaKey,
               FechaHoraSalida = origen.FechaHoraSalida,
               FechaHoraLlegada = origen.FechaHoraLlegada,
               FechaHoraReserva = origen.FechaHoraReserva,
               Asiento = origen.Asiento,
               DuracionMinutos = origen.DuracionMinutos,
               RetrasoMinutos = origen.RetrasoMinutos,
               PrecioTicketOriginal = origen.PrecioTicketOriginal,
               PrecioTicketUSD = origen.PrecioTicketUSD,
               MaletasTotales = origen.MaletasTotales,
               MaletasFacturadas = origen.MaletasFacturadas,
               CantidadTickets = origen.CantidadTickets,
               FechaCarga = SYSUTCDATETIME()
           FROM dbo.FactVuelo AS destino
           INNER JOIN #CargaFactVuelo AS origen ON origen.RecordID = destino.RecordID;"""
    )
    cursor.execute(
        """INSERT INTO dbo.FactVuelo
           (RecordID, OcurrenciaVueloID, AerolineaKey, VueloKey,
            AeropuertoOrigenKey, AeropuertoDestinoKey, PasajeroKey,
            FechaSalidaKey, FechaLlegadaKey, FechaReservaKey, EstadoVueloKey,
            DetalleVentaKey, FechaHoraSalida, FechaHoraLlegada, FechaHoraReserva,
            Asiento, DuracionMinutos, RetrasoMinutos, PrecioTicketOriginal,
            PrecioTicketUSD, MaletasTotales, MaletasFacturadas, CantidadTickets)
           SELECT c.RecordID, c.OcurrenciaVueloID, c.AerolineaKey, c.VueloKey,
                  c.AeropuertoOrigenKey, c.AeropuertoDestinoKey, c.PasajeroKey,
                  c.FechaSalidaKey, c.FechaLlegadaKey, c.FechaReservaKey,
                  c.EstadoVueloKey, c.DetalleVentaKey, c.FechaHoraSalida,
                  c.FechaHoraLlegada, c.FechaHoraReserva, c.Asiento,
                  c.DuracionMinutos, c.RetrasoMinutos, c.PrecioTicketOriginal,
                  c.PrecioTicketUSD, c.MaletasTotales, c.MaletasFacturadas,
                  c.CantidadTickets
           FROM #CargaFactVuelo AS c
           WHERE NOT EXISTS
               (SELECT 1 FROM dbo.FactVuelo AS f WHERE f.RecordID = c.RecordID);"""
    )
    verificados = cursor.execute(
        """SELECT COUNT(*) FROM dbo.FactVuelo AS f
           INNER JOIN #CargaFactVuelo AS c ON c.RecordID = f.RecordID"""
    ).fetchone()[0]
    if verificados != len(filas):
        raise RuntimeError(
            f"Validacion de carga fallida: se esperaban {len(filas)} hechos "
            f"y se encontraron {verificados}."
        )
    return {
        "procesados": len(filas),
        "insertados": len(filas) - int(existentes),
        "actualizados": int(existentes),
        "verificados": int(verificados),
    }


def cargar_dataframe(df: pd.DataFrame) -> dict[str, int]:
    """Carga un DataFrame transformado; hace rollback completo ante cualquier error."""
    datos = preparar_dataframe_carga(df)
    if datos.empty:
        return {"procesados": 0, "insertados": 0, "actualizados": 0, "verificados": 0}

    conexion = abrir_conexion()
    try:
        cursor = conexion.cursor()
        mapas = _cargar_dimensiones(cursor, datos)
        filas = _crear_filas_hecho(datos, mapas)
        resultado = _cargar_hechos(cursor, filas)
        conexion.commit()
        return resultado
    except Exception:
        conexion.rollback()
        raise
    finally:
        conexion.close()


def cargar_archivo(ruta_csv: Path = RUTA_CSV_PREDETERMINADA) -> dict[str, int]:
    return cargar_dataframe(pd.read_csv(ruta_csv))


def crear_argumentos() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Carga el dataset limpio en SQL Server.")
    parser.add_argument("--archivo", type=Path, default=RUTA_CSV_PREDETERMINADA)
    parser.add_argument(
        "--crear-esquema",
        action="store_true",
        help="Ejecuta sql/create_database.sql antes de cargar.",
    )
    parser.add_argument("--script-sql", type=Path, default=RUTA_SQL_PREDETERMINADA)
    return parser


def main() -> None:
    args = crear_argumentos().parse_args()
    if args.crear_esquema:
        print(f"Creando o verificando el modelo con {args.script_sql}...")
        ejecutar_script_creacion(args.script_sql)
    print(f"Cargando {args.archivo} en SQL Server...")
    resultado = cargar_archivo(args.archivo)
    print(
        "Carga completada: "
        f"{resultado['procesados']} procesados, "
        f"{resultado['insertados']} insertados y "
        f"{resultado['actualizados']} actualizados; "
        f"{resultado['verificados']} verificados."
    )


if __name__ == "__main__":
    main()
