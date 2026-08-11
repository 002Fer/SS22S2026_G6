import pandas as pd
import numpy as np
import re

pd.set_option("display.max_columns", 50)
pd.set_option("display.width", 120)



# 2) CARGAR DATASET


df_raw = pd.read_csv("dataset_sucio.csv")


df_before = df_raw.copy()

print("DATOS ORIGINALES:")
print(df_before.head())



# 3) DIAGNÓSTICO RÁPIDO


print("\nINFORMACIÓN DEL DATASET:")
df_before.info()

print("\nVALORES FALTANTES:")
print(
    df_before
    .replace(r"^\s*$", np.nan, regex=True)
    .isna()
    .sum()
    .sort_values(ascending=False)
)

print("\nDUPLICADOS:")
print(df_before.duplicated().sum())


 
# 4) LIMPIEZA / TRATAMIENTO DE DATOS
 

df = df_before.copy()


# ESTANDARIZACIÓN DE TEXTOS


def norm_text(s):

    if pd.isna(s):
        return s

    # Quitar espacios dobles y espacios en extremos
    s = re.sub(r"\s+", " ", str(s)).strip()

    return s


# Nombre
df["nombre"] = df["nombre"].apply(norm_text).str.title()

# Ciudad
df["ciudad"] = df["ciudad"].apply(norm_text).str.title()

# Categoría
df["categoria"] = df["categoria"].apply(norm_text).str.title()



# ESTANDARIZACIÓN DE GÉNERO


df["genero"] = df["genero"].apply(norm_text)

# Convertimos temporalmente a mayúsculas
df["genero"] = df["genero"].str.upper()

# Normalizamos valores
df["genero"] = df["genero"].replace({
    "M": "Masculino",
    "F": "Femenino"
})



# ESTANDARIZACIÓN DE FECHAS


# El dataset contiene diferentes formatos
date_formats = [
    "%Y-%m-%d",
    "%d/%m/%Y",
    "%Y/%m/%d"
]

fecha = pd.to_datetime(
    df["fecha_registro"],
    format=date_formats[0],
    errors="coerce"
)

for fmt in date_formats[1:]:

    fecha = fecha.fillna(
        pd.to_datetime(
            df["fecha_registro"],
            format=fmt,
            errors="coerce"
        )
    )

df["fecha_registro"] = fecha


# ESTANDARIZACIÓN DEL GASTO


def money_to_float(x):

    if pd.isna(x):
        return np.nan

    s = str(x).strip()

    # Cambiar coma decimal por punto
    s = s.replace(",", ".")

    # Eliminar cualquier carácter que no sea
    # número, punto o signo
    s = re.sub(r"[^0-9\.-]", "", s)

    return pd.to_numeric(
        s,
        errors="coerce"
    )


df["gasto_q"] = df["gasto_q"].apply(
    money_to_float
)


 
# 5) TRATAMIENTO DE CELDAS VACÍAS
 

# Nombre faltante
df["nombre"] = df["nombre"].fillna(
    "Desconocido"
)

# Género faltante
df["genero"] = df["genero"].fillna(
    "Desconocido"
)

# Ciudad faltante
df["ciudad"] = df["ciudad"].fillna(
    "Desconocida"
)

# Categoría faltante
df["categoria"] = df["categoria"].fillna(
    "Desconocida"
)


# ------------------------------------------
# Gasto faltante
# ------------------------------------------

# El gasto NaN lo ponemos en 0 ya que se asume que no tuvo gastos 
df["gasto_q"] = df["gasto_q"].fillna(0)


 
# 6) ELIMINACIÓN DE DUPLICADOS
 

df = df.drop_duplicates()


# Resultado final
df_after = df.copy()


 
# 7) EVIDENCIA ANTES VS DESPUÉS
 

print("\n============================")
print("ANTES DE LA LIMPIEZA")
print("============================")

print(df_before.head(10))


print("\n============================")
print("DESPUÉS DE LA LIMPIEZA")
print("============================")

print(df_after.head(10))


 
# 8) COMPARACIÓN DE CALIDAD
 

resumen_calidad = pd.DataFrame({

    "faltantes_antes":
        df_before
        .replace(r"^\s*$", np.nan, regex=True)
        .isna()
        .sum(),

    "faltantes_despues":
        df_after
        .isna()
        .sum(),

    "dtype_antes":
        df_before
        .dtypes
        .astype(str),

    "dtype_despues":
        df_after
        .dtypes
        .astype(str)

})

print("\nRESUMEN DE CALIDAD:")

print(resumen_calidad)


 
# 9) RESULTADOS GENERALES
 

print("\nFilas antes:")
print(len(df_before))

print("\nFilas después:")
print(len(df_after))

print("\nDuplicados antes:")
print(df_before.duplicated().sum())

print("\nDuplicados después:")
print(df_after.duplicated().sum())


 
# 10) EXPORTAR DATASET LIMPIO
 

output_path = "dataset_limpio.csv"

df_after.to_csv(
    output_path,
    index=False,
    encoding="utf-8"
)

print("\nArchivo exportado:")
print(output_path)