Lista Inicial de Stored Procedures:

1. SP de Auditoría e Infraestructura (El "Helper")
Este es el SP independiente que mencionaste. Todos los demás SP lo llamarán para dejar rastro de lo que sucede.

sp_registrar_log_sistema: Recibe el ID del usuario, la acción realizada, la tabla afectada y los valores (JSONB). Inserta directamente en logsSistema.

2. SP de Catálogos y Localización (Configuración Inicial)
Estos SP permiten llenar la base de la pirámide de datos.

sp_insertar_persona: Registra empleados, operarios o contactos legales.

sp_insertar_moneda: Define las monedas (USD, CRC, NIO, EUR, JPY).

sp_insertar_geografia_completa: Un SP "maestro" que inserte en cascada País -> Provincia -> Ciudad para simplificar el llenado de los 5 países.

sp_insertar_direccion: Crea los registros de ubicación física para proveedores y centros logísticos.

sp_actualizar_tipo_cambio: Inserta en exchangeRates el valor diario de las monedas frente al USD.

3. SP de Entidades y Productos (Sourcing)
Aquí es donde cumpliremos el requisito de los 100 productos y los proveedores.

sp_insertar_proveedor: Registra la empresa proveedora y su contacto legal en una sola transacción (usando la tabla N a N proveedoresContactosLegales).

sp_insertar_categoria_y_unidad: Llena categoriasBase (Cosmética, Aceites, etc.) y unidadesMedida.

sp_insertar_producto_base: Registra los productos exóticos. Se llamará masivamente para llegar a los 100 registros.

sp_configurar_ubicacion_hub: Define pasillos, estantes y niveles en el HUB de Nicaragua.

4. SP Transaccionales (Compras e Inventario)
Estos manejan el flujo de dinero y mercancía.

sp_crear_orden_compra_completa: Un SP complejo que recibe un arreglo de productos, crea la cabecera en ordenesCompra y los detalles en ordenesCompraDetalle.

sp_registrar_arribo_lote: Cuando el producto llega a Nicaragua. Crea el loteImportacion y lo posiciona en el inventarioHub.

sp_registrar_gasto_importacion: Inserta en transaccionesCostos (fletes, seguros, impuestos DUA) asociados a una orden de compra.

5. SP de Cumplimiento y Salida (Dynamic Brands)
Para manejar los 9 sitios web (marcas blancas) y los envíos.

sp_registrar_marca_blanca: Registra las marcas (los 9 sitios web dinámicos) que consumirán los productos del HUB.

sp_configurar_requisitos_legales: Vincula productos con las leyes de cada país de destino.

sp_registrar_movimiento_trazabilidad: Registra cada paso (Etiquetado, Despacho) en la tabla trazabilidadMovimientos.

6. SP de Orquestación (El "Master Loader")
Este es el procedimiento que llamarás una sola vez para disparar todo el proceso de prueba.

sp_orquestador_llenado_datos_prueba:

Llama a los SP de catálogos (Personas, Monedas).

Llama al SP de Geografía para crear los 5 países (Nicaragua, Costa Rica, India, Marruecos, Francia, etc.).

Registra los proveedores internacionales.

Ejecuta un bucle para insertar los 100 productos distribuidos.

Registra las 9 marcas blancas (sitios web).

Genera órdenes de compra y movimientos de inventario iniciales para que el sistema no esté vacío.


////////////////////////////////////
1. SP de Auditoría Independiente
Este procedimiento será invocado por todos los demás para centralizar los logs.

