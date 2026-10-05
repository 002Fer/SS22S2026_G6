import csv
from datetime import date
from decimal import Decimal
import unittest
from pathlib import Path

from src.sources import (
    CSV_SOURCES,
    OLTP_SOURCES,
    CsvSource,
    parse_csv_rows,
    parse_date,
    parse_decimal,
    parse_integer,
    parse_text,
    require_source_file,
)


PROJECT_ROOT = Path(__file__).resolve().parents[1]


class ConvertersTests(unittest.TestCase):
    def test_parse_text(self):
        self.assertEqual("hola mundo", parse_text("  hola mundo  "))

    def test_parse_integer(self):
        self.assertEqual(123, parse_integer(" 123 "))
        with self.assertRaises(ValueError):
            parse_integer("abc")

    def test_parse_decimal(self):
        self.assertEqual(Decimal("45.67"), parse_decimal(" 45.67 "))
        with self.assertRaises(ValueError):
            parse_decimal("invalido")

    def test_parse_date(self):
        self.assertEqual(date(2026, 8, 31), parse_date("2026-08-31"))
        with self.assertRaises(ValueError):
            parse_date("31/08/2026")


class CsvSourceTests(unittest.TestCase):
    def test_main_csv_files_have_expected_rows_and_types(self):
        for source in CSV_SOURCES:
            with self.subTest(filename=source.filename):
                path = PROJECT_ROOT / "data" / "csv" / source.filename
                rows = list(parse_csv_rows(source, path))
                self.assertEqual(source.expected_rows, len(rows))

    def test_quality_cases_are_not_a_main_source(self):
        names = {source.filename for source in CSV_SOURCES}
        self.assertNotIn("casos_calidad_opcionales.csv", names)

        quality_path = PROJECT_ROOT / "data" / "quality" / "casos_calidad_opcionales.csv"
        with quality_path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(10, len(rows))

    def test_require_source_file_raises_if_missing(self):
        with self.assertRaises(FileNotFoundError):
            require_source_file(PROJECT_ROOT / "data" / "csv", "archivo_inexistente.csv")

    def test_parse_csv_rows_header_mismatch(self):
        dummy_source = CsvSource(
            filename="promociones.csv",
            table="promociones",
            columns=("columna_inexistente",),
            converters=(parse_text,),
            expected_rows=1,
        )
        path = PROJECT_ROOT / "data" / "csv" / "promociones.csv"
        with self.assertRaises(ValueError) as ctx:
            list(parse_csv_rows(dummy_source, path))
        self.assertIn("Columnas inesperadas", str(ctx.exception))


class OltpSourcesDefinitionsTests(unittest.TestCase):
    def test_oltp_sources_count(self):
        self.assertEqual(7, len(OLTP_SOURCES))
        tables = [s.table for s in OLTP_SOURCES]
        self.assertIn("sucursal", tables)
        self.assertIn("categoria", tables)
        self.assertIn("marca", tables)
        self.assertIn("producto", tables)
        self.assertIn("cliente", tables)
        self.assertIn("venta", tables)
        self.assertIn("venta_detalle", tables)


if __name__ == "__main__":
    unittest.main()
