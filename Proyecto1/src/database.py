import logging
import time
from pathlib import Path

import psycopg
from psycopg import Connection
from psycopg.errors import OperationalError

from .config import CONNECT_ATTEMPTS, CONNECT_DELAY_SECONDS, DatabaseConfig


LOGGER = logging.getLogger(__name__)


def connect_with_retry(config: DatabaseConfig, label: str) -> Connection:
    last_error: Exception | None = None

    for attempt in range(1, CONNECT_ATTEMPTS + 1):
        try:
            connection = psycopg.connect(**config.connection_kwargs())
            LOGGER.info(
                "Conexión exitosa a %s (%s:%s/%s)",
                label,
                config.host,
                config.port,
                config.dbname,
            )
            return connection
        except OperationalError as error:
            last_error = error
            LOGGER.warning(
                "No fue posible conectar a %s (intento %s/%s)",
                label,
                attempt,
                CONNECT_ATTEMPTS,
            )
            if attempt < CONNECT_ATTEMPTS:
                time.sleep(CONNECT_DELAY_SECONDS)

    raise ConnectionError(f"No se pudo conectar a {label}") from last_error


def execute_sql_file(connection: Connection, path: Path) -> None:
    if not path.is_file():
        raise FileNotFoundError(f"No existe el archivo SQL: {path}")

    statements = [statement.strip() for statement in path.read_text(encoding="utf-8").split(";")]
    with connection.cursor() as cursor:
        for statement in statements:
            if statement:
                cursor.execute(statement)

