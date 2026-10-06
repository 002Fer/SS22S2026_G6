"""
===============================================================================
PROYECTO 1 - SEMINARIO DE SISTEMAS 2 (SG-FOOD)
DAG PRINCIPAL DE APACHE AIRFLOW PARA ORQUESTACIÓN ELT
===============================================================================
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator

default_args = {
    'owner': 'sgfood_team',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    dag_id='sgfood_elt_pipeline',
    default_args=default_args,
    description='Orquestación completa ELT para SG-Food (Python Extract -> Raw DW -> dbt Models -> dbt Tests)',
    schedule_interval='0 3 * * *',  # Ejecución diaria a las 03:00 AM
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=['sgfood', 'elt', 'dbt', 'postgres', 'airflow'],
) as dag:

    start_pipeline = EmptyOperator(
        task_id='start_pipeline'
    )

    # 1. Extracción y Carga OLTP -> raw
    load_oltp_task = BashOperator(
        task_id='load_oltp_to_raw',
        bash_command='python -m src.main load-oltp',
        cwd='/opt/airflow/project',
    )

    # 2. Extracción y Carga CSV -> raw
    load_csv_task = BashOperator(
        task_id='load_csv_to_raw',
        bash_command='python -m src.main load-csv',
        cwd='/opt/airflow/project',
    )

    # 3. Validación de Paridad y Conteo en raw
    validate_raw_task = BashOperator(
        task_id='validate_raw_data',
        bash_command='python -m src.main validate',
        cwd='/opt/airflow/project',
    )

    # 4. Transformación dbt (staging, intermediate, marts)
    dbt_run_task = BashOperator(
        task_id='dbt_run_models',
        bash_command='cd dbt/sgfood_dbt && dbt run --profiles-dir .',
        cwd='/opt/airflow/project',
    )

    # 5. Pruebas de Calidad dbt (generic & singular tests)
    dbt_test_task = BashOperator(
        task_id='dbt_test_quality',
        bash_command='cd dbt/sgfood_dbt && dbt test --profiles-dir .',
        cwd='/opt/airflow/project',
    )

    end_pipeline = EmptyOperator(
        task_id='end_pipeline'
    )

    # Definición de dependencias secuenciales y en paralelo
    start_pipeline >> [load_oltp_task, load_csv_task] >> validate_raw_task >> dbt_run_task >> dbt_test_task >> end_pipeline
