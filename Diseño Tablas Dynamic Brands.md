Bases de Datos 1

Caso #2

Estudiantes:
Angélica Cabrera Bermúdez - 2024253434
Estefanía Portuguez Víquez - 2024800621

-----------------------------------------
- Database engine: MySQL 9.7
- Database name: DynamicBrands

- Descripción:
Esta es una empresa de base tecnológica. Han desarrollado una IA capaz de generar sitios de e-commerce dinámicos. 
* A partir de parámetros (logo, enfoque, país), la IA despliega tiendas virtuales con marcas blancas. 
* Pueden abrir y cerrar "N" sitios en diferentes países de Latam con un solo clic, cada uno con un enfoque de marketing y mensajes distintos para el mismo producto base.

-----------------------------------------

---------------------------------
---Datos Auditoria---
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)
---------------------------------

## Tables:
// Tablas de Catálogo
### paises
- paisId: serial auto-increment (PK)
- nombre: varchar(75)
- codigoISO: varchar(3)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### estados
- estadoId: serial auto-increment (PK)
- paisId: (FK)
- nombre: varchar(50)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### ciudades
- ciudadId: serial auto-increment (PK)
- estadoId: (FK)
- nombre: varchar(50)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### direcciones
- direccionId: serial auto-increment (PK)
- ciudadId: (FK)
- codigoPostal: varchar(10)
- primeraLinea: varchar(150)
- segundaLinea: varchar(150)
- postTime: timestamp
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### monedas
- monedaId: serial auto-increment (PK)
- nombre: varchar(75)
- simbolo: varchar(5)
- codigoISO: varchar(3)
- paisId: FK
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### exchangeRates
- exchangeRateId: serial auto-increment (PK)
- monedaOrigenId: FK (a monedas)
- monedaDestinoId: FK (a monedas)
- exchangeRate: decimal(18,6)
- esActual: boolean
- validFrom: timestamp
- validTo: timestamp
- fechaCreacion: timestamp
- checksum: varbinary(255)

### tiposDeDatosAtributos
- tipoDeDatoAtributoId: serial auto-increment (PK)
- nombre: varchar(15)
- descripcion: varchar (150)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### unidadesDeMedida
- unidadDeMedidaId: serial auto-increment (PK)
- medida: VARCHAR(30)
- abreviación: VARCHAR(10)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### estadosOrden //Pendiente, empacado, enviado, ...
- estadoOrdenId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### estadosEnvio //En almacen, en transito, entregado, ...
- estadoEnvioId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### eventosEnvio //Recibido en ___, entregado a __, ... 
- eventoEnvioId: serial auto-increment (PK)
- nombre: varchar(50)
- descripcion: varchar (150)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

// Tablas para el núcleo de la IA y los sitios web (Permiten configuraciones variables)
### tiendas
- tiendaId: serial auto-increment (PK)
- nombre: varchar(50)
- dominio: varchar(255)
- paisId: FK
- monedaId: FK
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### conceptosTiendas
- conceptoTiendaId: serial auto-increment (PK)
- tiendaId: FK
- descripcion: varchar(500)
- apariencia: JSON
- logoURL: varchar(255)
- enfoqueMarketing: JSON
- version: int
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### productosMarcasBlancas //Prodcutos específicos de la tienda creada por la IA
- productoMarcaBlancaId: serial auto-increment (PK)
- tiendaId: FK
- productoBaseId: int
- nombreComercial: varchar(50)
- unidadDeMedidaId: FK
- descripcion: varchar(200)
- fotoURL: varchar(255)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

// Tablas para flexibilidad de producto (Con el uso del modelo EAV)
### atributos
- atributoId: serial auto-increment (PK)
- nombre: varchar(30)
- descripcion: varchar (150)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### valoresDeAtributos
- valorDeAtributoId: (productoMarcaBlancaId (FK), atributoId (FK)) (PK)
- valor: varchar(30)
- tipoDeDatoAtributoId: FK
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

// Tablas para ventas y logística de salida
### clientes
- clienteId: serial auto-increment (PK)
- nombre: varchar(50)
- primerApellido: varchar(50)
- segundoApellido: varchar(50)
- correo: varchar(100) unique
- telefono: varchar(20)
- contraseña: varbinary(255)
- fechaDeRegistro: timestamp
- fechaActualizacion: timestamp
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### ordenes 
- ordenId: serial auto-increment (PK)
- tiendaId: FK
- clienteId: FK
- estadoOrdenId: FK
- monedaId: FK
- montoLocal: decimal(18, 6)
- montoUSD: decimal(18, 6)
- exchangeRateId: FK
- notas: varchar(300)
- direccionEnvioId: Fk (a direcciones) 
- activo: boolean default 1
- deleted: boolean default 0
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- checksum: varbinary(255)

