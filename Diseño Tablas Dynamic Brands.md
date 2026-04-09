Bases de Datos 1

Caso #1

Estudiantes:
Angélica Cabrera Bermúdez - 2024253434
Estefanía Portuguez Víquez - 2024800621

-----------------------------------------
- Database engine: MySQL
- Database name: DynamicBrands

- Descripción:
Esta es una empresa de base tecnológica. Han desarrollado una IA capaz de generar sitios de e-commerce dinámicos. 
* A partir de parámetros (logo, enfoque, país), la IA despliega tiendas virtuales con marcas blancas. 
* Pueden abrir y cerrar "N" sitios en diferentes países de Latam con un solo clic, cada uno con un enfoque de marketing y mensajes distintos para el mismo producto base.

-----------------------------------------

## Tables:
// Tablas de Catálogo (Para evitar Hardcoding y usar Selects en UI)
### paises
- paisId: serial auto-increment (PK)
- nombre: varchar(75)
- codigoISO: varchar(3)
- monedaId: FK
- activo: boolean default 1

### monedas
- monedaId: serial auto-increment (PK)
- nombre: varchar(75)
- simbolo: varchar(5)
- codigoISO: varchar(3)
- activo: boolean default 1

### tiposDeDatosAtributos:
- tipoDeDatoAtributoId: serial auto-increment (PK)
- nombre: varchar(15)
- descripcion: varchar (150)

### estadosOrden //Pendiente, empacado, enviado, ...
- estadoOrdenId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)

### estadosEnvio //En almacen, en transito, entregado, ...
- estadoEnvioId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)

### eventosEnvio //Recibido en ___, entregado a __, ... 
- eventoEnvioId: serial auto-increment (PK)
- nombre: varchar(50)
- descripcion: varchar (150)

### accionesTiendas  //Abrir, cerrar, actualizar, ...
- accionTiendaId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)

### procesos //Stored Procedures
- procesoId: serial auto-increment (PK)
- nombre: varchar(50)
- descripcion: varchar (150)

### pasosProcesos
- pasoProcesoId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)

### estadosProcesos
- estadoProcesoId: serial auto-increment (PK)
- nombre: varchar(20)
- descripcion: varchar (150)

### erroresProcesos
- errorProcesoId: serial auto-increment (PK)
- codigoSQL: varchar(10)
- explicacion: varchar (150)

### entidadesSistema
- entidadSitemaId: serial auto-increment (PK)
- nombre: varchar(50)
- funcion: varchar (150)

// Tablas para el núcleo de la IA y los sitios web (Permiten configuraciones variables)
### tiendas
- tiendaId: serial auto-increment (PK)
- nombre: varchar(50)
- dominio: varchar(255)
- paisId: FK
- monedaId: FK
- activo: boolean default 1
- fechaCreacion: timestamp

### conceptosTiendas:
- conceptoTiendaId: serial auto-increment (PK)
- tiendaId: FK
- apariencia: JSON
- enfoqueMarketing: JSON
- version: int
- fechaImplementacion: timestamp

### productosMarcasBlancas //Prodcutos específicos de la tienda creada por la IA
- productoMarcaBlancaId: serial auto-increment (PK)
- tiendaId: FK
- productoBaseId: FK //Referencia a tabla en EtheriaGlobal
- nombreComercial:
- precio: decimal(12, 2)
- activo: boolean default 1

// Tablas para flexibilidad de producto (Con el uso del modelo EAV)
### atributos
- atributoId: serial auto-increment (PK)
- nombre: varchar(30)
- descripcion: varchar (150)

### valoresDeAtributos
- valorDeAtributoId: (productoMarcaBlancaId (FK), atributoId (FK)) (PK)
- valor: varchar(30)
- tipoDeDatoAtributoId: FK

// Tablas para ventas y logística de salida
### clientes
- clienteId: serial auto-increment (PK)
- nombre: varchar(50)
- primerApellido: varchar(50)
- segundoApellido: varchar(50)
- correo: varchar(100) unique
- telefono: varchar(20)
- contraseña: varchar(255)
- fechaDeRegistro: timestamp
- activo: boolean default 1

### ordenes 
- ordenId: serial auto-increment (PK)
- tiendaId: FK
- clienteId: FK
- estadoOrdenId: FK
- monedaId: FK
- montoLocal: decimal(18, 2)
- activo: boolean default 1
- fechaCreacion: timestamp
- fechaActualizacion: timestamp

### productosOrdenes:
- productoOrdenId: serial auto-increment (PK)
- ordenId: FK
- productosMarcasBlancasId: FK
- cantidad: int
- monedaId: FK
- montoLocal: decimal(18, 2)

### envios
- envioId: serial auto-increment (PK)
- ordenId: FK
- courierId: FK //Referencia a tabla en EtheriaGlobal
- numeroGuia: varchar(100)
- estadoEnvioId: FK
- activo: boolean default 1

## instruccionesEtiquetas:
- instruccionEtiquetaId: serial auto-increment (PK)
- productosMarcasBlancasId: FK
- especificaciones: JSON
- datosLegales: JSON
- envioId: FK
- trazabilidadId: FK //Referencia a tabla en EtheriaGlobal

### costosLogistica
- costoLogisticaId: serial auto-increment (PK)
- envioId: FK
- montoUSD: decimal(12,2)
- tipoCostoId: FK //Referencia a tabla en EtheriaGlobal

// Tablas para bitácoras e historiales
### bitacoraSPTransacciones
- bitacoraSPTransaccionesId: serial auto-increment (PK)
- procesoId: FK
- pasoProcesoId: FK
- estadoProcesoId: FK
- errorProcesoId: FK
- mensaje: varchar (150)
- entidadSitemaId: FK
- fecha: timestamp

### historialEstadosOrdenes
- historialEstadoOrdenId: serial auto-increment (PK)
- ordenId: FK
- estadoAnteriorId: FK a la tabla estadosOrden
- estadoNuevoId: FK a la tabla estadosOrden
- comentario: varchar (150)
- fecha: timestamp

### historialRastreosEnvios
- historialRastreoEnvioId: serial auto-increment (PK)
- envioId: FK
- eventoEnvioId: FK
- paisRegistrado: FK //Referencia a tabla en EtheriaGlobal
- ciudadRegistrada: FK //Referencia a tabla en EtheriaGlobal
- comentario: varchar (150)
- fecha: timestamp

### bitacoraTiendas
- bitacoraTiendaId: serial auto-increment (PK)
- tiendaId: FK
- accionTiendaId: FK
- comentario: varchar (150)
- fecha: timestamp

-----------------------------------------
