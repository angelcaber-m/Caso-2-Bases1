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
 - nombre: VARCHAR (100)
 - codigoISO: VARCHAR (5)
 - activo: BOOLEAN


## categoriasBase: Define si el producto es cosmética, aromaterapia, bebida, etc.
 - categoriaId: SERIAL (PK)
 - nombre: VARCHAR(100)
 - descripcion: TEXT

## proveedores: Empresas internacionales que suministran los productos en granel.
- proveedorId: SERIAL (PK)
- nombre: VARCHAR(150)
- paisId: INT (FK)
- contactoLegal: TEXT

## unidades_medida: Define las unidades para el manejo de bulk (Litros, Kilogramos, Unidades).
- unidadMedidaId: SERIAL (PK)
- nombre: VARCHAR (30) -- Ej: 'Litros'
- abreviatura: VARCHAR (5) -- Ej: 'L'

## estadosTrazabilidad: Catálogo de estados por los que pasa un producto en el HUB.
- estadoTrazabilidadId: SERIAL (PK)
- nombre: VARCHAR (50) -- Ej: 'Recibido', 'Etiquetado', 'Despachado', 'Retenido'


//Gestión de Productos e Inventario (Sourcing)
//Enfocada en el almacenamiento en el HUB de Nicaragua y la gestión de costos en dólares.
## productosBase: El producto sin marca (ej. Aceite de Lavanda puro).
- productoBaseId: SERIAL (PK)
- nombre: VARCHAR(150)
- categoriaId: INT (FK)
- unidadMedidaId: INT -> Referencia a la tabla unidades_medida
- descripcionTecnica: TEXT


## lotesImportacion: Crucial para la trazabilidad hacia atrás.
- loteId: SERIAL (PK)
- codigoLote: VARCHAR(50)
- productoBaseId: INT (FK) 
- proveedorId: INT (FK)
- cantidadInicial: NUMERIC(12,2) //Representa el total que ingresó al HUB
- stockActual: NUMERIC(12,2)  //Es la cantidad disponible que disminuye conforme se etiqueta para Dynamic Brands.
- fechaArribo: TIMESTAMPTZ


## tiposCostoImportacion: Catálogo de gastos (Aranceles, Fletes, Seguros, Gastos Aduaneros).
- tipoCostoId: SERIAL (PK)
- nombre: VARCHAR(50)
- descripcion: TEXT


## costosImportacionDetalle: Permite a la gerencia calcular la rentabilidad real sumando todos los costos asociados al lote.
- costoId: SERIAL (PK)
- loteId: INT (FK) 
- tipoCostoId: INT (FK) 
- montoUSD: NUMERIC(15,2) 

// Logística de Salida y Trazabilidad
// Esta sección conecta con el sistema de Dynamic Brands (MySQL) para el etiquetado y cumplimiento legal.
## requisitosLegalesPais: Almacena permisos de salud o regulaciones específicas (ej. requisitos para productos de "ingesta").
- requisitoId: SERIAL (PK) 
- productoBaseId:INT(FK)
- paisDestinoId: INT (FK) -> paises.pais_id
- descripcionPermiso: TEXT
- urlDocumentoLegal: VARCHAR(512)


## trazabilidadHub: Registra el "matrimonio" entre el producto bulk y la orden específica de una marca blanca.
- trazabilidadId: (UUID PK, DEFAULT gen_random_uuid()) //El uso de UUID es ideal para llaves primarias que deben ser únicas a través de diferentes sistemas o bases de datos
- loteId: INT (FK) -> lotes_importacion.lote_id
- ordenIdExterna:INT -- Referencia a Dynamic Brands (MySQL)
- estadoTrazabilidadId: INT (FK) -> estados_trazabilidad.estado_trazabilidad_id
- fechaProcesado:TIMESTAMPTZ
- operarioId:INT

## couriers: Terceros encargados de la entrega final.
- courierId: SERIAL (PK)
- nombre: VARCHAR(100)
- contacto: TEXT 
- activo: BOOLEAN

// Patrones de Logging y Auditoría
// Diseñada bajo el patrón de log estructurado para reconstruir fallos en los Stored Procedures.
## bitacoraSPLogistica: Registra cada paso de los procesos transaccionales.
- logId: SERIAL (PK)
- procesoNombre: VARCHAR(100)
- pasoDescripcion: TEXT
- estado: VARCHAR(20)
- codigoSqlstate: VARCHAR(5)
- mensajeJson: JSONB
- fechaRegistro: TIMESTAMPTZ