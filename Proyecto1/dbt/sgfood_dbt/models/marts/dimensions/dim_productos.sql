with productos as (
    select * from {{ ref('stg_productos') }}
),

categorias as (
    select * from {{ ref('stg_categorias') }}
),

marcas as (
    select * from {{ ref('stg_marcas') }}
)

select
    md5(cast(p.id_producto as text)) as producto_sk,
    p.id_producto,
    p.sku,
    p.nombre_producto,
    coalesce(c.nombre_categoria, 'SIN CATEGORIA') as nombre_categoria,
    coalesce(m.nombre_marca, 'SIN MARCA') as nombre_marca,
    p.unidad_medida,
    p.costo_base,
    p.precio_lista,
    p.es_activo
from productos p
left join categorias c on p.id_categoria = c.id_categoria
left join marcas m on p.id_marca = m.id_marca
