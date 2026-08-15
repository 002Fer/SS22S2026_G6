import argparse
import sys
from pathlib import Path

from extract import extraer_datos
from transform import transformar_datos

RAIZ_PROYECTO = Path(__file__).resolve().parent.parent

RUTA_ENTRADA_PREDETERMINADA = (
    RAIZ_PROYECTO / "datos" / "dataset_vuelos_crudo.csv"
)

RUTA_SALIDA_PREDETERMINADA = (
    RAIZ_PROYECTO / "datos" / "dataset_vuelos_limpio.csv"
)

def crear_argumentos():
    parser = argparse.ArgumentParser(
        description="Ejecuta la extracción y transformación del dataset de vuelos."
    )

    parser.add_argument(
        "--entrada",
        type=Path,
        default=RUTA_ENTRADA_PREDETERMINADA,
        help="Ruta del archivo CSV crudo.",
    )

    parser.add_argument(
        "--salida",
        type=Path,
        default=RUTA_SALIDA_PREDETERMINADA,
        help="Ruta donde se guardará el CSV limpio.",
    )

    return parser


def main():

    parser = crear_argumentos()
    args = parser.parse_args()

    try:

        print("=" * 60)
        print("INICIANDO PROCESO ETL")
        print("=" * 60)

        # 1. EXTRACCIÓN

        print("\n[1] Extrayendo datos...")

        df = extraer_datos(args.entrada)

        print("Datos extraídos correctamente.")
        print(f"Registros encontrados: {len(df)}")

        # 2. TRANSFORMACIÓN

        print("\n[2] Transformando y limpiando datos...")

        df_limpio = transformar_datos(df)

        print("Datos transformados correctamente.")
        print(f"Registros finales: {len(df_limpio)}")

        # 3. GUARDAR CSV LIMPIO

        print("\n[3] Guardando dataset limpio...")

        args.salida.parent.mkdir(
            parents=True,
            exist_ok=True
        )

        df_limpio.to_csv(
            args.salida,
            index=False
        )

        print("Archivo guardado correctamente.")
        print(f"Ruta: {args.salida}")

        print("\n" + "=" * 60)
        print("PROCESO ETL FINALIZADO CORRECTAMENTE")
        print("=" * 60)

    except FileNotFoundError as error:

        print("\nError: archivo no encontrado.")
        print(error)

        sys.exit(1)

    except Exception as error:

        print("\nOcurrió un error durante el proceso ETL:")
        print(error)

        sys.exit(1)

if __name__ == "__main__":
    main()