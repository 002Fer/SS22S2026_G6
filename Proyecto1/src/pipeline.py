import csv
import logging
from datetime import datetime, timezone
from pathlib import Path
from uuid import UUID, uuid4

from psycopg import Connection, sql

from .config import CSV_DIR, EXTRACT_BATCH_SIZE, QUALITY_DIR, RAW_DDL_PATH, SOURCE_DB, TARGET_DB
from .database import connect_with_retry, execute_sql_file
from .sources import (
    CSV_SOURCES,
    OLTP_SOURCES,
    CsvSource,
    OltpSource,
    parse_csv_rows,
    require_source_file,
)


LOGGER = logging.getLogger(__name__)
METADATA_COLUMNS = ("_loaded_at", "_source", "_batch_id")


def initialize_raw_schema(connection: Connection) -> None:
    execute_sql_file(connection, RAW_DDL_PATH)
    connection.commit()
    LOGGER.info("Schema raw y tablas disponibles")


def truncate_raw_tables(connection: Connection, table_names: list[str]) -> None:
    identifiers = [sql.Identifier("raw", table) for table in table_names]
    statement = sql.SQL("TRUNCATE TABLE {} ").format(sql.SQL(", ").join(identifiers))
    connection.execute(statement)


def copy_statement(table: str, columns: tuple[str, ...]) -> sql.Composed:
    all_columns = columns + METADATA_COLUMNS
    return sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier("raw", table),
        sql.SQL(", ").join(map(sql.Identifier, all_columns)),
    )


def load_oltp_table(
    source_connection: Connection,
    target_connection: Connection,
    source: OltpSource,
    batch_id: UUID,
    loaded_at: datetime,
) -> int:
    select_query = sql.SQL("SELECT {} FROM {} ORDER BY 1").format(
        sql.SQL(", ").join(map(sql.Identifier, source.columns)),
        sql.Identifier("oltp_sgfood", source.table),
    )

    count = 0
    with source_connection.cursor() as source_cursor, target_connection.cursor() as target_cursor:
        source_cursor.execute(select_query)
        with target_cursor.copy(copy_statement(source.table, source.columns)) as copy:
            while True:
                rows = source_cursor.fetchmany(EXTRACT_BATCH_SIZE)
                if not rows:
                    break
                for row in rows:
                    copy.write_row((*row, loaded_at, "postgresql_oltp", batch_id))
                count += len(rows)

    LOGGER.info("raw.%s: %s registros cargados", source.table, count)
    return count



def load_csv_table(
    target_connection: Connection,
    source: CsvSource,
    batch_id: UUID,
    loaded_at: datetime,
) -> int:
    path = require_source_file(CSV_DIR, source.filename)
    count = 0

    with target_connection.cursor() as cursor:
        with cursor.copy(copy_statement(source.table, source.columns)) as copy:
            for row in parse_csv_rows(source, path):
                copy.write_row((*row, loaded_at, f"csv:{source.filename}", batch_id))
                count += 1

    if count != source.expected_rows:
        raise ValueError(
            f"Cantidad inesperada en {source.filename}: esperada={source.expected_rows}, obtenida={count}"
        )

    LOGGER.info("raw.%s: %s registros cargados", source.table, count)
    return count


def load_oltp() -> dict[str, int]:
    batch_id = uuid4()
    loaded_at = datetime.now(timezone.utc)
    counts: dict[str, int] = {}

    source_connection = connect_with_retry(SOURCE_DB, "PostgreSQL transaccional")
    target_connection = connect_with_retry(TARGET_DB, "PostgreSQL Data Warehouse")

    try:
        initialize_raw_schema(target_connection)
        truncate_raw_tables(target_connection, [source.table for source in OLTP_SOURCES])
        for source in OLTP_SOURCES:
            counts[source.table] = load_oltp_table(
                source_connection,
                target_connection,
                source,
                batch_id,
                loaded_at,
            )
        target_connection.commit()
        LOGGER.info("Carga OLTP confirmada. batch_id=%s", batch_id)
        return counts
    except Exception:
        target_connection.rollback()
        LOGGER.exception("La carga OLTP falló y fue revertida")
        raise
    finally:
        source_connection.close()
        target_connection.close()


def load_csv() -> dict[str, int]:
    batch_id = uuid4()
    loaded_at = datetime.now(timezone.utc)
    counts: dict[str, int] = {}
    target_connection = connect_with_retry(TARGET_DB, "PostgreSQL Data Warehouse")

    try:
        initialize_raw_schema(target_connection)
        truncate_raw_tables(target_connection, [source.table for source in CSV_SOURCES])
        for source in CSV_SOURCES:
            counts[source.table] = load_csv_table(target_connection, source, batch_id, loaded_at)
        target_connection.commit()
        LOGGER.info("Carga CSV confirmada. batch_id=%s", batch_id)
        return counts
    except Exception:
        target_connection.rollback()
        LOGGER.exception("La carga CSV falló y fue revertida")
        raise
    finally:
        target_connection.close()


def source_counts(connection: Connection) -> dict[str, int]:
    counts = {}
    for source in OLTP_SOURCES:
        query = sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier("oltp_sgfood", source.table))
        counts[source.table] = connection.execute(query).fetchone()[0]
    return counts


def target_counts(connection: Connection) -> dict[str, int]:
    counts = {}
    for table in [source.table for source in OLTP_SOURCES] + [source.table for source in CSV_SOURCES]:
        query = sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier("raw", table))
        counts[table] = connection.execute(query).fetchone()[0]
    return counts


def validate_raw() -> dict[str, int]:
    source_connection = connect_with_retry(SOURCE_DB, "PostgreSQL transaccional")
    target_connection = connect_with_retry(TARGET_DB, "PostgreSQL Data Warehouse")

    try:
        initialize_raw_schema(target_connection)
        expected = source_counts(source_connection)
        expected.update({source.table: source.expected_rows for source in CSV_SOURCES})
        actual = target_counts(target_connection)

        differences = {
            table: (expected[table], actual.get(table, 0))
            for table in expected
            if expected[table] != actual.get(table, 0)
        }
        if differences:
            raise ValueError(f"Los conteos raw no coinciden: {differences}")

        for table, count in actual.items():
            LOGGER.info("Validación raw.%s: %s registros", table, count)
        LOGGER.info("Validación completada: %s tablas correctas", len(actual))
        return actual
    finally:
        source_connection.close()
        target_connection.close()


def inspect_quality_cases() -> int:
    path = require_source_file(QUALITY_DIR, "casos_calidad_opcionales.csv")
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    LOGGER.info("Casos de calidad disponibles: %s. No se cargaron a raw.", len(rows))
    return len(rows)


def run_all() -> dict[str, int]:
    load_oltp()
    load_csv()
    inspect_quality_cases()
    return validate_raw()

