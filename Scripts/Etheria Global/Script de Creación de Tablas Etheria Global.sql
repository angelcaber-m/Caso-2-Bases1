-- Creación de la base de datos (Ejecutar por separado si es necesario)
-- CREATE DATABASE "EtheriaGlobal";

-- Extensión para manejo de UUID (necesaria para trazabilidadMovimientos)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

--------------------------------------------------------------------------------
-- 1. CATÁLOGOS BÁSICOS E INFRAESTRUCTURA
--------------------------------------------------------------------------------

CREATE TABLE personas (
    personaId SERIAL PRIMARY KEY,
    cedulaIdentidad VARCHAR(50) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    primerApellido VARCHAR(100) NOT NULL,
    segundoApellido VARCHAR(100),
    email VARCHAR(150) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE monedas (
    monedaId SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL,
    codigoISO VARCHAR(3) UNIQUE NOT NULL,
    simbolo VARCHAR(5),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE exchangeRates (
    exchangeRateId SERIAL PRIMARY KEY,
    monedaOrigenId INT NOT NULL REFERENCES monedas(monedaId),
    monedaDestinoId INT NOT NULL REFERENCES monedas(monedaId),
    valorCompra NUMERIC(12,6) NOT NULL,
    valorVenta NUMERIC(12,6) NOT NULL,
    fechaRegistro TIMESTAMPTZ DEFAULT NOW(),
    fechaEfectiva DATE NOT NULL,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

--------------------------------------------------------------------------------
-- 2. GEOGRAFÍA Y LOCALIZACIÓN
--------------------------------------------------------------------------------

CREATE TABLE paises (
    paisId SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    codigoISO VARCHAR(5) UNIQUE NOT NULL,
    monedaLocalId INT REFERENCES monedas(monedaId),
    activo BOOLEAN DEFAULT TRUE,
    createdAt TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE provinciasEstados (
    provinciaEstadoId SERIAL PRIMARY KEY,
    paisId INT NOT NULL REFERENCES paises(paisId),
    nombre VARCHAR(100) NOT NULL,
    codigoPostalOpcional VARCHAR(20),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE ciudades (
    ciudadId SERIAL PRIMARY KEY,
    provinciaEstadoId INT NOT NULL REFERENCES provinciasEstados(provinciaEstadoId),
    nombre VARCHAR(100) NOT NULL,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE direcciones (
    direccionId SERIAL PRIMARY KEY,
    ciudadId INT NOT NULL REFERENCES ciudades(ciudadId),
    detalles VARCHAR(255),
    updatedAt TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

--------------------------------------------------------------------------------
-- 3. PROVEEDORES Y PRODUCTOS BASE
--------------------------------------------------------------------------------

CREATE TABLE proveedores (
    proveedorId SERIAL PRIMARY KEY,
    cedulaJuridica VARCHAR(50) UNIQUE NOT NULL,
    nombreComercial VARCHAR(150) NOT NULL,
    direccionId INT REFERENCES direcciones(direccionId),
    telefonoOficina VARCHAR(20),
    activo BOOLEAN DEFAULT TRUE,
    createdAt TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE proveedoresContactosLegales (
    proveedorId INT REFERENCES proveedores(proveedorId),
    personaId INT REFERENCES personas(personaId),
    rol VARCHAR(50),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    PRIMARY KEY (proveedorId, personaId)
);

CREATE TABLE categoriasBase (
    categoriaId SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion VARCHAR(255),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE unidadesMedida (
    unidadMedidaId SERIAL PRIMARY KEY,
    nombre VARCHAR(30) UNIQUE NOT NULL,
    abreviatura VARCHAR(5),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE productosBase (
    productoBaseId SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    categoriaId INT REFERENCES categoriasBase(categoriaId),
    unidadMedidaId INT REFERENCES unidadesMedida(unidadMedidaId),
    descripcionTecnica VARCHAR(255),
    updatedAt TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

--------------------------------------------------------------------------------
-- 4. COMPRAS E INVENTARIO (HUB NICARAGUA)
--------------------------------------------------------------------------------

CREATE TABLE ordenesCompra (
    ordenCompraId SERIAL PRIMARY KEY,
    proveedorId INT NOT NULL REFERENCES proveedores(proveedorId),
    fechaEmision TIMESTAMPTZ DEFAULT NOW(),
    estado VARCHAR(20), -- 'Pendiente', 'Pagada', etc.
    monedaCompraId INT REFERENCES monedas(monedaId),
    tipoCambioAUSD NUMERIC(12,6),
    updatedAt TIMESTAMPTZ,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE ordenesCompraDetalle (
    detalleOCId SERIAL PRIMARY KEY,
    ordenCompraId INT NOT NULL REFERENCES ordenesCompra(ordenCompraId),
    productoBaseId INT NOT NULL REFERENCES productosBase(productoBaseId),
    cantidadPedida NUMERIC(12,2) NOT NULL,
    precioUnitarioMonedaOrigen NUMERIC(15,2) NOT NULL,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE lotesImportacion (
    loteId SERIAL PRIMARY KEY,
    codigoLote VARCHAR(50),
    detalleOCId INT REFERENCES ordenesCompraDetalle(detalleOCId),
    fechaProduccion DATE,
    fechaVencimiento DATE,
    createdAt TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE ubicacionesHub (
    ubicacionId SERIAL PRIMARY KEY,
    codigoPasillo VARCHAR(10),
    estante VARCHAR(10),
    nivel VARCHAR(10),
    capacidadMax NUMERIC(12,2),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (codigoPasillo, estante, nivel)
);

CREATE TABLE inventarioHub (
    inventarioId SERIAL PRIMARY KEY,
    loteId INT NOT NULL REFERENCES lotesImportacion(loteId),
    ubicacionId INT REFERENCES ubicacionesHub(ubicacionId),
    cantidadDisponible NUMERIC(12,2) DEFAULT 0,
    fechaArribo TIMESTAMPTZ,
    estadoCalidad VARCHAR(20),
    versionLock INT DEFAULT 0,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

--------------------------------------------------------------------------------
-- 5. COSTOS Y REQUISITOS LEGALES
--------------------------------------------------------------------------------

CREATE TABLE tiposCostoImportacion (
    tipoCostoId SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL,
    esEntrada BOOLEAN,
    descripcion VARCHAR(255),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE transaccionesCostos (
    transaccionId SERIAL PRIMARY KEY,
    ordenCompraId INT REFERENCES ordenesCompra(ordenCompraId),
    tipoCostoId INT REFERENCES tiposCostoImportacion(tipoCostoId),
    monedaOriginalId INT REFERENCES monedas(monedaId),
    montoOriginal NUMERIC(15,2),
    tipoCambioUSD NUMERIC(12,6),
    montoUSD NUMERIC(15,2),
    numeroDocumento VARCHAR(100),
    urlDocumento VARCHAR(512),
    hashDocumento VARCHAR(64),
    fechaTransaccion TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE tiposRequisitos (
    tipoRequisitoId SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE requisitosLegalesPais (
    requisitoId SERIAL PRIMARY KEY,
    tipoRequisitoId INT REFERENCES tiposRequisitos(tipoRequisitoId),
    productoBaseId INT REFERENCES productosBase(productoBaseId),
    paisDestinoId INT REFERENCES paises(paisId),
    nombreRequisito VARCHAR(150),
    urlDocumentoLegal VARCHAR(512),
    hashValidacion VARCHAR(64),
    ultimaRevision DATE,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

--------------------------------------------------------------------------------
-- 6. LOGÍSTICA DE SALIDA (DYNAMIC BRANDS)
--------------------------------------------------------------------------------

CREATE TABLE marcasBlancas (
    marcaId SERIAL PRIMARY KEY,
    nombreMarca VARCHAR(100) UNIQUE NOT NULL,
    logotipoUrl VARCHAR(512),
    paisSedeId INT REFERENCES paises(paisId),
    activo BOOLEAN DEFAULT TRUE,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE
);

CREATE TABLE couriers (
    courierId SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN DEFAULT TRUE
);

CREATE TABLE estadosTrazabilidad (
    estadoTrazabilidadId SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE trazabilidadMovimientos (
    movimientoId UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    inventarioId INT NOT NULL REFERENCES inventarioHub(inventarioId),
    ordenIdExterna INT, -- Ref a Dynamic Brands (MySQL)
    marcaId INT REFERENCES marcasBlancas(marcaId),
    paisDestinoId INT REFERENCES paises(paisId),
    courierId INT REFERENCES couriers(courierId),
    tipoMovimiento VARCHAR(50),
    cantidad NUMERIC(12,2),
    estadoTrazabilidadId INT REFERENCES estadosTrazabilidad(estadoTrazabilidadId),
    operarioId INT REFERENCES personas(personaId),
    fechaRegistro TIMESTAMPTZ DEFAULT NOW(),
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT
);

--------------------------------------------------------------------------------
-- 7. AUDITORÍA AVANZADA
--------------------------------------------------------------------------------

CREATE TABLE sources (
    sourceId SERIAL PRIMARY KEY,
    nombre VARCHAR(75) NOT NULL,
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMPTZ DEFAULT NOW(),
    fechaActualizacion TIMESTAMPTZ,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    checksum BYTEA
);

CREATE TABLE logTypes (
    logTypeId SERIAL PRIMARY KEY,
    nombre VARCHAR(75) NOT NULL,
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMPTZ DEFAULT NOW(),
    fechaActualizacion TIMESTAMPTZ,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    checksum BYTEA
);

CREATE TABLE eventTypes (
    eventTypeId SERIAL PRIMARY KEY,
    logTypeId INT NOT NULL REFERENCES logTypes(logTypeId),
    nombre VARCHAR(75) NOT NULL,
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMPTZ DEFAULT NOW(),
    fechaActualizacion TIMESTAMPTZ,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    checksum BYTEA
);

CREATE TABLE severities (
    severityId SERIAL PRIMARY KEY,
    nombre VARCHAR(75) NOT NULL,
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMPTZ DEFAULT NOW(),
    fechaActualizacion TIMESTAMPTZ,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    checksum BYTEA
);

CREATE TABLE dataObjects (
    dataObjectId SERIAL PRIMARY KEY,
    nombre VARCHAR(75) NOT NULL,
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMPTZ DEFAULT NOW(),
    fechaActualizacion TIMESTAMPTZ,
    actualizadoPor INT REFERENCES personas(personaId),
    computadoraId INT,
    deleted BOOLEAN DEFAULT FALSE,
    checksum BYTEA
);

CREATE TABLE logs (
    logId BIGSERIAL PRIMARY KEY,
    userId INT REFERENCES personas(personaId),
    eventTypeId INT REFERENCES eventTypes(eventTypeId),
    descripcion VARCHAR(500),
    sourceId INT REFERENCES sources(sourceId),
    severityId INT REFERENCES severities(severityId),
    referenceId1 BIGINT,
    referenceId2 BIGINT,
    referenceDesc1 VARCHAR(200),
    referenceDesc2 VARCHAR(200),
    dataObjectId1 INT REFERENCES dataObjects(dataObjectId),
    dataObjectId2 INT REFERENCES dataObjects(dataObjectId),
    fechaRegistro TIMESTAMPTZ DEFAULT NOW(),
    computadoraId INT,
    checksum BYTEA
);