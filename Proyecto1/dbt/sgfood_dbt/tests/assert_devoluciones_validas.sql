-- Test singular: Verifica que las cantidades devueltas sean estrictamente mayores a cero
select
    devolucion_sk,
    cantidad_devuelta
from {{ ref('fct_devoluciones') }}
where cantidad_devuelta <= 0
