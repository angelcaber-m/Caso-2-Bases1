Bases de Datos 1

Caso #2

Estudiantes:
Angélica Cabrera Bermúdez - 2024253434
Estefanía Portuguez Víquez -2024800621

-----------------------------------------
- Database engine: PostgreSQL
- Database name: EtheriaGlobal

- Descripción:
Esta empresa se encarga de la cadena de suministro. Importan productos naturales y curativos exóticos de todo el mundo (bebidas, alimentos, cosmética dermatológica, capilar, aromaterapia, jabones y aceites esenciales).
* Todos los productos son de gama alta y poseen propiedades medicinales/saludables.
* Se importan en "bulk" (cajas sin marca ni etiquetado) en dólares (USD).
* Todo llega a un centro logístico en la costa Caribe de Nicaragua.

-----------------------------------------

## Tables:

//Tablas de Catálogo y Localización - Estas tablas evitan la duplicidad de datos y permiten filtrar por origen y categoría.
## paises: Almacena los países donde se compran los insumos originales.
 - paisId: SERIAL (PK)
 - nombre: VARCHAR (100) UNIQUE
 - codigoISO: VARCHAR (5) UNIQUE
 - monedaLocalId: INT (FK) ->monedas -- Referencia a tabla monedas
 - activo: BOOLEAN
 - createdAt: TIMESTAMPTZ DEFAULT NOW()
 - actualizadoPor: INT (FK) -> personas
 - computadoraId: INT -- ID del terminal/estación
 - deleted: BOOLEAN DEFAULT FALSE
 
## provinciasEstados (NUEVA)
- provinciaEstadoId: SERIAL (PK)
- paisId: INT (FK) -> paises
- nombre: VARCHAR(100)
- codigoPostalOpcional: VARCHAR(20)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## ciudades (NUEVA)
- ciudadId: SERIAL (PK)
- provinciaEstadoId: INT (FK) -> provinciasEstados
- nombre: VARCHAR(100)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## direcciones
- direccionId: SERIAL (PK)
- ciudadId: INT (FK) -> ciudades //Eliminé paisId y provinciaEstado de aquí porque ya se obtienen a través de ciudadId (Normalización).
- detalles: VARCHAR(255) 
- updatedAt: TIMESTAMPTZ //Para rastrear cambios de domicilio
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## personas
- personaId: SERIAL (PK)
- cedulaIdentidad: VARCHAR(50) UNIQUE
- nombre: VARCHAR(100)
- primerApellido: VARCHAR(100)
- segundoApellido: VARCHAR(100)
- email: VARCHAR(150) UNIQUE
- telefono: VARCHAR(20)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## monedas
- monedaId: SERIAL (PK)
- nombre: VARCHAR(50) UNIQUE
- codigoISO: VARCHAR(3) UNIQUE -- Ej: USD, CRC, NIO
- simbolo: VARCHAR(5)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## exchangeRates
- exchangeRateId: SERIAL (PK)
- monedaOrigenId: INT (FK) -> monedas (La moneda que quieres convertir)
- monedaDestinoId: INT (FK) -> monedas (Generalmente USD, pero se deja flexible)
- valorCompra: NUMERIC(12,6) -- Cantidad de moneda origen para comprar 1 unidad de destino
- valorVenta: NUMERIC(12,6)
- fechaRegistro: TIMESTAMPTZ DEFAULT NOW() -- Fecha y hora exacta de la tasa
- fechaEfectiva: DATE -- La fecha para la cual aplica esta tasa (útil para tasas oficiales de bancos)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE



//Entidades y productos
## proveedores: Empresas internacionales que suministran los productos en granel.
- proveedorId: SERIAL (PK)
- cedulaJuridica: VARCHAR(50) UNIQUE
- nombreComercial: VARCHAR(150)
- direccionId: INT (FK) -> direcciones
- telefonoOficina: VARCHAR(20)
- activo: BOOLEAN
- createdAt: TIMESTAMPTZ DEFAULT NOW()
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## proveedoresContactosLegales: (N a N) //REVISAR ESTA TABLA PORQUE ES NUEVA
- proveedorId: INT (FK) -> proveedores
- personaId: INT (FK) -> personas
- rol: VARCHAR(50) -- Ej: 'Representante Legal', 'Agente Aduanero'
- PRIMARY KEY (proveedorId, personaId)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

