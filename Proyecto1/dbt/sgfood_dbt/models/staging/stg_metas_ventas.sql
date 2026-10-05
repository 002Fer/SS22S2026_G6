with source as (
    select * from {{ source('raw', 'metas_ventas') }}
),

renamed as (
    select
        trim(periodo) as periodo,
        cast(id_sucursal as integer) as id_sucursal,
        cast(meta_ventas as numeric(14, 2)) as meta_ventas,
        cast(meta_unidades as integer) as meta_unidades,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
