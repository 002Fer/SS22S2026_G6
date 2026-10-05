-- Test singular: Verifica que no existan registros de inventario con stock disponible negativo
select
    inventario_sk,
    stock_disponible
from {{ ref('fct_inventario') }}
where stock_disponible < 0