//Gestión de Productos e Inventario (Sourcing)
//Enfocada en el almacenamiento en el HUB de Nicaragua y la gestión de costos en dólares.
## categoriasBase REVISAR TABLA ES NUEVA
- categoriaId: SERIAL (PK)
- nombre: VARCHAR(100) UNIQUE
- descripcion: VARCHAR(255)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## unidadesMedida: Define las unidades para el manejo de bulk (Litros, Kilogramos, Unidades).
- unidadMedidaId: SERIAL (PK)
- nombre: VARCHAR (30) UNIQUE -- Ej: 'Litros'
- abreviatura: VARCHAR (5) -- Ej: 'L'
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## productosBase: El producto sin marca (ej. Aceite de Lavanda puro).
- productoBaseId: SERIAL (PK)
- nombre: VARCHAR(150)
- categoriaId: INT (FK) -> categoriasBase
- unidadMedidaId: INT (FK)-> unidadesMedida
- descripcionTecnica: VARCHAR(255)
- updatedAt: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## ubicacionesHub REVISAR TABLA NUEVA
- ubicacionId: SERIAL (PK)
- codigoPasillo: VARCHAR(10)
- estante: VARCHAR(10)
- nivel: VARCHAR(10)
- capacidadMax: NUMERIC(12,2)
- UNIQUE (codigoPasillo, estante, nivel) -- Evita duplicidad de espacio físico
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

//Compras e Inventario (Patrón Transaccional)
Separación de Orden de Compra (OC) e Inventario real (Firme) tras arribo.

## ordenesCompra TABLA NUEVA
- ordenCompraId: SERIAL (PK)
- proveedorId: INT (FK) -> proveedores
- fechaEmision: TIMESTAMPTZ
- estado: VARCHAR(20) -- 'Pendiente', 'Pagada', 'En Transito', 'Recibida', 'Devuelta'
- monedaCompraId: INT (FK) -> monedas
- tipoCambioAUSD: NUMERIC(12,6)
- updatedAt: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## ordenesCompraDetalle TABLA NUEVA
- detalleOCId: SERIAL (PK)
- ordenCompraId: INT (FK)
- productoBaseId: INT (FK)
- cantidadPedida: NUMERIC(12,2)
- precioUnitarioMonedaOrigen: NUMERIC(15,2)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## lotesImportacion TABLA NUEVA
- loteId: SERIAL (PK)
- codigoLote: VARCHAR(50) -- Del proveedor
- detalleOCId: INT (FK) -> ordenesCompraDetalle
- fechaProduccion: DATE
- fechaVencimiento: DATE
- createdAt: TIMESTAMPTZ DEFAULT NOW()
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE


## inventarioHub (Registro de Stock Real) TABLA NUEVA
- inventarioId: SERIAL (PK)
- loteId: INT (FK) -> lotesImportacion
- ubicacionId: INT (FK) -> ubicacionesHub
- cantidadDisponible: NUMERIC(12,2) -- Solo se llena cuando llega al HUB
- fechaArribo: TIMESTAMPTZ
- estadoCalidad: VARCHAR(20)
- versionLock: INT DEFAULT 0 //Para control de concurrencia (evita errores en ventas simultáneas)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE //Para dar de baja stock por daño/pérdida


//Costos y Finanzas (Patrón de Transacciones)
//Manejo de entradas/salidas de dinero y documentos legales (DUA).
## tiposCostoImportacion NUEVA TABLA
- tipoCostoId: SERIAL (PK)
- nombre: VARCHAR(50) UNIQUE
- esEntrada: BOOLEAN -- Para diferenciar ingresos/egresos
- descripcion: VARCHAR(255)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## transaccionesCostos (Patrón de Transacción) NUEVA TABLA
- transaccionId: SERIAL (PK)
- ordenCompraId: INT (FK) -> ordenesCompra
- tipoCostoId: INT (FK) -> tiposCostoImportacion
- monedaOriginalId: INT (FK) -> monedas
- montoOriginal: NUMERIC(15,2)
- tipoCambioUSD: NUMERIC(12,6)
- montoUSD: NUMERIC(15,2) -- Calculado
- numeroDocumento: VARCHAR(100) -- Referencia a DUA, Factura o Comprobante
- urlDocumento: VARCHAR(512)
- hashDocumento: VARCHAR(64) -- Checksum (SHA-256) para integridad del DUA
- fechaTransaccion: TIMESTAMPTZ DEFAULT NOW()
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE


//Logística de Salida y Cumplimiento
//Conexión con Dynamic Brands y requisitos legales por país.
## tiposRequisitos (NUEVA)
// Para clasificar si el documento es de salud, aduanero o técnico.
- tipoRequisitoId: SERIAL (PK)
- nombre: VARCHAR(100) -- Ej: 'Registro Sanitario', 'Certificado Libre Venta'
- descripcion: VARCHAR(255)
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## requisitosLegalesPais NUEVA TABLA
- requisitoId: SERIAL (PK)
- tipoRequisitoId: INT (FK) -> tiposRequisitos
- productoBaseId: INT (FK) -> productosBase
- paisDestinoId: INT (FK) -> paises
- nombreRequisito: VARCHAR(150)
- urlDocumentoLegal: VARCHAR(512)
- hashValidacion: VARCHAR(64) -- Checksum
- ultimaRevision: DATE
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## marcasBlancas (NUEVA)
// Esta tabla es el puente con Dynamic Brands. Registra las marcas que la IA crea.
- marcaId: SERIAL (PK)
- nombreMarca: VARCHAR(100) UNIQUE
- logotipoUrl: VARCHAR(512)
- paisSedeId: INT (FK) -> paises
- activo: BOOLEAN DEFAULT TRUE
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE

