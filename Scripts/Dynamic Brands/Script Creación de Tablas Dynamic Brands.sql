CREATE DATABASE IF NOT EXISTS DynamicBrands;
USE DynamicBrands;

-- ==========================================
-- 1. TABLAS DE CATÁLOGO (UBICACIÓN Y MONEDA)
-- ==========================================

CREATE TABLE paises (
    paisId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(75) NOT NULL,
    codigoISO VARCHAR(3),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE estados (
    estadoId INT AUTO_INCREMENT PRIMARY KEY,
    paisId INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_estados_paises FOREIGN KEY (paisId) REFERENCES paises(paisId)
) ENGINE=InnoDB;

CREATE TABLE ciudades (
    ciudadId INT AUTO_INCREMENT PRIMARY KEY,
    estadoId INT NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_ciudades_estados FOREIGN KEY (estadoId) REFERENCES estados(estadoId)
) ENGINE=InnoDB;

CREATE TABLE direcciones (
    direccionId INT AUTO_INCREMENT PRIMARY KEY,
    ciudadId INT NOT NULL,
    codigoPostal VARCHAR(10),
    primeraLinea VARCHAR(150),
    segundaLinea VARCHAR(150),
    postTime TIMESTAMP,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_direcciones_ciudades FOREIGN KEY (ciudadId) REFERENCES ciudades(ciudadId)
) ENGINE=InnoDB;

CREATE TABLE monedas (
    monedaId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(75) NOT NULL,
    simbolo VARCHAR(5),
    codigoISO VARCHAR(3),
    paisId INT, -- Referencia lógica
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE exchangeRates (
    exchangeRateId INT AUTO_INCREMENT PRIMARY KEY,
    monedaOrigenId INT NOT NULL,
    monedaDestinoId INT NOT NULL,
    exchangeRate DECIMAL(18,6) NOT NULL,
    esActual BOOLEAN DEFAULT 1,
    validFrom TIMESTAMP,
    validTo TIMESTAMP,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    checksum VARBINARY(255),
    CONSTRAINT fk_ex_monedaO FOREIGN KEY (monedaOrigenId) REFERENCES monedas(monedaId),
    CONSTRAINT fk_ex_monedaD FOREIGN KEY (monedaDestinoId) REFERENCES monedas(monedaId)
) ENGINE=InnoDB;

-- ==========================================
-- 2. TABLAS DE APOYO TÉCNICO Y ESTADOS
-- ==========================================

CREATE TABLE tiposDeDatosAtributos (
    tipoDeDatoAtributoId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(15),
    descripcion VARCHAR(150),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE unidadesDeMedida (
    unidadDeMedidaId INT AUTO_INCREMENT PRIMARY KEY,
    medida VARCHAR(30),
    abreviacion VARCHAR(10),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE estadosOrden (
    estadoOrdenId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20),
    descripcion VARCHAR(150),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE estadosEnvio (
    estadoEnvioId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(20),
    descripcion VARCHAR(150),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE eventosEnvio (
    eventoEnvioId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50),
    descripcion VARCHAR(150),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

-- ==========================================
-- 3. NÚCLEO DE IA Y PRODUCTOS
-- ==========================================

CREATE TABLE tiendas (
    tiendaId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    dominio VARCHAR(255),
    paisId INT, -- Referencia lógica
    monedaId INT NOT NULL,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_tiendas_moneda FOREIGN KEY (monedaId) REFERENCES monedas(monedaId)
) ENGINE=InnoDB;

CREATE TABLE conceptosTiendas (
    conceptoTiendaId INT AUTO_INCREMENT PRIMARY KEY,
    tiendaId INT NOT NULL,
    descripcion VARCHAR(500),
    apariencia JSON,
    logoURL VARCHAR(255),
    enfoqueMarketing JSON,
    version INT,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_conceptos_tienda FOREIGN KEY (tiendaId) REFERENCES tiendas(tiendaId)
) ENGINE=InnoDB;

CREATE TABLE productosMarcasBlancas (
    productoMarcaBlancaId INT AUTO_INCREMENT PRIMARY KEY,
    tiendaId INT NOT NULL,
    productoBaseId INT, -- Referencia lógica a otra BD
    nombreComercial VARCHAR(50),
    unidadDeMedidaId INT NOT NULL,
    descripcion VARCHAR(200),
    fotoURL VARCHAR(255),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_pmb_tienda FOREIGN KEY (tiendaId) REFERENCES tiendas(tiendaId),
    CONSTRAINT fk_pmb_unidad FOREIGN KEY (unidadDeMedidaId) REFERENCES unidadesDeMedida(unidadDeMedidaId)
) ENGINE=InnoDB;

CREATE TABLE atributos (
    atributoId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(30),
    descripcion VARCHAR(150),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE valoresDeAtributos (
    productoMarcaBlancaId INT NOT NULL,
    atributoId INT NOT NULL,
    valor VARCHAR(30),
    tipoDeDatoAtributoId INT NOT NULL,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    PRIMARY KEY (productoMarcaBlancaId, atributoId),
    CONSTRAINT fk_va_pmb FOREIGN KEY (productoMarcaBlancaId) REFERENCES productosMarcasBlancas(productoMarcaBlancaId),
    CONSTRAINT fk_va_atrib FOREIGN KEY (atributoId) REFERENCES atributos(atributoId),
    CONSTRAINT fk_va_tipo FOREIGN KEY (tipoDeDatoAtributoId) REFERENCES tiposDeDatosAtributos(tipoDeDatoAtributoId)
) ENGINE=InnoDB;

-- ==========================================
-- 4. VENTAS Y LOGÍSTICA
-- ==========================================

CREATE TABLE clientes (
    clienteId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50),
    primerApellido VARCHAR(50),
    segundoApellido VARCHAR(50),
    correo VARCHAR(100) UNIQUE,
    telefono VARCHAR(20),
    contrasena VARBINARY(255),
    fechaDeRegistro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE ordenes (
    ordenId INT AUTO_INCREMENT PRIMARY KEY,
    tiendaId INT NOT NULL,
    clienteId INT NOT NULL,
    estadoOrdenId INT NOT NULL,
    monedaId INT NOT NULL,
    direccionEnvioId INT NOT NULL, -- Nueva columna para la logística de entrega
    montoLocal DECIMAL(18,6),
    monto DECIMAL(18,6),
    exchangeRateId INT,
    notas VARCHAR(300),
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    checksum VARBINARY(255),
    CONSTRAINT fk_ord_tienda FOREIGN KEY (tiendaId) REFERENCES tiendas(tiendaId),
    CONSTRAINT fk_ord_cliente FOREIGN KEY (clienteId) REFERENCES clientes(clienteId),
    CONSTRAINT fk_ord_estado FOREIGN KEY (estadoOrdenId) REFERENCES estadosOrden(estadoOrdenId),
    CONSTRAINT fk_ord_moneda FOREIGN KEY (monedaId) REFERENCES monedas(monedaId),
    CONSTRAINT fk_ord_exrate FOREIGN KEY (exchangeRateId) REFERENCES exchangeRates(exchangeRateId),
    CONSTRAINT fk_ord_direccion FOREIGN KEY (direccionEnvioId) REFERENCES direcciones(direccionId)
) ENGINE=InnoDB;

CREATE TABLE productosOrdenes (
    productoOrdenId INT AUTO_INCREMENT PRIMARY KEY,
    ordenId INT NOT NULL,
    productoMarcaBlancaId INT NOT NULL,
    cantidad DECIMAL(12,2),
    monedaId INT NOT NULL,
    precioUnitario DECIMAL(10,2),
    montoLocal DECIMAL(18,6),
    monto DECIMAL(18,6),
    exchangeRateId INT,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    checksum VARBINARY(255),
    CONSTRAINT fk_po_orden FOREIGN KEY (ordenId) REFERENCES ordenes(ordenId),
    CONSTRAINT fk_po_pmb FOREIGN KEY (productoMarcaBlancaId) REFERENCES productosMarcasBlancas(productoMarcaBlancaId),
    CONSTRAINT fk_po_moneda FOREIGN KEY (monedaId) REFERENCES monedas(monedaId),
    CONSTRAINT fk_po_exrate FOREIGN KEY (exchangeRateId) REFERENCES exchangeRates(exchangeRateId)
) ENGINE=InnoDB;

CREATE TABLE couriers (
    courierId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150),
    ceduldaJuridica VARCHAR(12),
    direccionId INT NOT NULL,
    numeroTelefono VARCHAR(20),
    correo VARCHAR(100),
    sitioWebURL VARCHAR(255),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_courier_dir FOREIGN KEY (direccionId) REFERENCES direcciones(direccionId)
) ENGINE=InnoDB;

CREATE TABLE envios (
    envioId INT AUTO_INCREMENT PRIMARY KEY,
    ordenId INT NOT NULL,
    courierId INT NOT NULL,
    numeroGuia VARCHAR(100),
    estadoEnvioId INT NOT NULL,
    fechaDespacho TIMESTAMP,
    fechaEstimadaEntrega TIMESTAMP,
    fechaRealEntrega TIMESTAMP NULL,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    completado BOOLEAN DEFAULT 0,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_env_orden FOREIGN KEY (ordenId) REFERENCES ordenes(ordenId),
    CONSTRAINT fk_env_courier FOREIGN KEY (courierId) REFERENCES couriers(courierId),
    CONSTRAINT fk_env_estado FOREIGN KEY (estadoEnvioId) REFERENCES estadosEnvio(estadoEnvioId)
) ENGINE=InnoDB;

CREATE TABLE rastreosEnvios (
    rastreoEnvioId INT AUTO_INCREMENT PRIMARY KEY,
    envioId INT NOT NULL, -- Requerido para integridad física
    eventoEnvioId INT NOT NULL,
    direccionId INT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    registradoPor INT,
    dispositivo INT,
    comentario VARCHAR(200),
    checksum VARBINARY(255),
    CONSTRAINT fk_rast_envio FOREIGN KEY (envioId) REFERENCES envios(envioId),
    CONSTRAINT fk_rast_evento FOREIGN KEY (eventoEnvioId) REFERENCES eventosEnvio(eventoEnvioId),
    CONSTRAINT fk_rast_dir FOREIGN KEY (direccionId) REFERENCES direcciones(direccionId)
) ENGINE=InnoDB;

CREATE TABLE instruccionesEtiquetas (
    instruccionEtiquetaId INT AUTO_INCREMENT PRIMARY KEY,
    productoMarcaBlancaId INT NOT NULL,
    especificacionesTecnicas JSON,
    registroSanitario VARCHAR(100),
    advertenciasConsumo VARCHAR(500),
    detalleIngredientes VARCHAR(500),
    fechaCaducidad DATE,
    envioId INT,
    trazabilidadId INT, -- Referencia lógica
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_etiq_pmb FOREIGN KEY (productoMarcaBlancaId) REFERENCES productosMarcasBlancas(productoMarcaBlancaId),
    CONSTRAINT fk_etiq_envio FOREIGN KEY (envioId) REFERENCES envios(envioId)
) ENGINE=InnoDB;

CREATE TABLE costosLogistica (
    costoLogisticaId INT AUTO_INCREMENT PRIMARY KEY,
    envioId INT NOT NULL,
    tipoCostoId INT,
    monedaId INT NOT NULL,
    montoLocal DECIMAL(18,6),
    monto DECIMAL(18,6),
    exchangeRateId INT,
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    activo BOOLEAN DEFAULT 1,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_cost_envio FOREIGN KEY (envioId) REFERENCES envios(envioId),
    CONSTRAINT fk_cost_moneda FOREIGN KEY (monedaId) REFERENCES monedas(monedaId),
    CONSTRAINT fk_cost_exrate FOREIGN KEY (exchangeRateId) REFERENCES exchangeRates(exchangeRateId)
) ENGINE=InnoDB;

-- ==========================================
-- 5. HISTORIALES Y AUDITORÍA
-- ==========================================

CREATE TABLE exchangeHistory (
    exchangeHistoryId INT AUTO_INCREMENT PRIMARY KEY,
    fechaInicio TIMESTAMP,
    fechaFin TIMESTAMP,
    exchangeRateId INT NOT NULL,
    exchangeRate DECIMAL(18,6),
    monedaOrigenId INT NOT NULL,
    monedaDestinoId INT NOT NULL,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    checksum VARBINARY(255),
    CONSTRAINT fk_eh_exrate FOREIGN KEY (exchangeRateId) REFERENCES exchangeRates(exchangeRateId),
    CONSTRAINT fk_eh_monO FOREIGN KEY (monedaOrigenId) REFERENCES monedas(monedaId),
    CONSTRAINT fk_eh_monD FOREIGN KEY (monedaDestinoId) REFERENCES monedas(monedaId)
) ENGINE=InnoDB;

CREATE TABLE historialEstadosOrdenes (
    historialEstadoOrdenId INT AUTO_INCREMENT PRIMARY KEY,
    ordenId INT NOT NULL,
    estadoAnteriorId INT,
    estadoNuevoId INT,
    rastreoEnvioId INT,
    comentario VARCHAR(200),
    fechaRegistro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    registradoPor INT,
    dispositivo INT,
    checksum VARBINARY(255),
    CONSTRAINT fk_heo_orden FOREIGN KEY (ordenId) REFERENCES ordenes(ordenId),
    CONSTRAINT fk_heo_estA FOREIGN KEY (estadoAnteriorId) REFERENCES estadosOrden(estadoOrdenId),
    CONSTRAINT fk_heo_estN FOREIGN KEY (estadoNuevoId) REFERENCES estadosOrden(estadoOrdenId),
    CONSTRAINT fk_heo_rast FOREIGN KEY (rastreoEnvioId) REFERENCES rastreosEnvios(rastreoEnvioId)
) ENGINE=InnoDB;

CREATE TABLE historialCostosLogistica (
    historialCostoLogisticaId INT AUTO_INCREMENT PRIMARY KEY,
    costoLogisticaId INT NOT NULL,
    monedaLocal INT,
    exchangeRateId INT,
    montoLocalAnterior DECIMAL(18,6),
    montoAnterior DECIMAL(18,6),
    montoLocalNuevo DECIMAL(18,6),
    montoNuevo DECIMAL(18,6),
    comentario VARCHAR(200),
    fechaRegistro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    registradoPor INT,
    dispositivo INT,
    checksum VARBINARY(255),
    CONSTRAINT fk_hcl_costo FOREIGN KEY (costoLogisticaId) REFERENCES costosLogistica(costoLogisticaId),
    CONSTRAINT fk_hcl_moneda FOREIGN KEY (monedaLocal) REFERENCES monedas(monedaId),
    CONSTRAINT fk_hcl_exrate FOREIGN KEY (exchangeRateId) REFERENCES exchangeRates(exchangeRateId)
) ENGINE=InnoDB;

-- ==========================================
-- 6. PATRÓN DE LOGS
-- ==========================================

CREATE TABLE sources (
    sourceId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(75),
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE logTypes (
    logTypeId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(75),
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE eventTypes (
    eventTypeId INT AUTO_INCREMENT PRIMARY KEY,
    logTypeId INT NOT NULL,
    nombre VARCHAR(75),
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255),
    CONSTRAINT fk_et_type FOREIGN KEY (logTypeId) REFERENCES logTypes(logTypeId)
) ENGINE=InnoDB;

CREATE TABLE severities (
    severityId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(75),
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE dataObjects (
    dataObjectId INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(75),
    descripcion VARCHAR(200),
    fechaCreacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fechaActualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    actualizadoPor INT,
    computadora INT,
    deleted BOOLEAN DEFAULT 0,
    checksum VARBINARY(255)
) ENGINE=InnoDB;

CREATE TABLE logs (
    logId BIGINT AUTO_INCREMENT PRIMARY KEY,
    userId INT, -- Referencia lógica
    eventTypeId INT NOT NULL,
    descripcion VARCHAR(500),
    sourceId INT NOT NULL,
    severityId INT NOT NULL,
    referenceId1 BIGINT NULL,
    referenceId2 BIGINT NULL,
    referenceDesc1 VARCHAR(200) NULL,
    referenceDesc2 VARCHAR(200) NULL,
    dataObjectId1 INT NULL,
    dataObjectId2 INT NULL,
    fechaRegistro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    computadora INT,
    checksum VARBINARY(255),
    CONSTRAINT fk_logs_event FOREIGN KEY (eventTypeId) REFERENCES eventTypes(eventTypeId),
    CONSTRAINT fk_logs_source FOREIGN KEY (sourceId) REFERENCES sources(sourceId),
    CONSTRAINT fk_logs_severity FOREIGN KEY (severityId) REFERENCES severities(severityId),
    CONSTRAINT fk_logs_do1 FOREIGN KEY (dataObjectId1) REFERENCES dataObjects(dataObjectId),
    CONSTRAINT fk_logs_do2 FOREIGN KEY (dataObjectId2) REFERENCES dataObjects(dataObjectId)
) ENGINE=InnoDB;
