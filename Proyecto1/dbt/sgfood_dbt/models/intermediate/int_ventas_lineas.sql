with ventas as (
    select * from {{ ref('stg_ventas') }}
),

detalle as (
    select * from {{ ref('stg_ventas_detalle') }}
),

productos as (
    select * from {{ ref('stg_productos') }}
),

joined as (
    select
        d.id_detalle,
        d.id_venta,
        v.fecha_venta,
        v.id_cliente,
        v.id_sucursal,
        d.id_producto,
        v.canal_venta,
        v.metodo_pago,
        v.estado_venta,
        d.cantidad,
        d.precio_unitario,
        d.descuento_porcentaje,
        cast((d.cantidad * d.precio_unitario) as numeric(14, 2)) as monto_bruto,
        cast(((d.cantidad * d.precio_unitario) * d.descuento_porcentaje) as numeric(14, 2)) as monto_descuento,
        d.subtotal as monto_neto,
        coalesce(p.costo_base, 0) as costo_unitario,
        cast((d.cantidad * coalesce(p.costo_base, 0)) as numeric(14, 2)) as costo_total,
        cast((d.subtotal - (d.cantidad * coalesce(p.costo_base, 0))) as numeric(14, 2)) as utilidad
    from detalle d
    inner join ventas v on d.id_venta = v.id_venta
    left join productos p on d.id_producto = p.id_producto
)

select * from joined