## estadosTrazabilidad NUEVA TABLA
- estadoTrazabilidadId: SERIAL (PK)
- nombre: VARCHAR(50) -- 'Recibido', 'En Proceso Etiquetado', 'Listo para Courier'

## trazabilidadMovimientos (Log de Inventario) NUEVA TABLA
- movimientoId: (UUID PK)
- inventarioId: INT (FK) -> inventarioHub
- ordenIdExterna: INT -- Referencia a Dynamic Brands (MySQL)
- marcaId: INT (FK) -> marcasBlancas (Para saber qué etiqueta usar)
- paisDestinoId: INT (FK) -> paises (Para saber qué requisitos legales aplican al empaque)
- courierId: INT (FK) -> couriers
- tipoMovimiento: VARCHAR(50) -- 'Recepcion', 'Etiquetado', 'Despacho', 'Ajuste'
- cantidad: NUMERIC(12,2)
- estadoTrazabilidadId: INT (FK)-> estadosTrazabilidad
- operarioId: INT (FK) ->personas
- fechaRegistro: TIMESTAMPTZ DEFAULT NOW()
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT


//Auditoría de Sistema
//Control técnico de la ejecución de procesos.
## sources (Orígenes de los eventos)
- sourceId: SERIAL (PK)
- nombre: VARCHAR(75) -- Ej: 'App Móvil', 'Portal Web', 'API Sourcing'
- descripcion: VARCHAR(200)
- fechaCreacion: TIMESTAMPTZ DEFAULT NOW()
- fechaActualizacion: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE
- checksum: BYTEA -- Formato binario para integridad en Postgres

## logTypes (Categorías generales de logs)
- logTypeId: SERIAL (PK)
- nombre: VARCHAR(75) -- Ej: 'Seguridad', 'Transaccional', 'Sistema'
- descripcion: VARCHAR(200)
- fechaCreacion: TIMESTAMPTZ DEFAULT NOW()
- fechaActualizacion: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE
- checksum: BYTEA

## eventTypes (Tipos de eventos específicos) 
- eventTypeId: SERIAL (PK)
- logTypeId: INT (FK) -> logTypes
- nombre: VARCHAR(75) -- Ej: 'Login Exitoso', 'Error de Inventario'
- descripcion: VARCHAR(200)
- fechaCreacion: TIMESTAMPTZ DEFAULT NOW()
- fechaActualizacion: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE
- checksum: BYTEA

## severities (Niveles de importancia)
- severityId: SERIAL (PK)
- nombre: VARCHAR(75) -- Ej: 'Crítico', 'Error', 'Advertencia', 'Info'
- descripcion: VARCHAR(200)
- fechaCreacion: TIMESTAMPTZ DEFAULT NOW()
- fechaActualizacion: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE
- checksum: BYTEA

## dataObjects (Catálogo de tablas/objetos del sistema)
- dataObjectId: SERIAL (PK)
- nombre: VARCHAR(75) -- Ej: 'ordenesCompra', 'inventarioHub'
- descripcion: VARCHAR(200)
- fechaCreacion: TIMESTAMPTZ DEFAULT NOW()
- fechaActualizacion: TIMESTAMPTZ
- actualizadoPor: INT (FK) -> personas
- computadoraId: INT
- deleted: BOOLEAN DEFAULT FALSE
- checksum: BYTEA

## logs (Registro histórico de actividad)
- logId: BIGSERIAL (PK)
- userId: INT (FK) -> personas
- eventTypeId: INT (FK) -> eventTypes
- descripcion: VARCHAR(500)
- sourceId: INT (FK) -> sources
- severityId: INT (FK) -> severities
- referenceId1: BIGINT NULL -- ID del registro afectado (ej: id de una factura)
- referenceId2: BIGINT NULL
- referenceDesc1: VARCHAR(200) NULL
- referenceDesc2: VARCHAR(200) NULL
- dataObjectId1: INT (FK) -> dataObjects NULL
- dataObjectId2: INT (FK) -> dataObjects NULL
- fechaRegistro: TIMESTAMPTZ DEFAULT NOW()
- computadoraId: INT
- checksum: BYTEA

 

