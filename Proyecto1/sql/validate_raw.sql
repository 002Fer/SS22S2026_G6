SELECT 'sucursal' AS tabla, COUNT(*) AS registros FROM raw.sucursal
UNION ALL SELECT 'categoria', COUNT(*) FROM raw.categoria
UNION ALL SELECT 'marca', COUNT(*) FROM raw.marca
UNION ALL SELECT 'producto', COUNT(*) FROM raw.producto
UNION ALL SELECT 'cliente', COUNT(*) FROM raw.cliente
UNION ALL SELECT 'venta', COUNT(*) FROM raw.venta
UNION ALL SELECT 'venta_detalle', COUNT(*) FROM raw.venta_detalle
UNION ALL SELECT 'inventario_bodega', COUNT(*) FROM raw.inventario_bodega
UNION ALL SELECT 'proveedores_precios', COUNT(*) FROM raw.proveedores_precios
UNION ALL SELECT 'promociones', COUNT(*) FROM raw.promociones
UNION ALL SELECT 'metas_ventas', COUNT(*) FROM raw.metas_ventas
UNION ALL SELECT 'devoluciones', COUNT(*) FROM raw.devoluciones
ORDER BY tabla;

