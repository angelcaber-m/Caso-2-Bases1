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
- nombre
- codigoISO
- monedaId
- activo

### monedas
- monedaId: serial auto-increment (PK)
- nombre
- simbolo
- codigoISO
- activo

### estadosOrden //Pendiente, empacado, enviado...
- estadoOrdenId: serial auto-increment (PK)
- nombre
- descripcion

### estadosEnvio //En almacen, en transito, entregado...
- estadoEnvioId: serial auto-increment (PK)
- nombre
- descripcion

### eventosEnvio
- eventoEnvioId: serial auto-increment (PK)
- nombre
- descripcion

### accionesTiendas
- accionTiendaId: serial auto-increment (PK)
- nombre
- descripcion

### procesos
- procesoId: serial auto-increment (PK)
- nombre
- descripcion

### pasosProcesos
- pasoProcesoId: serial auto-increment (PK)
- nombre
- descripcion

### estadosProcesos
- estadoProcesoId: serial auto-increment (PK)
- nombre
- descripcion

### erroresProcesos
- errorProcesoId: serial auto-increment (PK)
- codigoSQL
- explicacion

### entidadesSistema
- entidadSitemaId: serial auto-increment (PK)
- nombre
- funcion

// Tablas para el núcleo de la IA y los sitios web (Permiten configuraciones variables)
### tiendas
- tiendaId: serial auto-increment (PK)
- nombre
- dominio
- paisId: FK
- monedaId: FK
- activo
- fechaCreacion

### conceptosTiendas:
- conceptoTiendaId: serial auto-increment (PK)
- tiendaId: FK
- apariencia: JSON
- enfoqueMarketing: JSON
- version
- fechaImplementacion

### productosMarcasBlancas //Prodcutos específicos de la tienda creada por la IA
- productoMarcaBlancaId: serial auto-increment (PK)
- tiendaId: FK
- productoBaseId: FK //Referencia a tabla en EtheriaGlobal
- nombreComercial
- activo

// Tablas para flexibilidad de producto (Con el uso del modelo EAV)
### atributos
- atributoId: serial auto-increment (PK)
- nombre
- descripcion

### valoresDeAtributos
- valorDeAtributoId: (productoMarcaBlancaId (FK), atributoId (FK)) (PK)
- valor //varchar
- tipoDeDato

// Tablas para ventas y logística de salida
### clientes
- clienteId: serial auto-increment (PK)
- nombre: varchar(50)
- primerApellido: varchar(50)
- segundoApellido: varchar(50)
- correo: varchar(100) unique
- telefono: varchar(20)
- contraseña: varchar(255)
- fechaDeRegistro: date
- activo: boolean

### ordenes 
- ordenId: serial auto-increment (PK)
- tiendaId: FK
- clienteId: FK
- estadoOrdenId: FK
- monedaId: FK
- montoLocal
- activo
- fechaCreacion
- fechaActualizacion

### productosOrdenes:
- productoOrdenId: serial auto-increment (PK)
- ordenId: FK
- productosMarcasBlancasId: FK
- cantidad
- monedaId: FK
- montoLocal

### envios
- envioId: serial auto-increment (PK)
- ordenId: FK
- courierId: FK //Referencia a tabla en EtheriaGlobal
- numeroGuia
- estadoEnvioId: FK
- activo

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
- montoUSD
- tipoCostoId: FK //Referencia a tabla en EtheriaGlobal

// Tablas para bitácoras e historiales
### bitacoraSPTransacciones
- bitacoraSPTransaccionesId: serial auto-increment (PK)
- procesoId: FK
- pasoProcesoId: FK
- estadoProcesoId: FK
- errorProcesoId: FK
- mensaje
- entidadSitemaId: FK
- fecha

### historialEstadosOrdenes
- historialEstadoOrdenId: serial auto-increment (PK)
- ordenId: FK
- estadoAnteriorId: FK a la tabla estadosOrden
- estadoNuevoId: FK a la tabla estadosOrden
- comentario
- fecha

### historialRastreosEnvios
- historialRastreoEnvioId: serial auto-increment (PK)
- envioId: FK
- eventoEnvioId: FK
- paisRegistrado: FK //Referencia a tabla en EtheriaGlobal
- ciudadRegistrada: FK //Referencia a tabla en EtheriaGlobal
- comentario
- fecha

### bitacoraTiendas
- bitacoraTiendaId: serial auto-increment (PK)
- tiendaId: FK
- accionTiendaId: FK
- comentario
- fecha

-----------------------------------------
