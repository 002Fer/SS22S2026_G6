-- depends_on: {{ ref('stg_devoluciones') }}
-- depends_on: {{ ref('stg_ventas') }}

with devoluciones as (
    select * from {{ ref('stg_devoluciones') }}
),

ventas as (
    select * from {{ ref('stg_ventas') }}
),

joined as (
    select
        d.id_devolucion,
        d.fecha_devolucion,
        d.id_venta,
        d.id_producto,
        coalesce(v.id_sucursal, 0) as id_sucursal,
        coalesce(v.id_cliente, 0) as id_cliente,
        d.cantidad_devuelta,
        d.motivo
    from devoluciones d
    left join ventas v on d.id_venta = v.id_venta
)

select * from joined