### productosOrdenes
- productoOrdenId: serial auto-increment (PK)
- ordenId: FK
- productoMarcaBlancaId: FK
- cantidad: numeric(12,2)
- monedaId: FK
- precioUnitario: numeric(10,2)
- montoLocal: decimal(18, 6)
- montoUSD: decimal(18, 6)
- exchangeRateId: FK
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- checksum: varbinary(255)

### couriers
- courierId: serial auto-increment (PK)
- nombre: varchar(150)
- ceduldaJuridica: varchar(12)
- direccionId: FK
- numeroTelefono: varchar(20)
- correo: varchar(100)
- sitioWebURL: varchar(255)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### envios
- envioId: serial auto-increment (PK)
- ordenId: FK
- courierId: FK
- numeroGuia: varchar(100)
- estadoEnvioId: FK
- fechaDespacho: timestamp
- fechaEstimadaEntrega: timestamp
- fechaRealEntrega: timestamp null
- fechaActualizacion: timestamp
- completado: boolean default 0
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

### rastreosEnvios
- rastreoEnvioId: serial auto-increment (PK)
- envioId: FK
- eventoEnvioId: FK
- direccionId: FK
- fecha: timestamp
- registradoPor: int
- dispositivo: int
- comentario: varchar(200)
- checksum: varbinary(255)

### instruccionesEtiquetas:
- instruccionEtiquetaId: serial auto-increment (PK)
- productoMarcaBlancaId: FK
- especificacionesTecnicas: JSON
- registroSanitario: varchar(100)
- advertenciasConsumo: varchar(500)
- detalleIngredientes: varchar(500)
- fechaCaducidad: date
- envioId: FK
- trazabilidadId: int
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### costosLogistica
- costoLogisticaId: serial auto-increment (PK)
- envioId: FK
- tipoCostoId: int
- monedaId: FK
- montoLocal: decimal(18, 6)
- montoUSD: decimal(18, 6)
- exchangeRateId: FK
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- activo: boolean default 1
- deleted: boolean default 0
- checksum: varbinary(255)

// Tablas para logs y history
### exchangeHistory
- exchangeHistoryId: serial auto-increment (PK)
- fechaInicio: timestamp
- fechaFin: timestamp
- exchangeRateId: FK
- exchangeRate: decimal(18,6)
- monedaOrigenId: FK (a monedas)
- monedaDestinoId: FK (a monedas)
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- checksum: varbinary(255)

### historialEstadosOrdenes
- historialEstadoOrdenId: serial auto-increment (PK)
- ordenId: FK
- estadoAnteriorId: FK a la tabla estadosOrden
- estadoNuevoId: FK a la tabla estadosOrden
- rastreoEnvioId: FK
- comentario: varchar (150)
- fechaRegistro: timestamp
- registradoPor: int
- dispositivo: int
- comentario: varchar(200)
- checksum: varbinary(255)

### historialCostosLogistica
- historialCostoLogisticaId: serial auto-increment (PK)
- costoLogisticaId: FK
- monedaLocal: FK (a monedas)
- exchangeRateId: FK
- montoLocalAnterior: decimal(18, 6)
- montoUSDAnterior: decimal(18, 6)
- montoLocalNuevo: decimal(18, 6)
- montoUSDNuevo: decimal(18, 6)
- comentario: varchar (150)
- fechaRegistro: timestamp
- registradoPor: int
- dispositivo: int
- comentario: varchar(200)
- checksum: varbinary(255)

### sources
- sourceId: serial auto-increment (PK)
- nombre: varchar(75)
- descripcion: varchar(200)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### logTypes
- logTypeId: serial auto-increment (PK)
- nombre: varchar(75)
- descripcion: varchar(200)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### eventTypes
- eventTypeId: serial auto-increment (PK)
- logTypeId: FK
- nombre: varchar(75)
- descripcion: varchar(200)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### severities
- severityId: serial auto-increment (PK)
- nombre: varchar(75)
- descripcion: varchar(200)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### dataObjects
- dataObjectId: serial auto-increment (PK)
- nombre: varchar(75)
- descripcion: varchar(200)
- fechaCreacion: timestamp
- fechaActualizacion: timestamp
- actualizadoPor: int
- computadora: int
- deleted: boolean default 0
- checksum: varbinary(255)

### logs
- logId: bigint serial auto-increment (PK)
- userId: int
- eventTypeId: FK
- descripcion: varchar(200)
- sourceId: FK
- severityId: FK
- referenceId1: bigint null
- referenceId2: bigint null
- referenceDesc1: varchar(200) null
- referenceDesc2: varchar(200) null
- dataObjectId1: FK (a dataObjects) null
- dataObjectId2: FK (a dataObjects) null
- fechaRegistro: timestamp
- computadora: int
- checksum: varbinary(255)

-----------------------------------------
