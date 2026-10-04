# Proyecto 1 - Seminario de Sistemas 2

## Integrantes
- Integrante 1
- Integrante 2
- Integrante 3

## Descripción
Implementación de un flujo moderno de datos utilizando Python,
Apache Airflow, PostgreSQL y dbt.

## Arquitectura

Fuentes -> Python -> PostgreSQL RAW -> dbt -> Data Warehouse

Apache Airflow orquesta todo el proceso.

## Tecnologías
- Python
- Apache Airflow
- PostgreSQL
- dbt Core

## Estructura
- scripts/: extracción y carga
- dags/: DAGs de Airflow
- dbt/: proyecto dbt
- sql/: creación y validación de BD
- docs/: documentación