with int_ventas as (
    select * from {{ ref('int_ventas_lineas') }}
)

select
    md5(cast(id_detalle as text)) as venta_linea_sk,
    id_venta,
    id_detalle,
    md5(cast(id_cliente as text)) as cliente_sk,
    md5(cast(id_sucursal as text)) as sucursal_sk,
    md5(cast(id_producto as text)) as producto_sk,
    cast(to_char(fecha_venta, 'YYYYMMDD') as integer) as fecha_sk,
    canal_venta,
    metodo_pago,
    estado_venta,
    cantidad,
    precio_unitario,
    descuento_porcentaje,
    monto_bruto,
    monto_descuento,
    monto_neto,
    costo_unitario,
    costo_total,
    utilidad
from int_ventas
