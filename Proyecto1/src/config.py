import os
from dataclasses import dataclass
from pathlib import Path

from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).resolve().parents[1]
load_dotenv(PROJECT_ROOT / ".env")


@dataclass(frozen=True)
class DatabaseConfig:
    host: str
    port: int
    dbname: str
    user: str
    password: str

    @classmethod
    def from_env(cls, prefix: str, defaults: dict[str, str]) -> "DatabaseConfig":
        return cls(
            host=os.getenv(f"{prefix}_DB_HOST", defaults["host"]),
            port=int(os.getenv(f"{prefix}_DB_PORT", defaults["port"])),
            dbname=os.getenv(f"{prefix}_DB_NAME", defaults["dbname"]),
            user=os.getenv(f"{prefix}_DB_USER", defaults["user"]),
            password=os.getenv(f"{prefix}_DB_PASSWORD", defaults["password"]),
        )

    def connection_kwargs(self) -> dict[str, str | int]:
        return {
            "host": self.host,
            "port": self.port,
            "dbname": self.dbname,
            "user": self.user,
            "password": self.password,
            "connect_timeout": 5,
        }


SOURCE_DB = DatabaseConfig.from_env(
    "SOURCE",
    {
        "host": "localhost",
        "port": "5433",
        "dbname": "sgfood_source",
        "user": "sgfood",
        "password": "sgfood_source_2026",
    },
)

TARGET_DB = DatabaseConfig.from_env(
    "TARGET",
    {
        "host": "localhost",
        "port": "5434",
        "dbname": "sgfood_dw",
        "user": "sgfood",
        "password": "sgfood_dw_2026",
    },
)


def resolve_project_path(variable: str, default: str) -> Path:
    configured = Path(os.getenv(variable, default))
    return configured if configured.is_absolute() else PROJECT_ROOT / configured


CSV_DIR = resolve_project_path("CSV_DIR", "data/csv")
QUALITY_DIR = resolve_project_path("QUALITY_DIR", "data/quality")
RAW_DDL_PATH = resolve_project_path("RAW_DDL_PATH", "sql/create_raw.sql")
CONNECT_ATTEMPTS = int(os.getenv("DB_CONNECT_ATTEMPTS", "10"))
CONNECT_DELAY_SECONDS = float(os.getenv("DB_CONNECT_DELAY_SECONDS", "2"))
EXTRACT_BATCH_SIZE = int(os.getenv("EXTRACT_BATCH_SIZE", "1000"))
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
LOG_FILE = os.getenv("LOG_FILE", "").strip()

