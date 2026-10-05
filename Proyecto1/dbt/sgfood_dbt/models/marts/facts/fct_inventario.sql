with int_inventario as (
    select * from {{ ref('int_inventario_costos') }}
)

select
    md5(cast(id_sucursal as text) || '_' || cast(id_producto as text) || '_' || cast(fecha_corte as text)) as inventario_sk,
    md5(cast(id_sucursal as text)) as sucursal_sk,
    md5(cast(id_producto as text)) as producto_sk,
    cast(to_char(fecha_corte, 'YYYYMMDD') as integer) as fecha_sk,
    stock_disponible,
    stock_minimo,
    stock_maximo,
    lote,
    fecha_vencimiento,
    costo_base_producto,
    valor_inventario_costo,
    es_bajo_minimo
from int_inventario
