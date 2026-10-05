with int_devoluciones as (
    select * from {{ ref('int_devoluciones_detalle') }}
)

select
    md5(cast(id_devolucion as text)) as devolucion_sk,
    id_devolucion,
    id_venta,
    md5(cast(id_sucursal as text)) as sucursal_sk,
    md5(cast(id_producto as text)) as producto_sk,
    md5(cast(id_cliente as text)) as cliente_sk,
    cast(to_char(fecha_devolucion, 'YYYYMMDD') as integer) as fecha_sk,
    cantidad_devuelta,
    motivo
from int_devoluciones
