/*

Practica 1 - Data Warehouse - vuelos

**/

USE VuelosDW;


/* =========================================================
   CONSULTA 1: TOTAL DE VUELOS
   =========================================================
   Se cuentan las ocurrencias de vuelo distintas, ya que
   FactVuelo tiene una fila por pasajero/ticket.
*/
SELECT
    COUNT(DISTINCT OcurrenciaVueloID) AS TotalVuelos
FROM dbo.FactVuelo;


/* =========================================================
   CONSULTA 2: VUELOS POR AEROLINEA
   =========================================================
   Se cuentan las ocurrencias de vuelo distintas por
   aerolínea.
*/
SELECT
    a.Codigo AS CodigoAerolinea,
    a.Nombre AS Aerolinea,
    COUNT(DISTINCT f.OcurrenciaVueloID) AS TotalVuelos
FROM dbo.FactVuelo AS f
INNER JOIN dbo.DimAerolinea AS a
    ON f.AerolineaKey = a.AerolineaKey
GROUP BY
    a.Codigo,
    a.Nombre
ORDER BY
    TotalVuelos DESC;



/* =========================================================
   CONSULTA 3: TOP 5 DESTINOS
   =========================================================
   Se identifican los cinco aeropuertos destino con mayor
   cantidad de ocurrencias de vuelo.
*/
SELECT TOP 5
    ap.Codigo AS AeropuertoDestino,
    COUNT(DISTINCT f.OcurrenciaVueloID) AS TotalVuelos
FROM dbo.FactVuelo AS f
INNER JOIN dbo.DimAeropuerto AS ap
    ON f.AeropuertoDestinoKey = ap.AeropuertoKey
GROUP BY
    ap.Codigo
ORDER BY
    TotalVuelos DESC;



/* =========================================================
   CONSULTA 4: DISTRIBUCION POR GENERO
   =========================================================
   Como cada registro representa un pasajero/ticket,
   COUNT(*) permite obtener la cantidad de pasajeros/tickets
   por género.
*/
SELECT
    p.Genero,
    COUNT(*) AS TotalPasajeros
FROM dbo.FactVuelo AS f
INNER JOIN dbo.DimPasajero AS p
    ON f.PasajeroKey = p.PasajeroKey
GROUP BY
    p.Genero
ORDER BY
    TotalPasajeros DESC;



/* =========================================================
   CONSULTA 5: VUELOS CANCELADOS
   =========================================================
   Se cuentan las ocurrencias de vuelo distintas cuyo estado
   corresponde a CANCELADO.
*/
SELECT
    COUNT(DISTINCT f.OcurrenciaVueloID) AS VuelosCancelados
FROM dbo.FactVuelo AS f
INNER JOIN dbo.DimEstadoVuelo AS e
    ON f.EstadoVueloKey = e.EstadoVueloKey
WHERE
    UPPER(e.Estado) = 'CANCELADO';



/* =========================================================
   CONSULTA 6: VUELOS RETRASADOS
   =========================================================
   Se considera retrasado un vuelo cuyo RetrasoMinutos
   sea mayor que cero.
*/
SELECT
    COUNT(DISTINCT OcurrenciaVueloID) AS VuelosRetrasados
FROM dbo.FactVuelo
WHERE
    RetrasoMinutos > 0;


/* =========================================================
   CONSULTA 7: PROMEDIO DE RETRASOS
   =========================================================
   Se calcula el promedio de retraso en minutos.
*/
SELECT
    AVG(CAST(RetrasoMinutos AS DECIMAL(10,2))) AS PromedioRetrasoMinutos
FROM dbo.FactVuelo
WHERE
    RetrasoMinutos IS NOT NULL;



/* =========================================================
   CONSULTA 8: VENTAS / TICKETS
   =========================================================
   Se muestra la cantidad total de tickets y el total de
   ventas en USD.
*/
SELECT
    COUNT(*) AS TotalTickets,
    SUM(PrecioTicketUSD) AS VentasTotalesUSD,
    AVG(PrecioTicketUSD) AS PrecioPromedioTicketUSD
FROM dbo.FactVuelo
WHERE
    PrecioTicketUSD IS NOT NULL;
