with source as (
    select * from {{ source('raw', 'cliente') }}
),

renamed as (
    select
        cast(id_cliente as integer) as id_cliente,
        trim(nit) as nit,
        trim(nombre) as nombre_cliente,
        trim(tipo_cliente) as tipo_cliente,
        trim(municipio) as municipio,
        trim(departamento) as departamento,
        cast(fecha_alta as date) as fecha_alta,
        _loaded_at,
        _source,
        _batch_id
    from source
)

select * from renamed
