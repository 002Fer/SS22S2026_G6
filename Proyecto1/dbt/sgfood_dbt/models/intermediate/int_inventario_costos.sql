with inventario as (
    select * from {{ ref('stg_inventario_bodega') }}
),

productos as (
    select * from {{ ref('stg_productos') }}
),

joined as (
    select
        inv.fecha_corte,
        inv.id_sucursal,
        inv.id_producto,
        inv.stock_disponible,
        inv.stock_minimo,
        inv.stock_maximo,
        inv.lote,
        inv.fecha_vencimiento,
        coalesce(p.costo_base, 0) as costo_base_producto,
        cast((inv.stock_disponible * coalesce(p.costo_base, 0)) as numeric(14, 2)) as valor_inventario_costo,
        case
            when inv.stock_disponible < inv.stock_minimo then true
            else false
        end as es_bajo_minimo
    from inventario inv
    left join productos p on inv.id_producto = p.id_producto
)

select * from joined
