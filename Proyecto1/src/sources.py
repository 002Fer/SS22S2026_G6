from dataclasses import dataclass
from datetime import date
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Callable


Converter = Callable[[str], object]


@dataclass(frozen=True)
class OltpSource:
    table: str
    columns: tuple[str, ...]


@dataclass(frozen=True)
class CsvSource:
    filename: str
    table: str
    columns: tuple[str, ...]
    converters: tuple[Converter, ...]
    expected_rows: int


def parse_text(value: str) -> str:
    return value.strip()


def parse_integer(value: str) -> int:
    return int(value.strip())


def parse_decimal(value: str) -> Decimal:
    try:
        return Decimal(value.strip())
    except InvalidOperation as error:
        raise ValueError(f"Decimal inválido: {value!r}") from error


def parse_date(value: str) -> date:
    return date.fromisoformat(value.strip())


OLTP_SOURCES = (
    OltpSource("sucursal", ("id_sucursal", "nombre", "ciudad", "departamento")),
    OltpSource("categoria", ("id_categoria", "nombre")),
    OltpSource("marca", ("id_marca", "nombre")),
    OltpSource(
        "producto",
        (
            "id_producto",
            "sku",
            "nombre",
            "id_categoria",
            "id_marca",
            "unidad_medida",
            "costo_base",
            "precio_lista",
            "activo",
        ),
    ),
    OltpSource(
        "cliente",
        (
            "id_cliente",
            "nit",
            "nombre",
            "tipo_cliente",
            "municipio",
            "departamento",
            "fecha_alta",
        ),
    ),
    OltpSource(
        "venta",
        ("id_venta", "fecha", "id_cliente", "id_sucursal", "canal", "metodo_pago", "estado"),
    ),
    OltpSource(
        "venta_detalle",
        (
            "id_detalle",
            "id_venta",
            "id_producto",
            "cantidad",
            "precio_unitario",
            "descuento",
            "subtotal",
        ),
    ),
)


CSV_SOURCES = (
    CsvSource(
        "inventario_bodega.csv",
        "inventario_bodega",
        (
            "fecha_corte",
            "id_sucursal",
            "id_producto",
            "stock_disponible",
            "stock_minimo",
            "stock_maximo",
            "lote",
            "fecha_vencimiento",
        ),
        (parse_date, parse_integer, parse_integer, parse_integer, parse_integer, parse_integer, parse_text, parse_date),
        3840,
    ),
    CsvSource(
        "proveedores_precios.csv",
        "proveedores_precios",
        ("id_proveedor", "proveedor", "id_producto", "costo_proveedor", "plazo_dias", "fecha_vigencia"),
        (parse_integer, parse_text, parse_integer, parse_decimal, parse_integer, parse_date),
        103,
    ),
    CsvSource(
        "promociones.csv",
        "promociones",
        ("id_promocion", "nombre", "fecha_inicio", "fecha_fin", "id_categoria", "porcentaje_descuento"),
        (parse_integer, parse_text, parse_date, parse_date, parse_integer, parse_decimal),
        30,
    ),
    CsvSource(
        "metas_ventas.csv",
        "metas_ventas",
        ("periodo", "id_sucursal", "meta_ventas", "meta_unidades"),
        (parse_text, parse_integer, parse_decimal, parse_integer),
        48,
    ),
    CsvSource(
        "devoluciones.csv",
        "devoluciones",
        ("id_devolucion", "fecha", "id_venta", "id_producto", "cantidad", "motivo"),
        (parse_integer, parse_date, parse_integer, parse_integer, parse_integer, parse_text),
        80,
    ),
)


def require_source_file(directory: Path, filename: str) -> Path:
    path = directory / filename
    if not path.is_file():
        raise FileNotFoundError(f"No se encontró la fuente requerida: {path}")
    return path


def parse_csv_rows(source: CsvSource, path: Path):
    import csv

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        actual_columns = tuple(reader.fieldnames or ())
        if actual_columns != source.columns:
            raise ValueError(
                f"Columnas inesperadas en {source.filename}. "
                f"Esperadas={source.columns}, encontradas={actual_columns}"
            )

        for line_number, row in enumerate(reader, start=2):
            parsed = []
            for column, converter in zip(source.columns, source.converters):
                raw_value = row[column]
                if raw_value is None or raw_value.strip() == "":
                    parsed.append(None)
                    continue
                try:
                    parsed.append(converter(raw_value))
                except (TypeError, ValueError) as error:
                    raise ValueError(
                        f"Dato inválido en {source.filename}, línea {line_number}, "
                        f"columna {column}: {raw_value!r}"
                    ) from error
            yield tuple(parsed)


