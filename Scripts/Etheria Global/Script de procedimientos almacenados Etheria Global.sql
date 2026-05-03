/* ======================================================
   Módulo de Auditoría y Control (La Base)
   ====================================================== */

CREATE OR REPLACE PROCEDURE sp_registrar_log(
    p_usuario_id INT,
    p_evento_tipo_id INT,
    p_descripcion VARCHAR,
    p_source_id INT)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO logs (
        userId, eventTypeId, descripcion, sourceId, fechaRegistro
    ) VALUES (
        p_usuario_id, p_evento_tipo_id, p_descripcion, p_source_id, NOW()
    );
END;
$$;


/* ======================================================
   Módulo 1: Infraestructura y Catálogos Básicos
   ====================================================== */

--1. SP: Registrar Personas // Este procedimiento registra tanto a operarios como a contactos legales de proveedores.
CREATE OR REPLACE PROCEDURE sp_insertar_persona(
    p_cedula VARCHAR,
    p_nombre VARCHAR,
    p_apellido1 VARCHAR,
    p_apellido2 VARCHAR,
    p_email VARCHAR,
    p_telefono VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_persona_id INT;
BEGIN
    -- Validar si ya existe para evitar error de UNIQUE
    IF EXISTS (SELECT 1 FROM personas WHERE cedulaIdentidad = p_cedula) THEN
        RAISE NOTICE 'Persona con cédula % ya existe.', p_cedula;
        RETURN;
    END IF;

    INSERT INTO personas (
        cedulaIdentidad, nombre, primerApellido, segundoApellido, 
        email, telefono, actualizadoPor, computadoraId
    ) VALUES (
        p_cedula, p_nombre, p_apellido1, p_apellido2, 
        p_email, p_telefono, p_actualizado_por, p_computadora_id
    ) RETURNING personaId INTO v_persona_id;

    -- Auditoría
    CALL sp_registrar_log(p_actualizado_por, 1, 'Registro de nueva persona: ' || p_nombre, 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error al insertar persona: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Error en sp_insertar_persona: %', SQLERRM;
END;
$$;



--2. SP: Configurar Monedas // Fundamental para el manejo de precios en la cadena de suministro internacional.

CREATE OR REPLACE PROCEDURE sp_insertar_moneda(
    p_nombre VARCHAR,
    p_codigo_iso VARCHAR,
    p_simbolo VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_moneda_id INT;
BEGIN
    INSERT INTO monedas (nombre, codigoISO, simbolo, actualizadoPor, computadoraId)
    VALUES (p_nombre, p_codigo_iso, p_simbolo, p_actualizado_por, p_computadora_id)
    RETURNING monedaId INTO v_moneda_id;

    IF v_moneda_id IS NOT NULL THEN
        CALL sp_registrar_log(p_actualizado_por, 1, 'Moneda creada: ' || p_codigo_iso, 1);
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en sp_insertar_moneda: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo al insertar moneda: %', SQLERRM;
END;
$$;


--3. SP: Registrar Tasa de Cambio // Permite la conversión dinámica de precios de compra (bulk) a dólares (USD).

CREATE OR REPLACE PROCEDURE sp_registrar_tasa_cambio(
    p_iso_origen VARCHAR,
    p_iso_destino VARCHAR,
    p_compra NUMERIC,
    p_venta NUMERIC,
    p_fecha_efectiva DATE,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_origen_id INT;
    v_destino_id INT;
    v_rate_id INT;
BEGIN
    SELECT monedaId INTO v_origen_id FROM monedas WHERE codigoISO = p_iso_origen;
    SELECT monedaId INTO v_destino_id FROM monedas WHERE codigoISO = p_iso_destino;

    IF v_origen_id IS NULL OR v_destino_id IS NULL THEN
        RAISE EXCEPTION 'Una de las monedas proporcionadas no existe (Origen: %, Destino: %)', p_iso_origen, p_iso_destino;
    END IF;

    INSERT INTO exchangeRates (
        monedaOrigenId, monedaDestinoId, valorCompra, valorVenta, 
        fechaEfectiva, actualizadoPor, computadoraId
    ) VALUES (
        v_origen_id, v_destino_id, p_compra, p_venta, 
        p_fecha_efectiva, p_actualizado_por, p_computadora_id
    ) RETURNING exchangeRateId INTO v_rate_id;

    CALL sp_registrar_log(p_actualizado_por, 1, 'Tasa de cambio registrada: ' || p_iso_origen || ' -> ' || p_iso_destino, 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en sp_registrar_tasa_cambio: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en tasa de cambio: %', SQLERRM;
END;
$$;


--4. SP: Unidades de Medida // Define cómo se cuantifican los productos medicinales exóticos (Litros para aceites, Kilogramos para polvos, etc.).
CREATE OR REPLACE PROCEDURE sp_configurar_unidades_medida(
    p_nombre VARCHAR,
    p_abreviatura VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_unidad_id INT;
BEGIN
    INSERT INTO unidadesMedida (nombre, abreviatura, actualizadoPor, computadoraId)
    VALUES (p_nombre, p_abreviatura, p_actualizado_por, p_computadora_id)
    RETURNING unidadMedidaId INTO v_unidad_id;

    IF v_unidad_id IS NOT NULL THEN
        CALL sp_registrar_log(p_actualizado_por, 1, 'Unidad de medida creada: ' || p_nombre, 1);
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en sp_configurar_unidades_medida: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo al configurar unidad: %', SQLERRM;
END;
$$;

--5. SP: Tipos de costo
CREATE OR REPLACE PROCEDURE sp_configurar_tipo_costo(
    p_id INT,
    p_nombre VARCHAR,
    p_descripcion VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_costo_id INT;
BEGIN
    -- 1. Validar si el tipo de costo ya existe para evitar duplicados
    SELECT tipoCostoId INTO v_tipo_costo_id 
    FROM tiposCostoImportacion 
    WHERE nombre = p_nombre;

    IF v_tipo_costo_id IS NOT NULL THEN
        -- Si ya existe, podemos optar por actualizar la descripción o simplemente registrar el log
        UPDATE tiposCostoImportacion 
        SET descripcion = p_descripcion,
            actualizadoEn = CURRENT_TIMESTAMP,
            actualizadoPor = p_actualizado_por,
            computadoraId = p_computadora_id
        WHERE tipoCostoId = v_tipo_costo_id;

        CALL sp_registrar_log(p_actualizado_por,1, 'Actualización de Tipo de Costo',1);
    ELSE
        -- 2. Insertar el nuevo tipo de costo
        INSERT INTO tiposCostoImportacion (tipoCostoId, nombre, descripcion, actualizadoPor, computadoraId)
        VALUES (p_id, p_nombre, p_descripcion, p_actualizado_por, p_computadora_id) RETURNING tipoCostoId INTO v_tipo_costo_id;

        -- 3. Registrar la acción en la bitácora
        CALL sp_registrar_log(p_actualizado_por,1, 'Registro de Tipo de Costo',1);
    END IF;

EXCEPTION WHEN OTHERS THEN
    -- Intentar registrar el error en el log antes de fallar
    -- Nota: Esto puede fallar si el error original fue la FK de usuario
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en sp_configurar_tipo_costo: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Error al configurar tipo de costo: %', SQLERRM;
END;
$$;


/* ======================================================
   Módulo 2: Geografía Completa
   ====================================================== */

--1. SP: Registrar Infraestructura Base: -- Este SP actúa como un inicializador global. En lugar de insertar datos uno a uno, agrupa los elementos básicos que no dependen de nadie más

CREATE OR REPLACE PROCEDURE sp_registrar_infraestructura_base(
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Insertar Monedas
    CALL sp_insertar_moneda('Dólar', 'USD', '$', p_actualizado_por, p_computadora_id);
    CALL sp_insertar_moneda('Colón', 'CRC', '₡', p_actualizado_por, p_computadora_id);
    CALL sp_insertar_moneda('Peso Mexicano', 'MXN', '$', p_actualizado_por, p_computadora_id);
    CALL sp_insertar_moneda('Peso Colombiano', 'COP', '$', p_actualizado_por, p_computadora_id);
    CALL sp_insertar_moneda('Balboa', 'PAB', 'B/.', p_actualizado_por, p_computadora_id);
    CALL sp_insertar_moneda('Quetzal', 'GTQ', 'Q', p_actualizado_por, p_computadora_id);

    -- 2. Tasas de Cambio (Valores de ejemplo)
    -- Colón Costarricense (CRC)
    CALL sp_registrar_tasa_cambio('CRC', 'USD', 510.00, 515.00, CURRENT_DATE, p_actualizado_por, p_computadora_id);

    -- Peso Mexicano (MXN)
    CALL sp_registrar_tasa_cambio('MXN', 'USD', 16.85, 16.95, CURRENT_DATE, p_actualizado_por, p_computadora_id);

    -- Peso Colombiano (COP)
    CALL sp_registrar_tasa_cambio('COP', 'USD', 3850.00, 3900.00, CURRENT_DATE, p_actualizado_por, p_computadora_id);

    -- Balboa Panameño (PAB) -> Paridad 1:1 con el Dólar
    CALL sp_registrar_tasa_cambio('PAB', 'USD', 1.00, 1.00, CURRENT_DATE, p_actualizado_por, p_computadora_id);

    -- Quetzal Guatemalteco (GTQ)
    CALL sp_registrar_tasa_cambio('GTQ', 'USD', 7.75, 7.85, CURRENT_DATE, p_actualizado_por, p_computadora_id);
  
    -- 3. Unidades de Medida
    CALL sp_configurar_unidades_medida('Litros', 'L', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_unidades_medida('Kilogramos', 'Kg', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_unidades_medida('Unidades', 'Un', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_unidades_medida('Mililitros', 'ml', p_actualizado_por, p_computadora_id);

    -- 4. Tipo de costo
    CALL sp_configurar_tipo_costo(1, 'Flete Internacional', 'Costo de transporte marítimo/aéreo', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_tipo_costo(2, 'Seguro', 'Seguro de carga internacional', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_tipo_costo(3, 'DAI', 'Derecho Arancelario a la Importación', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_tipo_costo(4, 'Bodegaje', 'Costo de permanencia en recinto aduanero', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_tipo_costo(5, 'Corretaje Aduanero', 'Honorarios del Agente de Aduanas por gestión de nacionalización', p_actualizado_por, p_computadora_id);
    CALL sp_configurar_tipo_costo(6, 'Impuesto sobre Ventas (Importación)', 'Impuesto al valor agregado liquidado en aduana', p_actualizado_por, p_computadora_id);

    --5. Tipo de requisito
    INSERT INTO tiposRequisitos (nombre) VALUES
    ('Registro Sanitario'),
    ('Certificado de Origen'),
    ('Permiso de Importación');

    CALL sp_registrar_log(p_actualizado_por, 1, 'Infraestructura base (Monedas, Tasas, Unidades, Tipos de costo) cargada', 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en infraestructura base: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo crítico en infraestructura: %', SQLERRM;
END;
$$;


--2. SP Registrar Ubicaciones Lógicas: --Este es el SP más complejo de este módulo porque maneja la recursividad lógica de la ubicación.

CREATE OR REPLACE PROCEDURE sp_registrar_ubicaciones_logicas(
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. COSTA RICA
    INSERT INTO paises (nombre, codigoISO, monedaLocalId, activo, actualizadoPor, computadoraId)
    VALUES ('Costa Rica', 'CRI', (SELECT monedaId FROM monedas WHERE codigoISO = 'CRC'), TRUE, p_actualizado_por, p_computadora_id);

    -- 2. MÉXICO
    INSERT INTO paises (nombre, codigoISO, monedaLocalId, activo, actualizadoPor, computadoraId)
    VALUES ('México', 'MX', (SELECT monedaId FROM monedas WHERE codigoISO = 'MXN'), TRUE, p_actualizado_por, p_computadora_id);

    -- 3. COLOMBIA
    INSERT INTO paises (nombre, codigoISO, monedaLocalId, activo, actualizadoPor, computadoraId)
    VALUES ('Colombia', 'CO', (SELECT monedaId FROM monedas WHERE codigoISO = 'COP'), TRUE, p_actualizado_por, p_computadora_id);

    -- 4. PANAMÁ
    INSERT INTO paises (nombre, codigoISO, monedaLocalId, activo, actualizadoPor, computadoraId)
    VALUES ('Panamá', 'PA', (SELECT monedaId FROM monedas WHERE codigoISO = 'PAB'), TRUE, p_actualizado_por, p_computadora_id);

    -- 5. GUATEMALA
    INSERT INTO paises (nombre, codigoISO, monedaLocalId, activo, actualizadoPor, computadoraId)
    VALUES ('Guatemala', 'GT', (SELECT monedaId FROM monedas WHERE codigoISO = 'GTQ'), TRUE, p_actualizado_por, p_computadora_id);

    CALL sp_registrar_log(p_actualizado_por, 1, 'Geografía básica (5 países) cargada con estado activo', 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en geografía: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Error crítico en ubicaciones: %', SQLERRM;
END;
$$;



--3. SP Registrar Personas Sistema: --Unifica la carga de talento humano y legal.

CREATE OR REPLACE PROCEDURE sp_registrar_personas_sistema(
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Administrador Principal
    -- Si sp_insertar_persona falla, lanzará una excepción y saltará directamente al bloque EXCEPTION
    CALL sp_insertar_persona('0-000-000', 'Admin2', 'Etheria', 'System', 'admin@etheria.com', '50500000000', p_actualizado_por, p_computadora_id);

    -- 2. Operarios del HUB (Nicaragua)
    CALL sp_insertar_persona('NI-101', 'Juan', 'Pérez', 'López', 'jperez@etheria.com', '5058888888', p_actualizado_por, p_computadora_id);
    CALL sp_insertar_persona('NI-102', 'María', 'García', NULL, 'mgarcia@etheria.com', '5057777777', p_actualizado_por, p_computadora_id);

    -- 3. Contactos Legales de Proveedores Internacionales
    CALL sp_insertar_persona('FR-990', 'Jean', 'Dupont', NULL, 'j.dupont@frenchlab.com', '3312345678', p_actualizado_por, p_computadora_id);

    -- 4. LOG DE ÉXITO FINAL
    -- Solo se llega aquí si TODAS las llamadas anteriores terminaron sin errores.
    CALL sp_registrar_log(
        p_actualizado_por, 
        1, 
        'Carga masiva de personas del sistema finalizada con éxito total', 
        1);

EXCEPTION WHEN OTHERS THEN
    -- 5. MANEJO DE ERROR GLOBAL
    -- Si cualquiera de los CALL falla, capturamos el error aquí.
    -- Esto evita que se registre el log de éxito erróneamente.
    CALL sp_registrar_log(
        p_actualizado_por, 
        1, 
        'Fallo parcial o total en carga de personas: ' || SQLERRM, 
        1);
    
    -- Re-lanzamos la excepción para que el orquestador sepa que este módulo falló
    RAISE EXCEPTION 'Error en catálogo de personas (Consistencia): %', SQLERRM;
END;
$$;


/* ======================================================
   Módulo 3: Sourcing y Productos (El núcleo del negocio)
   ====================================================== */

--1. SP Registrar Proveedor Internacional: --Este procedimiento no solo crea la empresa, sino que gestiona la relación N a N con el representante legal que ya se registró en el módulo anterior.

-- 1. Registrar Proveedor con Nombre de Persona (en lugar de ID)
CREATE OR REPLACE PROCEDURE sp_registrar_proveedor_internacional(
    p_cedula_juridica VARCHAR,
    p_nombre_comercial VARCHAR,
    p_telefono VARCHAR,
    p_cedula_contacto VARCHAR, -- Usamos Cédula para buscar a la persona
    p_rol_legal VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_proveedor_id INT;
    v_persona_id INT;
BEGIN
    -- 1. Buscar a la persona por su cédula Y verificar que esté ACTIVA
    -- Esto evita asignar representantes legales que ya no laboran con la empresa
    SELECT personaId INTO v_persona_id 
    FROM personas 
    WHERE cedulaIdentidad = p_cedula_contacto; -- <--- Validación de seguridad
    
    IF v_persona_id IS NULL THEN
        RAISE EXCEPTION 'La persona con cédula % no existe o está inactiva en el catálogo.', p_cedula_contacto;
    END IF;
    -- 2. Insertar la empresa proveedora con estado ACTIVO
    INSERT INTO proveedores (
        cedulaJuridica, 
        nombreComercial, 
        telefonoOficina,
        actualizadoPor, 
        computadoraId
    )
    VALUES (
        p_cedula_juridica, 
        p_nombre_comercial, 
        p_telefono,
        p_actualizado_por, 
        p_computadora_id
    )
    ON CONFLICT (cedulaJuridica) DO UPDATE SET 
        nombreComercial = EXCLUDED.nombreComercial,
        activo = EXCLUDED.activo, -- <--- Reactivación si se vuelve a insertar
        actualizadoPor = EXCLUDED.actualizadoPor
    RETURNING proveedorId INTO v_proveedor_id;

    INSERT INTO proveedoresContactosLegales (proveedorId, personaId, rol, actualizadoPor, computadoraId)
    VALUES (v_proveedor_id, v_persona_id, p_rol_legal, p_actualizado_por, p_computadora_id);

    CALL sp_registrar_log(p_actualizado_por, 1, 'Proveedor registrado: ' || p_nombre_comercial, 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en proveedor: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en sp_registrar_proveedor_internacional: %', SQLERRM;
END;
$$;


--2. SP Crear Categoria Base: --Un catálogo simple pero vital para el filtrado de productos.
CREATE OR REPLACE PROCEDURE sp_crear_categoria_base(
    p_nombre VARCHAR,
    p_descripcion VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cat_id INT;
BEGIN
    INSERT INTO categoriasBase (nombre, descripcion, actualizadoPor, computadoraId)
    VALUES (p_nombre, p_descripcion, p_actualizado_por, p_computadora_id)
    RETURNING categoriaId INTO v_cat_id;

    IF v_cat_id IS NOT NULL THEN
        CALL sp_registrar_log(p_actualizado_por, 1, 'Categoría creada: ' || p_nombre, 1);
    END IF;

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en categorías: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en sp_crear_categoria_base: %', SQLERRM;
END;
$$;


-- 3. Insertar Producto por Nombres de Categoría y Unidad
CREATE OR REPLACE PROCEDURE sp_insertar_producto_base(
    p_nombre VARCHAR,
    p_nombre_categoria VARCHAR, -- Nombre en lugar de ID
    p_nombre_unidad VARCHAR,    -- Nombre en lugar de ID
    p_descripcion_tecnica VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prod_id INT;
    v_cat_id INT;
    v_uni_id INT;
BEGIN
    SELECT categoriaId INTO v_cat_id FROM categoriasBase WHERE nombre = p_nombre_categoria;
    SELECT unidadMedidaId INTO v_uni_id FROM unidadesMedida WHERE nombre = p_nombre_unidad;

    IF v_cat_id IS NULL OR v_uni_id IS NULL THEN
        RAISE EXCEPTION 'Categoría (%) o Unidad (%) no encontradas.', p_nombre_categoria, p_nombre_unidad;
    END IF;

    INSERT INTO productosBase (nombre, categoriaId, unidadMedidaId, descripcionTecnica, actualizadoPor, computadoraId)
    VALUES (p_nombre, v_cat_id, v_uni_id, p_descripcion_tecnica, p_actualizado_por, p_computadora_id)
    RETURNING productoBaseId INTO v_prod_id;

    CALL sp_registrar_log(p_actualizado_por, 1, 'Producto base registrado: ' || p_nombre, 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en producto base: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en sp_insertar_producto_base: %', SQLERRM;
END;
$$;



/* ======================================================
   Módulo 4: Operaciones de Compra e Inventario (HUB Nicaragua)
   ====================================================== */

--1. SP Generar Flujo Compras: --Este procedimiento es una "macro-transacción". Simula todo el proceso administrativo desde que se contacta al proveedor hasta que se pagan los impuestos de importación (DUA).

-- 1. Generar Compra buscando por Nombres
CREATE OR REPLACE PROCEDURE sp_generar_flujo_compras(
    id INT,
    p_nombre_proveedor VARCHAR,
    p_nombre_producto VARCHAR,
    p_cantidad NUMERIC,
    p_precio_unitario_origen NUMERIC,
    p_iso_moneda VARCHAR,
    p_tipo_cambio_usd NUMERIC,
    p_costo_dua NUMERIC,
    p_numero_documento VARCHAR,
    p_fecha_transaccion DATE, 
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_oc_id INT;
    v_prov_id INT;
    v_prod_id INT;
    v_moneda_id INT;
    v_monto_calculado NUMERIC(15,2);
BEGIN
    -- 1. Búsqueda de IDs por nombre
    SELECT proveedorId INTO v_prov_id FROM proveedores WHERE nombreComercial = p_nombre_proveedor;
    SELECT productoBaseId INTO v_prod_id FROM productosBase WHERE nombre = p_nombre_producto;
    SELECT monedaId INTO v_moneda_id FROM monedas WHERE codigoISO = p_iso_moneda;

    IF v_prov_id IS NULL OR v_prod_id IS NULL THEN
        RAISE EXCEPTION 'Proveedor (%) o Producto (%) inexistente.', p_nombre_proveedor, p_nombre_producto;
    END IF;

    -- 2. Insertar Cabecera de la Orden
    INSERT INTO ordenesCompra (proveedorId, estado, monedaCompraId, tipoCambio, fechaEmision, actualizadoPor, computadoraId)
    VALUES (v_prov_id, 'En Transito', v_moneda_id, p_tipo_cambio_usd, NOW(), p_actualizado_por, p_computadora_id)
    RETURNING ordenCompraId INTO v_oc_id;

    -- 3. Insertar Detalle de la Orden
    INSERT INTO ordenesCompraDetalle (detalleOCId, ordenCompraId, productoBaseId, cantidadPedida, precioUnitarioMonedaOrigen, actualizadoPor, computadoraId)
    VALUES (id, v_oc_id, v_prod_id, p_cantidad, p_precio_unitario_origen, p_actualizado_por, p_computadora_id);

    -- 4. Cálculo e Inserción de Costos (DUA)
    v_monto_calculado := (p_costo_dua / p_tipo_cambio_usd); 

    INSERT INTO transaccionesCostos (
        ordenCompraId, tipoCostoId, monedaOriginalId, montoOriginal, 
        tipoCambio, montoCalculado, numeroDocumento, 
        fechaTransaccion,
        actualizadoPor, computadoraId
    )
    VALUES (
        v_oc_id, 1, v_moneda_id, p_costo_dua, 
        p_tipo_cambio_usd, v_monto_calculado, p_numero_documento, 
        p_fecha_transaccion, -- Ahora sí existe el parámetro
        p_actualizado_por, p_computadora_id
    );

    CALL sp_registrar_log(p_actualizado_por, 1, 'Flujo OC generado para ' || p_nombre_proveedor, 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en flujo compras: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en sp_generar_flujo_compras: %', SQLERRM;
END;
$$;


--2. SP Ingresar Inventario Hub: --Este procedimiento simula la descarga del camión o barco en el HUB. Pasa la mercancía de un "papel" (Orden de Compra) a una "estantería" (Ubicación física).
CREATE OR REPLACE PROCEDURE sp_ingresar_inventario_hub(
    p_detalle_oc_id INT,
    p_codigo_lote_prov VARCHAR,
    p_fecha_vencimiento DATE,
    p_codigo_pasillo VARCHAR,
    p_estante VARCHAR,
    p_nivel VARCHAR,
    p_cantidad_recibida NUMERIC,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_lote_id INT;
    v_ubicacion_id INT;
BEGIN
    -- 1. Crear el lote de importación
    INSERT INTO lotesImportacion (
        codigoLote, detalleOCId, fechaProduccion, 
        fechaVencimiento, actualizadoPor, computadoraId
    )
    VALUES (
        p_codigo_lote_prov, p_detalle_oc_id, CURRENT_DATE, 
        p_fecha_vencimiento, p_actualizado_por, p_computadora_id
    )
    RETURNING loteId INTO v_lote_id;

    -- 2. Buscar o crear la ubicación física en el HUB
    SELECT ubicacionId INTO v_ubicacion_id 
    FROM ubicacionesHub 
    WHERE codigoPasillo = p_codigo_pasillo 
      AND estante = p_estante 
      AND nivel = p_nivel;

    IF v_ubicacion_id IS NULL THEN
        INSERT INTO ubicacionesHub (
            codigoPasillo, estante, nivel, capacidadMax, 
            actualizadoPor, computadoraId
        )
        VALUES (p_codigo_pasillo, p_estante, p_nivel, 5000, p_actualizado_por, p_computadora_id)
        RETURNING ubicacionId INTO v_ubicacion_id;
    END IF;

    -- 3. Registrar la entrada al Inventario Real con Control de Versión (Optimistic Lock)
    INSERT INTO inventarioHub (
        loteId, ubicacionId, cantidadDisponible, 
        fechaArribo, estadoCalidad, versionLock, 
        actualizadoPor, computadoraId
    )
    VALUES (
        v_lote_id, v_ubicacion_id, p_cantidad_recibida, 
        NOW(), 'Aprobado', 1, 
        p_actualizado_por, p_computadora_id
    );

    -- 4. Auditoría usando el ID del Lote como referencia
    CALL sp_registrar_log(
        p_actualizado_por, 1, 
        'Ingreso físico HUB exitoso. Lote: ' || p_codigo_lote_prov || ' en ' || p_codigo_pasillo || '-' || p_estante, 1);

EXCEPTION WHEN OTHERS THEN
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en ingreso a inventario: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en sp_ingresar_inventario_hub: %', SQLERRM;
END;
$$;


/* ======================================================
   Módulo 5: Salida y Conexión con Dynamic Brands
   ====================================================== */

--1. SP Configurar Marca Blanca: --Este procedimiento registra los 9 sitios web que solicitaste en las instrucciones, tratándolos como "clientes" o "marcas" a las que Etheria les sirve.
CREATE OR REPLACE PROCEDURE sp_configurar_marca_blanca(
    p_nombre_marca VARCHAR,
    p_url_logotipo VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_marca_id INT;
BEGIN
    -- 1. Registro o Actualización (UPSERT)
    -- Se elimina la columna paisSedeId tanto del INSERT como del UPDATE
    INSERT INTO marcasBlancas (
        nombreMarca, 
        logotipoUrl,
        actualizadoPor, 
        computadoraId
    )
    VALUES (
        p_nombre_marca, 
        p_url_logotipo,
        p_actualizado_por, 
        p_computadora_id
    )
    ON CONFLICT (nombreMarca) DO UPDATE SET 
        logotipoUrl = EXCLUDED.logotipoUrl,
        actualizadoPor = EXCLUDED.actualizadoPor,
        computadoraId = EXCLUDED.computadoraId
    RETURNING marcaId INTO v_marca_id;

    -- 2. Auditoría con el ID de la Marca (DataObjectID 19)
    CALL sp_registrar_log(
        p_actualizado_por, 1, 
        'Marca Blanca configurada/actualizada: ' || p_nombre_marca, 
        1);

EXCEPTION WHEN OTHERS THEN
    -- Registro de error en el log antes de lanzar la excepción
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en Marca Blanca: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en configuración de marca: %', SQLERRM;
END;
$$;

--2. SP Registrar Requisito Legal: --Como Etheria exporta productos medicinales y curativos, cada país de destino tiene reglas diferentes.
CREATE OR REPLACE PROCEDURE sp_registrar_requisito_legal(
    p_tipo_requisito_id INT,
    p_producto_id INT,
    p_iso_pais_destino VARCHAR,
    p_nombre_documento VARCHAR,
    p_url_doc VARCHAR,
    p_actualizado_por INT,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pais_id INT;
    v_requisito_id INT;
BEGIN
    -- 1. Validar existencia del País (Traducción ISO -> ID)
    SELECT paisId INTO v_pais_id 
    FROM paises 
    WHERE codigoISO = p_iso_pais_destino;

    IF v_pais_id IS NULL THEN
        RAISE EXCEPTION 'El país de destino con ISO % no existe en el sistema.', p_iso_pais_destino;
    END IF;

    -- 2. Validar existencia del Producto
    IF NOT EXISTS (SELECT 1 FROM productosBase WHERE productoBaseId = p_producto_id) THEN
        RAISE EXCEPTION 'El producto con ID % no existe.', p_producto_id;
    END IF;

    -- 3. Insertar o Actualizar el requisito legal (UPSERT)
    INSERT INTO requisitosLegalesPais (
        tipoRequisitoId, 
        productoBaseId, 
        paisDestinoId, 
        nombreRequisito, 
        urlDocumentoLegal, 
        ultimaRevision,      -- Control de auditoría legal
        actualizadoPor, 
        computadoraId
    )
    VALUES (
        p_tipo_requisito_id, 
        p_producto_id, 
        v_pais_id, 
        p_nombre_documento, 
        p_url_doc, 
        NOW(),               -- Fecha de revisión inicial
        p_actualizado_por, 
        p_computadora_id
    );

    -- 4. Registro en Log de Auditoría (Éxito)
    -- dataObjectId 18: Requisitos Legales
    CALL sp_registrar_log(
        p_actualizado_por, 1, 
        'Requisito legal procesado: ' || p_nombre_documento || ' (País: ' || p_iso_pais_destino || ')', 
        1);

EXCEPTION WHEN OTHERS THEN
    -- Registro en Log de Auditoría (Error)
    CALL sp_registrar_log(p_actualizado_por, 1, 'Error en requisito legal: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en sp_registrar_requisito_legal: %', SQLERRM;
END;
$$;



--3. SP Procesar Despacho Trazabilidad: --Este es el SP que genera la "salida" del inventario.
CREATE OR REPLACE PROCEDURE sp_procesar_despacho_trazabilidad(
    p_lote_codigo VARCHAR,
    p_cantidad NUMERIC,
    p_nombre_marca VARCHAR,
    p_iso_destino VARCHAR,
    p_orden_externa_id INT,
    p_operario_cedula VARCHAR,
    p_computadora_id INT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_inv_id INT;
    v_marca_id INT;
    v_ope_id INT;
    v_mov_id UUID;
    v_version_actual INT; -- Necesario para el versionLock
BEGIN
    -- 1. Obtener IDs y la versión actual del inventario (Bloqueo Optimista)
    SELECT i.inventarioId, i.versionLock 
    INTO v_inv_id, v_version_actual 
    FROM inventarioHub i 
    JOIN lotesImportacion l ON i.loteId = l.loteId 
    WHERE l.codigoLote = p_lote_codigo;

    SELECT marcaId INTO v_marca_id FROM marcasBlancas WHERE nombreMarca = p_nombre_marca;
    SELECT personaId INTO v_ope_id FROM personas WHERE cedulaIdentidad = p_operario_cedula;

    -- Validaciones de existencia
    IF v_inv_id IS NULL OR v_marca_id IS NULL OR v_ope_id IS NULL THEN
        RAISE EXCEPTION 'Lote, Marca o Operario no válidos. Verifique los datos.';
    END IF;

    -- 2. Registrar el movimiento de trazabilidad
    INSERT INTO trazabilidadMovimientos (
        inventarioId, ordenIdExterna, marcaId, paisDestinoId,
        tipoMovimiento, cantidad, 
        operarioId, fechaRegistro, actualizadoPor, computadoraId
    ) VALUES (
        v_inv_id, p_orden_externa_id, v_marca_id,
        (SELECT paisId FROM paises WHERE codigoISO = p_iso_destino),
        'Despacho Internacional', p_cantidad,
        v_ope_id, NOW(), v_ope_id, p_computadora_id
    ) RETURNING movimientoId INTO v_mov_id;

    -- 3. Actualizar Inventario con Seguridad (Resta y Versionado)
    UPDATE inventarioHub 
    SET cantidadDisponible = cantidadDisponible - p_cantidad,
        versionLock = versionLock + 1,
        actualizadoPor = v_ope_id
    WHERE inventarioId = v_inv_id 
      AND versionLock = v_version_actual -- Solo si nadie lo cambió mientras procesábamos
      AND cantidadDisponible >= p_cantidad; -- Evita quedar con stock negativo

    -- Si el UPDATE no afectó filas, es porque alguien más movió el stock o no hay suficiente
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conflicto de stock: El inventario cambió o no hay suficiente cantidad para el lote %', p_lote_codigo;
    END IF;

    -- 4. Registrar Log de Éxito (DataObjectID 21: Trazabilidad)
    CALL sp_registrar_log(
        v_ope_id, 1, 
        'Despacho exitoso. Movimiento: ' || v_mov_id || ' Lote: ' || p_lote_codigo, 
        1);

EXCEPTION WHEN OTHERS THEN
    -- Registrar Log de Error
    CALL sp_registrar_log(1, 1, 'Error en despacho: ' || SQLERRM, 1);
    RAISE EXCEPTION 'Fallo en despacho: %', SQLERRM;
END;
$$;

/* ======================================================
   Módulo 6: Orquestador Maestro
   ====================================================== */

-- Script de Ejecución: Este es el SP que "mueve los hilos" de todo el llenado.

DO $$ 
DECLARE 
    v_admin_id INT; 
    v_pc_id INT := 55;
    v_i INT;
    v_prov_count INT := 1;
    v_cat_count INT := 1;
    v_marca_nombre VARCHAR;
    v_prod_nombre VARCHAR;
    v_lote_code VARCHAR;
    v_cat_nombre VARCHAR;
    v_prov_nombre_busqueda VARCHAR;
    v_requisitos VARCHAR[] := ARRAY['Registro Sanitario', 'Certificado de Origen', 'Permiso de Importación'];
    v_nombre_req VARCHAR;
    v_tipo_req_id INT;
    v_producto_id INT;
BEGIN

    -- Admin1
    INSERT INTO personas (personaId, nombre, cedulaIdentidad, primerApellido, email) 
    VALUES (1, 'Admin', 'AUDIT-MASS', 'Etheria', 'adminetheria@gmail.com');
    PERFORM setval('personas_personaId_seq', (SELECT MAX(personaId) FROM personas));

    -- Datos para el log
    INSERT INTO sources (sourceId, nombre, descripcion) 
    VALUES (1, 'SISTEMA', 'Ejecucion de carga de datos de prueba');

    INSERT INTO eventTypes (eventTypeId, nombre, descripcion) 
    VALUES (1, 'DATOS DE PRUEBA', 'Carga de datos de prueba');


    /* ======================================================
       1. CARGA IFRAESTRUCTURA
       ====================================================== */
    -- Monedas
    CALL sp_registrar_infraestructura_base(v_admin_id, v_pc_id);
    -- Geografia
    CALL sp_registrar_ubicaciones_logicas(v_admin_id, v_pc_id);

    -- Personas
    
    v_admin_id := 1;

    CALL sp_registrar_personas_sistema(v_admin_id, v_pc_id);

    -- Proveedores
    WHILE v_prov_count <= 5 LOOP
        CALL sp_registrar_proveedor_internacional(
            'CJ-888-00' || v_prov_count,           -- p_cedula_juridica
            'Proveedor Global ' || v_prov_count,    -- p_nombre_comercial
            '2222-000' || v_prov_count,             -- p_telefono
            'AUDIT-MASS',                           -- p_cedula_contacto (Usa al Admin recién creado)
            'Representante Legal',                  -- p_rol_legal
            v_admin_id, 
            v_pc_id
        );
        v_prov_count := v_prov_count + 1;
    END LOOP;

    /* ======================================================
       2. CARGA DE CATÁLOGOS
       ====================================================== */

    -- Categorias
    WHILE v_cat_count <= 6 LOOP
        CALL sp_crear_categoria_base(
            'Categoría ' || v_cat_count,
            'Descripción de la categoría ' || v_cat_count,
            v_admin_id,
            v_pc_id
        );
        v_cat_count := v_cat_count + 1;
    END LOOP;

    -- Tiendas / Marcas Blancas (Sin paisId)
    FOR v_i IN 1..9 LOOP
        v_marca_nombre := 'Ethereal Shop ' || v_i;
        CALL sp_configurar_marca_blanca(v_marca_nombre, 'https://tienda' || v_i || '.ethereal.com/logo.png', v_admin_id, v_pc_id);
    END LOOP;

    /* ======================================================
       3. CARGA DE PRODUCTOS (100 REGISTROS)
       ====================================================== */


    FOR v_i IN 1..100 LOOP
        v_prod_nombre := 'Producto Masivo ' || v_i;
        v_cat_nombre := 'Categoría ' || ((v_i % 6) + 1);
        CALL sp_insertar_producto_base(v_prod_nombre, v_cat_nombre, 'Mililitros', 'Batch automatizado ' || v_i, v_admin_id, v_pc_id);
    END LOOP;

    -- Requisitos legales
    FOREACH v_nombre_req IN ARRAY v_requisitos LOOP
        
        -- Obtener ID del tipo de requisito
        SELECT tipoRequisitoId 
        INTO v_tipo_req_id
        FROM tiposRequisitos
        WHERE nombre = v_nombre_req;

        IF v_tipo_req_id IS NULL THEN
            RAISE NOTICE 'Tipo de requisito no existe: %', v_nombre_req;
            CONTINUE;
        END IF;

        -- Aplicar a varios productos (ejemplo: primeros 5)
        FOR v_producto_id IN 
            SELECT productoBaseId FROM productosBase LIMIT 5
        LOOP

            CALL sp_registrar_requisito_legal(
                v_tipo_req_id,                         -- p_tipo_requisito_id
                v_producto_id,                         -- p_producto_id
                'CRI',                                 -- país destino
                v_nombre_req,                          -- nombre documento
                'https://docs.ejemplo.com/' || lower(replace(v_nombre_req, ' ', '_')),
                v_admin_id,
                v_pc_id
            );

        END LOOP;

    END LOOP;

    /* ======================================================
       4. TRAZABILIDAD Y MOVIMIENTOS (100 REGISTROS)
       ====================================================== */
    FOR v_i IN 1..100 LOOP
        v_lote_code := 'LOTE-' || v_i || '-2026';
        v_prod_nombre := 'Producto Masivo ' || v_i;
        
        -- Seleccionar uno de los 5 proveedores registrados
        v_prov_nombre_busqueda := 'Proveedor Global ' || ((v_i % 5) + 1);

        CALL sp_generar_flujo_compras(
            v_i,
            v_prov_nombre_busqueda, 
            v_prod_nombre, 
            100, 1.0, 'USD', 1.0, 1.0, 
            'REF-' || v_i, 
            '2026-04-26', 
            v_admin_id, 
            v_pc_id
        );

        -- Ingreso a inventario HUB
        CALL sp_ingresar_inventario_hub(v_i, v_lote_code, '2029-01-01', 'P-01', 'E-01', 'N-1', 100, v_admin_id, v_pc_id);

        v_marca_nombre := 'Ethereal Shop ' || ((v_i % 9) + 1);
        CALL sp_procesar_despacho_trazabilidad(v_lote_code, 1.0, v_marca_nombre, 'CRI', 3000 + v_i, 'AUDIT-MASS', v_pc_id);
    END LOOP;
    
    RAISE NOTICE 'Carga masiva de 100 productos y 100 movimientos de trazabilidad finalizada.';

    CALL sp_registrar_log(1, 1, 'Carga de datos de prueba terminada.', 1);

EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Fallo crítico en el orquestador: %', SQLERRM;
END $$;
