import pandas as pd


def extraer_datos(ruta_csv):


    print(" EXTRACCIÓN ")

    try:
        df = pd.read_csv(ruta_csv)

        print("Archivo cargado correctamente.")
        print(f"Filas encontradas: {df.shape[0]}")
        print(f"Columnas encontradas: {df.shape[1]}")

        return df

    except FileNotFoundError:
        print("ERROR: No se encontró el archivo.")
        return None

    except Exception as error:
        print(f"ERROR al leer el archivo: {error}")
        return None