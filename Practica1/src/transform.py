import pandas as pd
import numpy as np
import re


def normalizar_texto(valor):

    if pd.isna(valor):
        return valor

    valor = str(valor).strip()

    valor = re.sub(
        r"\s+",
        " ",
        valor
    )

    return valor


def limpiar_aerolineas(df):

    df["airline_code"] = (
        df["airline_code"]
        .apply(normalizar_texto)
        .str.upper()
    )

    df["airline_name"] = (
        df["airline_name"]
        .apply(normalizar_texto)
        .str.title()
    )

    return df


def limpiar_aeropuertos(df):

    df["origin_airport"] = (
        df["origin_airport"]
        .apply(normalizar_texto)
        .str.upper()
    )

    df["destination_airport"] = (
        df["destination_airport"]
        .apply(normalizar_texto)
        .str.upper()
    )

    return df


def limpiar_genero(df):

    df["passenger_gender"] = (
        df["passenger_gender"]
        .apply(normalizar_texto)
        .str.upper()
    )

    df["passenger_gender"] = (
        df["passenger_gender"]
        .replace({
            "MASCULINO": "M",
            "MALE": "M",
            "FEMENINO": "F",
            "FEMALE": "F"
        })
    )

    return df


def limpiar_estado(df):

    df["status"] = (
        df["status"]
        .apply(normalizar_texto)
        .str.upper()
    )

    return df


def limpiar_clase(df):

    df["cabin_class"] = (
        df["cabin_class"]
        .apply(normalizar_texto)
        .str.upper()
    )

    return df


def convertir_fecha(valor):

    if pd.isna(valor):
        return pd.NaT

    formatos = [
        "%d/%m/%Y %H:%M",
        "%m-%d-%Y %I:%M %p",
        "%Y-%m-%d %H:%M:%S",
        "%Y-%m-%d %H:%M"
    ]

    for formato in formatos:

        try:

            return pd.to_datetime(
                valor,
                format=formato
            )

        except:
            pass

    return pd.NaT


def limpiar_fechas(df):

    columnas = [
        "departure_datetime",
        "arrival_datetime",
        "booking_datetime"
    ]

    for columna in columnas:

        df[columna] = df[columna].apply(
            convertir_fecha
        )

    return df


def convertir_precio(valor):

    if pd.isna(valor):
        return np.nan

    valor = str(valor).strip()

    valor = valor.replace(
        ",",
        "."
    )

    valor = re.sub(
        r"[^0-9\.-]",
        "",
        valor
    )

    return pd.to_numeric(
        valor,
        errors="coerce"
    )


def limpiar_precios(df):

    df["ticket_price"] = (
        df["ticket_price"]
        .apply(convertir_precio)
    )

    df["ticket_price_usd_est"] = (
        pd.to_numeric(
            df["ticket_price_usd_est"],
            errors="coerce"
        )
    )

    return df


def limpiar_numericos(df):

    columnas = [
        "duration_min",
        "delay_min",
        "passenger_age",
        "bags_total",
        "bags_checked"
    ]

    for columna in columnas:

        df[columna] = pd.to_numeric(
            df[columna],
            errors="coerce"
        )

    return df


def tratar_nulos(df):

    df["passenger_nationality"] = (
        df["passenger_nationality"]
        .fillna("UNKNOWN")
        .apply(normalizar_texto)
        .str.upper()
    )

    df["sales_channel"] = (
        df["sales_channel"]
        .fillna("UNKNOWN")
        .apply(normalizar_texto)
        .str.upper()
    )

    return df


def limpiar_otros_campos(df):

    df["payment_method"] = (
        df["payment_method"]
        .apply(normalizar_texto)
        .str.upper()
    )

    df["currency"] = (
        df["currency"]
        .apply(normalizar_texto)
        .str.upper()
    )

    return df


def eliminar_duplicados(df):

    cantidad = df.duplicated().sum()

    print(
        f"Duplicados encontrados: {cantidad}"
    )

    df = df.drop_duplicates()

    return df


def transformar_datos(df):

    print(
        "\n TRANSFORMACIÓN "
    )

    df = df.copy()

    print(
        f"Registros antes: {len(df)}"
    )

    df = limpiar_aerolineas(df)
    df = limpiar_aeropuertos(df)
    df = limpiar_genero(df)
    df = limpiar_estado(df)
    df = limpiar_clase(df)
    df = limpiar_fechas(df)
    df = limpiar_precios(df)
    df = limpiar_numericos(df)
    df = tratar_nulos(df)
    df = limpiar_otros_campos(df)
    df = eliminar_duplicados(df)

    print(
        f"Registros después: {len(df)}"
    )

    return df