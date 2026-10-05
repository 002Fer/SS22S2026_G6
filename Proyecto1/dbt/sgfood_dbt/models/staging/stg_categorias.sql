with source as (
    select * from {{ source('raw', 'categoria') }}
),

renamed as (
    select
        cast(id_categoria as integer) as id_categoria,
        trim(nombre) as nombre_categoria,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
