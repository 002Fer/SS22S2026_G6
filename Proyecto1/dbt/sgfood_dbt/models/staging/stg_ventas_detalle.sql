with source as (
    select * from {{ source('raw', 'venta_detalle') }}
),

renamed as (
    select
        cast(id_detalle as bigint) as id_detalle,
        cast(id_venta as bigint) as id_venta,
        cast(id_producto as integer) as id_producto,
        cast(cantidad as integer) as cantidad,
        cast(precio_unitario as numeric(12, 2)) as precio_unitario,
        cast(descuento as numeric(5, 4)) as descuento_porcentaje,
        cast(subtotal as numeric(14, 2)) as subtotal,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
