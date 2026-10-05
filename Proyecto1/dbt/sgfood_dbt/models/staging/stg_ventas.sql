with source as (
    select * from {{ source('raw', 'venta') }}
),

renamed as (
    select
        cast(id_venta as bigint) as id_venta,
        cast(fecha as date) as fecha_venta,
        cast(id_cliente as integer) as id_cliente,
        cast(id_sucursal as integer) as id_sucursal,
        upper(trim(canal)) as canal_venta,
        upper(trim(metodo_pago)) as metodo_pago,
        upper(trim(estado)) as estado_venta,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
