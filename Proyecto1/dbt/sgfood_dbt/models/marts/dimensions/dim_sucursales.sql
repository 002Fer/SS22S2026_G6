-- depends_on: {{ ref('stg_sucursales') }}
with sucursales as (
    select * from {{ ref('stg_sucursales') }}
)

select
    md5(cast(id_sucursal as text)) as sucursal_sk,
    id_sucursal,
    nombre_sucursal,
    ciudad,
    departamento
from sucursales
