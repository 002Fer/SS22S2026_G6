/*
    Practica 1 - Data warehouse de vuelos
    Motor: Microsoft SQL Server

    Grano de FactVuelo:
      una fila por registro de pasajero/ticket asociado a una ocurrencia de vuelo.

    El script es idempotente: puede ejecutarse mas de una vez sin borrar datos.
*/

USE [master];
GO

IF DB_ID(N'VuelosDW') IS NULL
BEGIN
    CREATE DATABASE [VuelosDW];
END;
GO

USE [VuelosDW];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.DimFecha', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimFecha
    (
        FechaKey       INT           NOT NULL,
        Fecha          DATE          NULL,
        Dia            TINYINT       NULL,
        Mes            TINYINT       NULL,
        NombreMes      NVARCHAR(15)  NOT NULL,
        Trimestre      TINYINT       NULL,
        Anio           SMALLINT      NULL,
        DiaSemana      TINYINT       NULL,
        NombreDia      NVARCHAR(15)  NOT NULL,
        EsFinDeSemana  BIT           NOT NULL,
        CONSTRAINT PK_DimFecha PRIMARY KEY CLUSTERED (FechaKey),
        CONSTRAINT UQ_DimFecha_Fecha UNIQUE (Fecha),
        CONSTRAINT CK_DimFecha_Mes CHECK (Mes IS NULL OR Mes BETWEEN 1 AND 12),
        CONSTRAINT CK_DimFecha_Trimestre CHECK (Trimestre IS NULL OR Trimestre BETWEEN 1 AND 4)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimAerolinea', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimAerolinea
    (
        AerolineaKey  INT IDENTITY(1,1) NOT NULL,
        Codigo        VARCHAR(10)       NOT NULL,
        Nombre        NVARCHAR(100)     NOT NULL,
        CONSTRAINT PK_DimAerolinea PRIMARY KEY CLUSTERED (AerolineaKey),
        CONSTRAINT UQ_DimAerolinea_Codigo UNIQUE (Codigo)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimAeropuerto', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimAeropuerto
    (
        AeropuertoKey  INT IDENTITY(1,1) NOT NULL,
        Codigo         VARCHAR(10)       NOT NULL,
        CONSTRAINT PK_DimAeropuerto PRIMARY KEY CLUSTERED (AeropuertoKey),
        CONSTRAINT UQ_DimAeropuerto_Codigo UNIQUE (Codigo)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimPasajero', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimPasajero
    (
        PasajeroKey   BIGINT IDENTITY(1,1) NOT NULL,
        PasajeroID    VARCHAR(50)          NOT NULL,
        Genero        VARCHAR(15)          NOT NULL,
        Edad          SMALLINT             NULL,
        Nacionalidad  VARCHAR(50)          NOT NULL,
        FechaInicio   DATETIME2(0)         NOT NULL,
        FechaFin      DATETIME2(0)         NOT NULL,
        EsActual      BIT                  NOT NULL,
        CONSTRAINT PK_DimPasajero PRIMARY KEY CLUSTERED (PasajeroKey),
        CONSTRAINT UQ_DimPasajero_Version UNIQUE (PasajeroID, FechaInicio),
        CONSTRAINT CK_DimPasajero_Edad CHECK (Edad IS NULL OR Edad BETWEEN 0 AND 130),
        CONSTRAINT CK_DimPasajero_Vigencia CHECK (FechaInicio < FechaFin)
    );

    CREATE UNIQUE INDEX UX_DimPasajero_Actual
        ON dbo.DimPasajero (PasajeroID)
        WHERE EsActual = 1;
END;
GO

IF OBJECT_ID(N'dbo.DimVuelo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimVuelo
    (
        VueloKey      INT IDENTITY(1,1) NOT NULL,
        NumeroVuelo   VARCHAR(20)       NOT NULL,
        TipoAeronave  VARCHAR(30)       NOT NULL,
        CONSTRAINT PK_DimVuelo PRIMARY KEY CLUSTERED (VueloKey),
        CONSTRAINT UQ_DimVuelo UNIQUE (NumeroVuelo, TipoAeronave)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimEstadoVuelo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimEstadoVuelo
    (
        EstadoVueloKey  INT IDENTITY(1,1) NOT NULL,
        Estado          VARCHAR(30)       NOT NULL,
        CONSTRAINT PK_DimEstadoVuelo PRIMARY KEY CLUSTERED (EstadoVueloKey),
        CONSTRAINT UQ_DimEstadoVuelo_Estado UNIQUE (Estado)
    );
END;
GO

IF OBJECT_ID(N'dbo.DimDetalleVenta', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDetalleVenta
    (
        DetalleVentaKey  INT IDENTITY(1,1) NOT NULL,
        CanalVenta       VARCHAR(30)       NOT NULL,
        MetodoPago       VARCHAR(30)       NOT NULL,
        Moneda           VARCHAR(10)       NOT NULL,
        ClaseCabina      VARCHAR(30)       NOT NULL,
        CONSTRAINT PK_DimDetalleVenta PRIMARY KEY CLUSTERED (DetalleVentaKey),
        CONSTRAINT UQ_DimDetalleVenta UNIQUE (CanalVenta, MetodoPago, Moneda, ClaseCabina)
    );
END;
GO

IF OBJECT_ID(N'dbo.FactVuelo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactVuelo
    (
        FactVueloKey          BIGINT IDENTITY(1,1) NOT NULL,
        RecordID              BIGINT                NOT NULL,
        OcurrenciaVueloID     VARCHAR(100)          NOT NULL,
        AerolineaKey          INT                   NOT NULL,
        VueloKey              INT                   NOT NULL,
        AeropuertoOrigenKey   INT                   NOT NULL,
        AeropuertoDestinoKey  INT                   NOT NULL,
        PasajeroKey           BIGINT                NOT NULL,
        FechaSalidaKey        INT                   NOT NULL,
        FechaLlegadaKey       INT                   NOT NULL,
        FechaReservaKey       INT                   NOT NULL,
        EstadoVueloKey        INT                   NOT NULL,
        DetalleVentaKey       INT                   NOT NULL,
        FechaHoraSalida       DATETIME2(0)          NULL,
        FechaHoraLlegada      DATETIME2(0)          NULL,
        FechaHoraReserva      DATETIME2(0)          NULL,
        Asiento               VARCHAR(10)           NULL,
        DuracionMinutos       SMALLINT              NULL,
        RetrasoMinutos        SMALLINT              NULL,
        PrecioTicketOriginal  DECIMAL(12,2)         NULL,
        PrecioTicketUSD       DECIMAL(12,2)         NULL,
        MaletasTotales        SMALLINT              NOT NULL,
        MaletasFacturadas     SMALLINT              NOT NULL,
        CantidadTickets       SMALLINT              NOT NULL CONSTRAINT DF_FactVuelo_CantidadTickets DEFAULT (1),
        FechaCarga            DATETIME2(0)          NOT NULL CONSTRAINT DF_FactVuelo_FechaCarga DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT PK_FactVuelo PRIMARY KEY CLUSTERED (FactVueloKey),
        CONSTRAINT UQ_FactVuelo_RecordID UNIQUE (RecordID),
        CONSTRAINT FK_FactVuelo_Aerolinea FOREIGN KEY (AerolineaKey) REFERENCES dbo.DimAerolinea (AerolineaKey),
        CONSTRAINT FK_FactVuelo_Vuelo FOREIGN KEY (VueloKey) REFERENCES dbo.DimVuelo (VueloKey),
        CONSTRAINT FK_FactVuelo_AeropuertoOrigen FOREIGN KEY (AeropuertoOrigenKey) REFERENCES dbo.DimAeropuerto (AeropuertoKey),
        CONSTRAINT FK_FactVuelo_AeropuertoDestino FOREIGN KEY (AeropuertoDestinoKey) REFERENCES dbo.DimAeropuerto (AeropuertoKey),
        CONSTRAINT FK_FactVuelo_Pasajero FOREIGN KEY (PasajeroKey) REFERENCES dbo.DimPasajero (PasajeroKey),
        CONSTRAINT FK_FactVuelo_FechaSalida FOREIGN KEY (FechaSalidaKey) REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactVuelo_FechaLlegada FOREIGN KEY (FechaLlegadaKey) REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactVuelo_FechaReserva FOREIGN KEY (FechaReservaKey) REFERENCES dbo.DimFecha (FechaKey),
        CONSTRAINT FK_FactVuelo_Estado FOREIGN KEY (EstadoVueloKey) REFERENCES dbo.DimEstadoVuelo (EstadoVueloKey),
        CONSTRAINT FK_FactVuelo_DetalleVenta FOREIGN KEY (DetalleVentaKey) REFERENCES dbo.DimDetalleVenta (DetalleVentaKey),
        CONSTRAINT CK_FactVuelo_Duracion CHECK (DuracionMinutos IS NULL OR DuracionMinutos >= 0),
        CONSTRAINT CK_FactVuelo_Retraso CHECK (RetrasoMinutos IS NULL OR RetrasoMinutos >= 0),
        CONSTRAINT CK_FactVuelo_Precios CHECK
            ((PrecioTicketOriginal IS NULL OR PrecioTicketOriginal >= 0)
             AND (PrecioTicketUSD IS NULL OR PrecioTicketUSD >= 0)),
        CONSTRAINT CK_FactVuelo_Maletas CHECK
            (MaletasTotales >= 0 AND MaletasFacturadas >= 0 AND MaletasFacturadas <= MaletasTotales),
        CONSTRAINT CK_FactVuelo_CantidadTickets CHECK (CantidadTickets = 1)
    );

    CREATE INDEX IX_FactVuelo_FechaSalida ON dbo.FactVuelo (FechaSalidaKey);
    CREATE INDEX IX_FactVuelo_Aerolinea ON dbo.FactVuelo (AerolineaKey);
    CREATE INDEX IX_FactVuelo_Destino ON dbo.FactVuelo (AeropuertoDestinoKey);
    CREATE INDEX IX_FactVuelo_Pasajero ON dbo.FactVuelo (PasajeroKey);
    CREATE INDEX IX_FactVuelo_Estado ON dbo.FactVuelo (EstadoVueloKey);
    CREATE INDEX IX_FactVuelo_Ocurrencia ON dbo.FactVuelo (OcurrenciaVueloID);
END;
GO

/* Miembros desconocidos para que las FK nunca queden nulas. */
IF NOT EXISTS (SELECT 1 FROM dbo.DimFecha WHERE FechaKey = 0)
BEGIN
    INSERT INTO dbo.DimFecha
        (FechaKey, Fecha, Dia, Mes, NombreMes, Trimestre, Anio, DiaSemana, NombreDia, EsFinDeSemana)
    VALUES
        (0, NULL, NULL, NULL, N'DESCONOCIDO', NULL, NULL, NULL, N'DESCONOCIDO', 0);
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimAerolinea WHERE AerolineaKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimAerolinea ON;
    INSERT INTO dbo.DimAerolinea (AerolineaKey, Codigo, Nombre)
    VALUES (0, 'UNKNOWN', N'DESCONOCIDA');
    SET IDENTITY_INSERT dbo.DimAerolinea OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimAeropuerto WHERE AeropuertoKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimAeropuerto ON;
    INSERT INTO dbo.DimAeropuerto (AeropuertoKey, Codigo)
    VALUES (0, 'UNKNOWN');
    SET IDENTITY_INSERT dbo.DimAeropuerto OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimPasajero WHERE PasajeroKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimPasajero ON;
    INSERT INTO dbo.DimPasajero
        (PasajeroKey, PasajeroID, Genero, Edad, Nacionalidad, FechaInicio, FechaFin, EsActual)
    VALUES
        (0, 'UNKNOWN', 'UNKNOWN', NULL, 'UNKNOWN', '19000101', '9999-12-31 23:59:59', 1);
    SET IDENTITY_INSERT dbo.DimPasajero OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimVuelo WHERE VueloKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimVuelo ON;
    INSERT INTO dbo.DimVuelo (VueloKey, NumeroVuelo, TipoAeronave)
    VALUES (0, 'UNKNOWN', 'UNKNOWN');
    SET IDENTITY_INSERT dbo.DimVuelo OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimEstadoVuelo WHERE EstadoVueloKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimEstadoVuelo ON;
    INSERT INTO dbo.DimEstadoVuelo (EstadoVueloKey, Estado)
    VALUES (0, 'UNKNOWN');
    SET IDENTITY_INSERT dbo.DimEstadoVuelo OFF;
END;
GO

IF NOT EXISTS (SELECT 1 FROM dbo.DimDetalleVenta WHERE DetalleVentaKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimDetalleVenta ON;
    INSERT INTO dbo.DimDetalleVenta
        (DetalleVentaKey, CanalVenta, MetodoPago, Moneda, ClaseCabina)
    VALUES
        (0, 'UNKNOWN', 'UNKNOWN', 'UNKNOWN', 'UNKNOWN');
    SET IDENTITY_INSERT dbo.DimDetalleVenta OFF;
END;
GO
