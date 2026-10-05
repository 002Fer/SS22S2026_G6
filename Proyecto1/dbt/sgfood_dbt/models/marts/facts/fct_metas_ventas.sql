with stg_metas as (
    select * from {{ ref('stg_metas_ventas') }}
)

select
    md5(periodo || '_' || cast(id_sucursal as text)) as meta_sk,
    md5(cast(id_sucursal as text)) as sucursal_sk,
    periodo,
    meta_ventas,
    meta_unidades
from stg_metas
