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
## paisesOrigen: Almacena los países donde se compran los insumos originales.
 - paisId (SERIAL PK)
 - nombre
 - codigoISO
 - activo (BOOLEAN)


## categoriasBase: Define si el producto es cosmética, aromaterapia, bebida, etc.
 - categoriaId (SERIAL PK)
 - nombre 
 - descripcion

## proveedores: Empresas internacionales que suministran los productos en granel.
- proveedorId (SERIAL PK)-
- nombre 
- paisId (FK)
- contacto_legal

//Gestión de Productos e Inventario (Sourcing)
//Enfocada en el almacenamiento en el HUB de Nicaragua y la gestión de costos en dólares.
## productosBase: El producto sin marca (ej. Aceite de Lavanda puro).
- productoBaseId (SERIAL PK)
- nombre
- categoriaId (FK)
- unidadMedida (ej. litros, kg)
- descripcionTecnica


## lotesImportacion: Crucial para la trazabilidad hacia atrás.
- loteId (SERIAL PK)
- codigoLote (UNIQUE), 
- productoBaseId (FK) 
- proveedorId (FK)
- cantidadInicial
- stockActual 
- fechaArribo (TIMESTAMPTZ)


## tiposCostoImportacion: Catálogo de gastos (Aranceles, Fletes, Seguros, Gastos Aduaneros).
- tipoCostoId (SERIAL PK)
- nombre
- descripcion


## costosImportacionDetalle: Permite a la gerencia calcular la rentabilidad real sumando todos los costos asociados al lote.
- costoId(SERIAL PK)
- loteId (FK) 
- tipoCostoId(FK) 
- montoUSD

// Logística de Salida y Trazabilidad
// Esta sección conecta con el sistema de Dynamic Brands (MySQL) para el etiquetado y cumplimiento legal.
## requisitosLegalesPais: Almacena permisos de salud o regulaciones específicas (ej. requisitos para productos de "ingesta").
- requisitoId (SERIAL PK) 
- productoBaseId(FK)
- codigoISOPaisDestino
- descripcionPermiso
- urlDocumentoLegal


## trazabilidad_hub: Registra el "matrimonio" entre el producto bulk y la orden específica de una marca blanca.
- trazabilidadId (UUID PK)
- loteId (FK) 
- ordenIdExterna (INT - ID de MySQL)
- fechaProcesado
- operarioId
- estadoFinal (ej. Etiquetado, Despachado).


## couriers: Terceros encargados de la entrega final.
- courierId (SERIAL PK)
- nombre
- contacto 
- activo (BOOLEAN)

// Patrones de Logging y Auditoría
// Diseñada bajo el patrón de log estructurado para reconstruir fallos en los Stored Procedures.
## bitacora_sp_logistica: Registra cada paso de los procesos transaccionales.
- logId (SERIAL PK)
- procesoNombre
- pasoDescripcion 
- estado (INFO, ERROR, SUCCESS)
- codigoSqlstate
- mensajeJson (JSONB para flexibilidad)
- fechaRegistro (TIMESTAMPTZ)