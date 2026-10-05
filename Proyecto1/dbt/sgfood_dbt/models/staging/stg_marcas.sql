with source as (
    select * from {{ source('raw', 'marca') }}
),

renamed as (
    select
        cast(id_marca as integer) as id_marca,
        trim(nombre) as nombre_marca,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
