with source as (
    select * from {{ source('raw', 'producto') }}
),

renamed as (
    select
        cast(id_producto as integer) as id_producto,
        trim(sku) as sku,
        trim(nombre) as nombre_producto,
        cast(id_categoria as integer) as id_categoria,
        cast(id_marca as integer) as id_marca,
        trim(unidad_medida) as unidad_medida,
        cast(costo_base as numeric(12, 2)) as costo_base,
        cast(precio_lista as numeric(12, 2)) as precio_lista,
        coalesce(activo, true) as es_activo,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
