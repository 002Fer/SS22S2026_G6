-- depends_on: {{ ref('stg_clientes') }}
with stg_clientes as (
    select * from {{ ref('stg_clientes') }}
)

select
    md5(cast(id_cliente as text)) as cliente_sk,
    id_cliente,
    nit,
    nombre_cliente,
    tipo_cliente,
    municipio,
    departamento,
    fecha_alta
from stg_clientes
