with source as (
    select * from {{ source('raw', 'sucursal') }}
),

renamed as (
    select
        cast(id_sucursal as integer) as id_sucursal,
        trim(nombre) as nombre_sucursal,
        trim(ciudad) as ciudad,
        trim(departamento) as departamento,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
