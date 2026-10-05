-- Test singular: Verifica que no existan líneas de venta con montos netos negativos
select
    venta_linea_sk,
    monto_neto
from {{ ref('fct_ventas') }}
where monto_neto < 0
