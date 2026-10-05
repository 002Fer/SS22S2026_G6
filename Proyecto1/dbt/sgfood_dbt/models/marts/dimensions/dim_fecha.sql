with date_spine as (
    select
        cast(datum as date) as fecha
    from generate_series('2024-01-01'::date, '2026-12-31'::date, '1 day'::interval) as datum
)

select
    cast(to_char(fecha, 'YYYYMMDD') as integer) as fecha_sk,
    fecha,
    extract(year from fecha)::integer as anio,
    extract(month from fecha)::integer as mes,
    extract(day from fecha)::integer as dia,
    extract(quarter from fecha)::integer as trimestre,
    trim(to_char(fecha, 'TMMonth')) as nombre_mes,
    trim(to_char(fecha, 'TMDay')) as nombre_dia,
    case
        when extract(isodow from fecha) in (6, 7) then true
        else false
    end as es_fin_de_semana
from date_spine
