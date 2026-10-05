import argparse
import logging
import sys
from pathlib import Path

from .config import LOG_FILE, LOG_LEVEL
from .pipeline import inspect_quality_cases, load_csv, load_oltp, run_all, validate_raw


def configure_logging() -> None:
    handlers: list[logging.Handler] = [logging.StreamHandler(sys.stdout)]
    if LOG_FILE:
        log_path = Path(LOG_FILE)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(log_path, encoding="utf-8"))

    logging.basicConfig(
        level=getattr(logging, LOG_LEVEL, logging.INFO),
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
        handlers=handlers,
        force=True,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Carga raw de SG-Food")
    parser.add_argument(
        "command",
        choices=("load-oltp", "load-csv", "validate", "quality-cases", "run-all"),
        nargs="?",
        default="run-all",
    )
    return parser


def main() -> int:
    configure_logging()
    logger = logging.getLogger(__name__)
    command = build_parser().parse_args().command

    try:
        if command == "load-oltp":
            load_oltp()
        elif command == "load-csv":
            load_csv()
        elif command == "validate":
            validate_raw()
        elif command == "quality-cases":
            inspect_quality_cases()
        else:
            run_all()
        logger.info("Comando %s finalizado correctamente", command)
        return 0
    except Exception:
        logger.exception("Comando %s finalizado con error", command)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