SQL
CREATE OR REPLACE PROCEDURE sp_registrar_log_sistema(
    p_usuarioId INT,
    p_accion VARCHAR(100),
    p_tabla VARCHAR(50),
    p_valorAnterior JSONB,
    p_valorNuevo JSONB,
    p_ip VARCHAR(45)
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO logsSistema (
        usuarioId, 
        accion, 
        tablaAfectada, 
        valorAnterior, 
        valorNuevo, 
        fechaRegistro, 
        ipOrigen
    )
    VALUES (
        p_usuarioId, 
        p_accion, 
        p_tabla, 
        p_valorAnterior, 
        p_valorNuevo, 
        NOW(), 
        p_ip
    );
END;
$$;
2. SP Transaccional: Llenado de Geografía (Jerárquico)
Este SP permite insertar un país con su moneda y una provincia/ciudad base en una sola transacción. Esto garantiza que no queden "países sin moneda" o "ciudades huérfanas".

SQL
CREATE OR REPLACE PROCEDURE sp_insertar_geografia_completa(
    p_paisNombre VARCHAR(100),
    p_codigoISO VARCHAR(5),
    p_monedaNombre VARCHAR(50),
    p_monedaISO VARCHAR(3),
    p_monedaSimbolo VARCHAR(5),
    p_provinciaNombre VARCHAR(100),
    p_ciudadNombre VARCHAR(100),
    p_usuarioId INT,
    p_computadoraId INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_monedaId INT;
    v_paisId INT;
    v_provId INT;
    v_ciudadId INT;
BEGIN
    -- 1. Insertar Moneda
    INSERT INTO monedas (nombre, codigoISO, simbolo, actualizadoPor, computadoraId)
    VALUES (p_monedaNombre, p_monedaISO, p_monedaSimbolo, p_usuarioId, p_computadoraId)
    ON CONFLICT (codigoISO) DO UPDATE SET nombre = EXCLUDED.nombre
    RETURNING monedaId INTO v_monedaId;

    -- 2. Insertar País
    INSERT INTO paises (nombre, codigoISO, monedaLocalId, activo, actualizadoPor, computadoraId)
    VALUES (p_paisNombre, p_codigoISO, v_monedaId, TRUE, p_usuarioId, p_computadoraId)
    RETURNING paisId INTO v_paisId;

    -- 3. Insertar Provincia/Estado
    INSERT INTO provinciasEstados (paisId, nombre, actualizadoPor, computadoraId)
    VALUES (v_paisId, p_provinciaNombre, p_usuarioId, p_computadoraId)
    RETURNING provinciaEstadoId INTO v_provId;

    -- 4. Insertar Ciudad
    INSERT INTO ciudades (provinciaEstadoId, nombre, actualizadoPor, computadoraId)
    VALUES (v_provId, p_ciudadNombre, p_usuarioId, p_computadoraId)
    RETURNING ciudadId INTO v_ciudadId;

    -- Registrar en Auditoría
    CALL sp_registrar_log_sistema(
        p_usuarioId, 
        'INSERT_GEOGRAPHY_AUTO', 
        'paises/ciudades', 
        NULL, 
        jsonb_build_object('pais', p_paisNombre, 'ciudad', p_ciudadNombre), 
        '127.0.0.1'
    );

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error al insertar geografía para %: %', p_paisNombre, SQLERRM;
    ROLLBACK; -- Importante: Deshace todo si falla un paso
END;
$$;
3. Orquestador de Datos de Prueba (Parte 1: Base)
Este es el archivo de "Orquestación" que mencionaste. Iremos llamando a los SP en orden.

SQL
DO $$ 
BEGIN
    -- 0. CREAR PERSONA ADMIN (Para el campo actualizadoPor)
    INSERT INTO personas (cedulaIdentidad, nombre, primerApellido, email, telefono)
    VALUES ('000-000-000', 'Sistema', 'Etheria', 'admin@etheriaglobal.com', '8888-8888');

    -- 1. LLENADO DE LOS 5 PAÍSES (REQUISITO)
    -- India (Proveedor de Especias y Aceites)
    CALL sp_insertar_geografia_completa('India', 'IN', 'Rupia India', 'INR', '₹', 'Maharashtra', 'Mumbai', 1, 101);
    
    -- Marruecos (Proveedor de Aceite de Argán)
    CALL sp_insertar_geografia_completa('Marruecos', 'MA', 'Dirham Marroquí', 'MAD', 'د.م.', 'Casablanca-Settat', 'Casablanca', 1, 101);
    
    -- Francia (Proveedor de Cosmética de lujo)
    CALL sp_insertar_geografia_completa('Francia', 'FR', 'Euro', 'EUR', '€', 'Île-de-France', 'París', 1, 101);
    
    -- Nicaragua (Centro Logístico HUB)
    CALL sp_insertar_geografia_completa('Nicaragua', 'NI', 'Córdoba', 'NIO', 'C$', 'Costa Caribe Sur', 'Bluefields', 1, 101);
    
    -- Costa Rica (Sede Administrativa / Dynamic Brands)
    CALL sp_insertar_geografia_completa('Costa Rica', 'CR', 'Colón', 'CRC', '₡', 'San José', 'San José', 1, 101);

    -- 2. INSERTAR USD (Moneda base de importación)
    INSERT INTO monedas (nombre, codigoISO, simbolo, actualizadoPor, computadoraId)
    VALUES ('Dólar Estadounidense', 'USD', '$', 1, 101) ON CONFLICT DO NOTHING;

END $$;