with source as (
    select * from {{ source('raw', 'devoluciones') }}
),

renamed as (
    select
        cast(id_devolucion as integer) as id_devolucion,
        cast(fecha as date) as fecha_devolucion,
        cast(id_venta as bigint) as id_venta,
        cast(id_producto as integer) as id_producto,
        cast(cantidad as integer) as cantidad_devuelta,
        trim(motivo) as motivo,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
