/*
===============================================================================
PROYECTO 1 - SEMINARIO DE SISTEMAS 2 (SG-FOOD)
SCRIPTS DE VALIDACIÓN DE CONTEOS Y CONSISTENCIA EN DATAWAREHOUSE (MARTS)
===============================================================================
*/

-- 1. Validar conteos en Staging
SELECT 'staging.stg_sucursales' AS tabla, COUNT(*) AS total_registros FROM staging.stg_sucursales
UNION ALL
SELECT 'staging.stg_categorias', COUNT(*) FROM staging.stg_categorias
UNION ALL
SELECT 'staging.stg_marcas', COUNT(*) FROM staging.stg_marcas
UNION ALL
SELECT 'staging.stg_productos', COUNT(*) FROM staging.stg_productos
UNION ALL
SELECT 'staging.stg_clientes', COUNT(*) FROM staging.stg_clientes
UNION ALL
SELECT 'staging.stg_ventas', COUNT(*) FROM staging.stg_ventas
UNION ALL
SELECT 'staging.stg_ventas_detalle', COUNT(*) FROM staging.stg_ventas_detalle
UNION ALL
SELECT 'staging.stg_inventario_bodega', COUNT(*) FROM staging.stg_inventario_bodega
UNION ALL
SELECT 'staging.stg_proveedores_precios', COUNT(*) FROM staging.stg_proveedores_precios
UNION ALL
SELECT 'staging.stg_promociones', COUNT(*) FROM staging.stg_promociones
UNION ALL
SELECT 'staging.stg_metas_ventas', COUNT(*) FROM staging.stg_metas_ventas
UNION ALL
SELECT 'staging.stg_devoluciones', COUNT(*) FROM staging.stg_devoluciones;

-- 2. Validar conteos en Dimensiones y Hechos (Marts)
SELECT 'marts.dim_clientes' AS tabla, COUNT(*) AS total_registros FROM marts.dim_clientes
UNION ALL
SELECT 'marts.dim_productos', COUNT(*) FROM marts.dim_productos
UNION ALL
SELECT 'marts.dim_sucursales', COUNT(*) FROM marts.dim_sucursales
UNION ALL
SELECT 'marts.dim_fecha', COUNT(*) FROM marts.dim_fecha
UNION ALL
SELECT 'marts.fct_ventas', COUNT(*) FROM marts.fct_ventas
UNION ALL
SELECT 'marts.fct_inventario', COUNT(*) FROM marts.fct_inventario
UNION ALL
SELECT 'marts.fct_metas_ventas', COUNT(*) FROM marts.fct_metas_ventas
UNION ALL
SELECT 'marts.fct_devoluciones', COUNT(*) FROM marts.fct_devoluciones;
