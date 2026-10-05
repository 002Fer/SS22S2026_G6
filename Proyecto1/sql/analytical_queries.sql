/*
===============================================================================
PROYECTO 1 - SEMINARIO DE SISTEMAS 2 (SG-FOOD)
SCRIPTS DE CONSULTAS ANALÍTICAS Y RESULTADOS DE NEGOCIO (DATAMARTS)
===============================================================================
*/

-- -----------------------------------------------------------------------------
-- CONSULTA 1: VENTAS TOTALES, COSTOS Y UTILIDAD BRUTA POR SUCURSAL Y DEPARTAMENTO
-- Propósito: Evaluar el rendimiento financiero de cada punto de venta y su margen de utilidad.
-- -----------------------------------------------------------------------------
SELECT
    s.nombre_sucursal,
    s.departamento,
    COUNT(DISTINCT v.id_venta) AS total_transacciones,
    SUM(v.cantidad) AS total_unidades_vendidas,
    SUM(v.monto_bruto) AS venta_bruta_gtq,
    SUM(v.monto_descuento) AS descuentos_otorgados_gtq,
    SUM(v.monto_neto) AS venta_neta_gtq,
    SUM(v.costo_total) AS costo_total_gtq,
    SUM(v.utilidad) AS utilidad_bruta_gtq,
    ROUND(CAST((SUM(v.utilidad) / NULLIF(SUM(v.monto_neto), 0)) * 100 AS NUMERIC), 2) AS margen_utilidad_pct
FROM marts.fct_ventas v
JOIN marts.dim_sucursales s ON v.sucursal_sk = s.sucursal_sk
WHERE v.estado_venta = 'COMPLETADA'
GROUP BY s.nombre_sucursal, s.departamento
ORDER BY venta_neta_gtq DESC;


-- -----------------------------------------------------------------------------
-- CONSULTA 2: TOP 10 PRODUCTOS MÁS VENDIDOS Y MARGEN POR CATEGORÍA Y MARCA
-- Propósito: Identificar los artículos líderes en generación de ingresos para estrategia de surtido.
-- -----------------------------------------------------------------------------
SELECT
    p.sku,
    p.nombre_producto,
    p.nombre_categoria,
    p.nombre_marca,
    SUM(v.cantidad) AS unidades_vendidas,
    SUM(v.monto_neto) AS ingresos_netos_gtq,
    SUM(v.utilidad) AS utilidad_generada_gtq,
    ROUND(CAST((SUM(v.utilidad) / NULLIF(SUM(v.monto_neto), 0)) * 100 AS NUMERIC), 2) AS margen_pct
FROM marts.fct_ventas v
JOIN marts.dim_productos p ON v.producto_sk = p.producto_sk
WHERE v.estado_venta = 'COMPLETADA'
GROUP BY p.sku, p.nombre_producto, p.nombre_categoria, p.nombre_marca
ORDER BY ingresos_netos_gtq DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- CONSULTA 3: CUMPLIMIENTO DE METAS DE VENTAS MENSUALES POR SUCURSAL
-- Propósito: Comparar el desempeño real de ventas contra los objetivos comerciales fijados.
-- -----------------------------------------------------------------------------
WITH ventas_mensuales AS (
    SELECT
        v.sucursal_sk,
        to_char(f.fecha, 'YYYY-MM') AS periodo,
        SUM(v.monto_neto) AS venta_real_gtq,
        SUM(v.cantidad) AS unidades_reales
    FROM marts.fct_ventas v
    JOIN marts.dim_fecha f ON v.fecha_sk = f.fecha_sk
    WHERE v.estado_venta = 'COMPLETADA'
    GROUP BY v.sucursal_sk, to_char(f.fecha, 'YYYY-MM')
)
SELECT
    m.periodo,
    s.nombre_sucursal,
    m.meta_ventas AS meta_ventas_gtq,
    COALESCE(vm.venta_real_gtq, 0) AS venta_real_gtq,
    ROUND(CAST((COALESCE(vm.venta_real_gtq, 0) / NULLIF(m.meta_ventas, 0)) * 100 AS NUMERIC), 2) AS pct_cumplimiento_ventas,
    m.meta_unidades,
    COALESCE(vm.unidades_reales, 0) AS unidades_reales,
    ROUND(CAST((COALESCE(vm.unidades_reales, 0) / NULLIF(m.meta_unidades, 0)) * 100 AS NUMERIC), 2) AS pct_cumplimiento_unidades
FROM marts.fct_metas_ventas m
JOIN marts.dim_sucursales s ON m.sucursal_sk = s.sucursal_sk
LEFT JOIN ventas_mensuales vm ON m.sucursal_sk = vm.sucursal_sk AND m.periodo = vm.periodo
ORDER BY m.periodo ASC, pct_cumplimiento_ventas DESC;


-- -----------------------------------------------------------------------------
-- CONSULTA 4: ALERTA DE INVENTARIOS EN NIVEL CRÍTICO (STOCK BAJO EL MÍNIMO)
-- Propósito: Monitorear desabastecimiento e insumos de bajo stock en bodegas de sucursal.
-- -----------------------------------------------------------------------------
SELECT
    f.fecha AS fecha_corte,
    s.nombre_sucursal,
    p.sku,
    p.nombre_producto,
    p.nombre_categoria,
    inv.stock_disponible,
    inv.stock_minimo,
    inv.stock_maximo,
    (inv.stock_minimo - inv.stock_disponible) AS unidades_faltantes_para_minimo,
    inv.valor_inventario_costo AS valor_stock_actual_gtq
FROM marts.fct_inventario inv
JOIN marts.dim_sucursales s ON inv.sucursal_sk = s.sucursal_sk
JOIN marts.dim_productos p ON inv.producto_sk = p.producto_sk
JOIN marts.dim_fecha f ON inv.fecha_sk = f.fecha_sk
WHERE inv.es_bajo_minimo = TRUE
ORDER BY unidades_faltantes_para_minimo DESC;


-- -----------------------------------------------------------------------------
-- CONSULTA 5: TASA Y MOTIVOS DE DEVOLUCIONES DE PRODUCTO POR SUCURSAL
-- Propósito: Analizar la calidad de los productos y problemas operativos en entregas.
-- -----------------------------------------------------------------------------
SELECT
    s.nombre_sucursal,
    p.nombre_producto,
    p.nombre_categoria,
    d.motivo,
    COUNT(d.devolucion_sk) AS eventos_devolucion,
    SUM(d.cantidad_devuelta) AS total_unidades_devueltas
FROM marts.fct_devoluciones d
JOIN marts.dim_sucursales s ON d.sucursal_sk = s.sucursal_sk
JOIN marts.dim_productos p ON d.producto_sk = p.producto_sk
GROUP BY s.nombre_sucursal, p.nombre_producto, p.nombre_categoria, d.motivo
ORDER BY total_unidades_devueltas DESC;
