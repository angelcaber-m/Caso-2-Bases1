-- Stored procedures para creacion de logs y llenado de datos base, que servirán para poder registrar ordenes y envios --

USE DynamicBrands;

DELIMITER $$

/* ======================================================
   1. AUDITORÍA E INFRAESTRUCTURA (LA BASE)
   ====================================================== */

-- SP independiente que registra cada paso ejecutado en las tablas de destino --
DROP PROCEDURE IF EXISTS sp_registrar_log $$
CREATE PROCEDURE sp_registrar_log(
    IN p_descripcion VARCHAR(500),
    IN p_evento_nombre VARCHAR(75),
    IN p_severidad_nombre VARCHAR(75),
    IN p_source_nombre VARCHAR(75)
)
BEGIN
    DECLARE v_eventId, v_sevId, v_srcId INT;

    SELECT eventTypeId INTO v_eventId FROM eventTypes WHERE nombre = p_evento_nombre LIMIT 1;
    SELECT severityId INTO v_sevId FROM severities WHERE nombre = p_severidad_nombre LIMIT 1;
    SELECT sourceId INTO v_srcId FROM sources WHERE nombre = p_source_nombre LIMIT 1;

    IF v_eventId IS NOT NULL AND v_sevId IS NOT NULL AND v_srcId IS NOT NULL THEN
        INSERT INTO logs (eventTypeId, descripcion, sourceId, severityId, fechaRegistro)
        VALUES (v_eventId, p_descripcion, v_srcId, v_sevId, NOW());
    END IF;
END $$

DROP PROCEDURE IF EXISTS sp_llenar_catalogos_logs $$
CREATE PROCEDURE sp_llenar_catalogos_logs(
    IN p_tabla VARCHAR(50), 
    IN p_nombre VARCHAR(75), 
    IN p_desc VARCHAR(200)
)
BEGIN
        -- Nota: Si falla el llenado de catálogos, no se pueden hacer logs, 
        -- así que se deja pasar para no detener el despliegue total
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN END;
    CASE p_tabla
        WHEN 'sources' THEN INSERT IGNORE INTO sources (nombre, descripcion) VALUES (p_nombre, p_desc);
        WHEN 'logTypes' THEN INSERT IGNORE INTO logTypes (nombre, descripcion) VALUES (p_nombre, p_desc);
        WHEN 'severities' THEN INSERT IGNORE INTO severities (nombre, descripcion) VALUES (p_nombre, p_desc);
        WHEN 'dataObjects' THEN INSERT IGNORE INTO dataObjects (nombre, descripcion) VALUES (p_nombre, p_desc);
    END CASE;
    -- Nota: Aquí no se llama a sp_registrar_log porque se está llenando la base para los log.
END $$

DROP PROCEDURE IF EXISTS sp_llenar_event_types $$
CREATE PROCEDURE sp_llenar_event_types(
    IN p_log_type VARCHAR(75),
    IN p_evento VARCHAR(75),
    IN p_desc VARCHAR(200)
)
BEGIN
    DECLARE v_logId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN END;
    SELECT logTypeId INTO v_logId FROM logTypes WHERE nombre = p_log_type LIMIT 1;
    IF v_logId IS NOT NULL THEN
        INSERT IGNORE INTO eventTypes (logTypeId, nombre, descripcion) VALUES (v_logId, p_evento, p_desc);
    END IF;
    -- Nota: Aquí no se llama a sp_registrar_log porque se está llenando la base para los log.
END $$

/* ======================================================
   2. CATÁLOGOS Y OPERACIONES
   ====================================================== */

DROP PROCEDURE IF EXISTS sp_llenar_geografia $$
CREATE PROCEDURE sp_llenar_geografia(
    IN p_pais VARCHAR(75), IN p_iso VARCHAR(3), IN p_estado VARCHAR(50), IN p_ciudad VARCHAR(50)
)
BEGIN
    DECLARE v_pId, v_eId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Geografía: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;

    SELECT paisId INTO v_pId FROM paises WHERE nombre = p_pais LIMIT 1;
    IF v_pId IS NULL THEN
        INSERT INTO paises (nombre, codigoISO) VALUES (p_pais, p_iso);
        SET v_pId = LAST_INSERT_ID();
    END IF;

    SELECT estadoId INTO v_eId FROM estados WHERE nombre = p_estado AND paisId = v_pId LIMIT 1;
    IF v_eId IS NULL THEN
        INSERT INTO estados (paisId, nombre) VALUES (v_pId, p_estado);
        SET v_eId = LAST_INSERT_ID();
    END IF;

    INSERT INTO ciudades (estadoId, nombre) VALUES (v_eId, p_ciudad);
    CALL sp_registrar_log(CONCAT('Ciudad cargada: ', p_ciudad), 'Paso Completado', 'Info', 'Sistema Llenado');
END $$

DROP PROCEDURE IF EXISTS sp_registrar_exchange_history $$
CREATE PROCEDURE sp_registrar_exchange_history(IN p_exRateId INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Historial: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;

    INSERT INTO exchangeHistory (fechaInicio, fechaFin, exchangeRateId, exchangeRate, monedaOrigenId, monedaDestinoId)
    SELECT validFrom, NOW(), exchangeRateId, exchangeRate, monedaOrigenId, monedaDestinoId
    FROM exchangeRates WHERE exchangeRateId = p_exRateId;
END $$

DROP PROCEDURE IF EXISTS sp_llenar_monedas_tasas $$
CREATE PROCEDURE sp_llenar_monedas_tasas(
    IN p_moneda VARCHAR(75), IN p_simbolo VARCHAR(5), IN p_iso VARCHAR(3), 
    IN p_pais_nombre VARCHAR(75), IN p_tasa DECIMAL(18,6)
)
BEGIN
    DECLARE v_pId, v_mId, v_usdId, v_exActualId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Monedas: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;

    SELECT paisId INTO v_pId FROM paises WHERE nombre = p_pais_nombre LIMIT 1;
    SELECT monedaId INTO v_usdId FROM monedas WHERE codigoISO = 'USD' LIMIT 1;

    -- Insertar moneda si no existe
    INSERT INTO monedas (nombre, simbolo, codigoISO, paisId) VALUES (p_moneda, p_simbolo, p_iso, v_pId);
    SET v_mId = LAST_INSERT_ID();

    -- Desactivar tasa anterior si existe
    SELECT exchangeRateId INTO v_exActualId FROM exchangeRates 
    WHERE monedaOrigenId = v_mId AND monedaDestinoId = v_usdId AND esActual = 1 LIMIT 1;

    IF v_exActualId IS NOT NULL THEN
        UPDATE exchangeRates SET esActual = 0 WHERE exchangeRateId = v_exActualId;
    END IF;

    -- Insertar la nueva tasa (o la primera)
    INSERT INTO exchangeRates (monedaOrigenId, monedaDestinoId, exchangeRate, esActual, validFrom)
    VALUES (v_mId, v_usdId, p_tasa, 1, NOW());
    
    SET v_exActualId = LAST_INSERT_ID();

    -- Registramos en el historial SIEMPRE, incluso la primera vez
    CALL sp_registrar_exchange_history(v_exActualId);
    
    CALL sp_registrar_log(CONCAT('Moneda y tasa (con historial) lista: ', p_iso), 'Paso Completado', 'Info', 'Sistema Llenado');
END $$

DROP PROCEDURE IF EXISTS sp_llenar_catalogos_ia $$
CREATE PROCEDURE sp_llenar_catalogos_ia(IN p_tipo VARCHAR(50), IN p_nombre VARCHAR(100))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Catálogos IA: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;

    CASE p_tipo
        WHEN 'Atributo' THEN INSERT INTO tiposDeDatosAtributos (nombre) VALUES (p_nombre);
        WHEN 'Medida' THEN INSERT INTO unidadesDeMedida (medida) VALUES (p_nombre);
        WHEN 'Orden' THEN INSERT INTO estadosOrden (nombre) VALUES (p_nombre);
        WHEN 'Envio' THEN INSERT INTO estadosEnvio (nombre) VALUES (p_nombre);
        WHEN 'EventoEnvio' THEN INSERT INTO eventosEnvio (nombre) VALUES (p_nombre);
    END CASE;
    CALL sp_registrar_log(CONCAT('IA Cat: ', p_nombre), 'Paso Completado', 'Info', 'Sistema Llenado');
END $$

DROP PROCEDURE IF EXISTS sp_llenar_atributos_base $$
CREATE PROCEDURE sp_llenar_atributos_base(IN p_nombre VARCHAR(75), IN p_desc VARCHAR(200))
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Atributos EAV: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;
    INSERT INTO atributos (nombre, descripcion) VALUES (p_nombre, p_desc);
    CALL sp_registrar_log(CONCAT('Atributo EAV: ', p_nombre), 'Paso Completado', 'Info', 'Sistema Llenado');
END $$

/* ======================================================
   3. DINÁMICA DE IA Y LOGÍSTICA
   ====================================================== */

DROP PROCEDURE IF EXISTS sp_crear_tiendas_dinamicas $$
CREATE PROCEDURE sp_crear_tiendas_dinamicas(
    IN p_nombre VARCHAR(50), IN p_dominio VARCHAR(255), IN p_pais VARCHAR(75), 
    IN p_concepto VARCHAR(500), IN p_apariencia JSON
)
BEGIN
    DECLARE v_pId, v_mId, v_tId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Tienda: ', @msg), 'Excepción', 'Critical', 'Motor IA');
    END;

    SELECT paisId INTO v_pId FROM paises WHERE nombre = p_pais LIMIT 1;
    SELECT monedaId INTO v_mId FROM monedas WHERE paisId = v_pId LIMIT 1;

    INSERT INTO tiendas (nombre, dominio, paisId, monedaId) VALUES (p_nombre, p_dominio, v_pId, v_mId);
    SET v_tId = LAST_INSERT_ID();

    INSERT INTO conceptosTiendas (tiendaId, descripcion, apariencia) VALUES (v_tId, p_concepto, p_apariencia);
    CALL sp_registrar_log(CONCAT('Tienda IA: ', p_nombre), 'Paso Completado', 'Info', 'Motor IA');
END $$

DROP PROCEDURE IF EXISTS sp_crear_productos_marcas_blancas $$
CREATE PROCEDURE sp_crear_productos_marcas_blancas(
    IN p_tienda VARCHAR(50), 
    IN p_nombre VARCHAR(50), 
    IN p_medida VARCHAR(30), 
    IN p_atributo VARCHAR(75), 
    IN p_valor VARCHAR(255), 
    IN p_tipo_dato VARCHAR(50),
    IN p_producto_base_id INT
)
BEGIN
    DECLARE v_tId, v_uId, v_prodId, v_aId, v_tdId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Producto: ', @msg), 'Excepción', 'Critical', 'Motor IA');
    END;

    SELECT tiendaId INTO v_tId FROM tiendas WHERE nombre = p_tienda LIMIT 1;
    SELECT unidadDeMedidaId INTO v_uId FROM unidadesDeMedida WHERE medida = p_medida LIMIT 1;
    SELECT atributoId INTO v_aId FROM atributos WHERE nombre = p_atributo LIMIT 1;
    SELECT tipoDeDatoAtributoId INTO v_tdId FROM tiposDeDatosAtributos WHERE nombre = p_tipo_dato LIMIT 1;

    INSERT INTO productosMarcasBlancas (tiendaId, nombreComercial, unidadDeMedidaId, productoBaseId) 
    VALUES (v_tId, p_nombre, v_uId, p_producto_base_id);
    
    SET v_prodId = LAST_INSERT_ID();

    INSERT INTO valoresDeAtributos (productoMarcaBlancaId, atributoId, valor, tipoDeDatoAtributoId)
    VALUES (v_prodId, v_aId, p_valor, v_tdId);
    
    CALL sp_registrar_log(CONCAT('Producto IA: ', p_nombre, ' (Base ID: ', p_producto_base_id, ')'), 'Paso Completado', 'Info', 'Motor IA');
END $$

DROP PROCEDURE IF EXISTS sp_generar_etiquetas_productos $$
CREATE PROCEDURE sp_generar_etiquetas_productos(
    IN p_producto VARCHAR(50), 
    IN p_specs JSON, 
    IN p_adv VARCHAR(500),
    IN p_trazabilidad_id INT
)
BEGIN
    DECLARE v_prodId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Etiqueta: ', @msg), 'Excepción', 'Critical', 'Motor IA');
    END;

    SELECT productoMarcaBlancaId INTO v_prodId FROM productosMarcasBlancas WHERE nombreComercial = p_producto LIMIT 1;
    
    INSERT INTO instruccionesEtiquetas (productoMarcaBlancaId, especificacionesTecnicas, advertenciasConsumo, trazabilidadId) 
    VALUES (v_prodId, p_specs, p_adv, p_trazabilidad_id);
    
    CALL sp_registrar_log(CONCAT('Etiqueta: ', p_producto), 'Paso Completado', 'Info', 'Motor IA');
END $$

DROP PROCEDURE IF EXISTS sp_llenar_clientes $$
CREATE PROCEDURE sp_llenar_clientes(
    IN p_nombre VARCHAR(50), 
    IN p_apellido1 VARCHAR(50), 
    IN p_apellido2 VARCHAR(50),
    IN p_telefono VARCHAR(20)
)
BEGIN
    DECLARE v_correo VARCHAR(100);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Cliente: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;

    -- Generar correo dinámico para evitar el error de UNIQUE
    SET v_correo = LOWER(CONCAT(p_nombre, '.', p_apellido1, '@mail.com'));

    INSERT INTO clientes (nombre, primerApellido, segundoApellido, correo, telefono, contraseña) 
    VALUES (p_nombre, p_apellido1, p_apellido2, v_correo, p_telefono, AES_ENCRYPT('Password123!', 'key_secreta'));

    CALL sp_registrar_log(CONCAT('Cliente registrado: ', p_nombre, ' ', p_apellido1), 'Paso Completado', 'Info', 'Sistema Llenado');
END $$

DROP PROCEDURE IF EXISTS sp_llenar_couriers $$
CREATE PROCEDURE sp_llenar_couriers(IN p_nombre VARCHAR(100), IN p_cedula VARCHAR(20), IN p_ciudad VARCHAR(50), IN p_dir VARCHAR(255))
BEGIN
    DECLARE v_cId, v_dId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Courier: ', @msg), 'Excepción', 'Critical', 'Sistema Llenado');
    END;

    SELECT ciudadId INTO v_cId FROM ciudades WHERE nombre = p_ciudad LIMIT 1;
    INSERT INTO direcciones (ciudadId, primeraLinea) VALUES (v_cId, p_dir);
    SET v_dId = LAST_INSERT_ID();
    INSERT INTO couriers (nombre, ceduldaJuridica, direccionId) VALUES (p_nombre, p_cedula, v_dId);
    CALL sp_registrar_log(CONCAT('Courier: ', p_nombre), 'Paso Completado', 'Info', 'Sistema Llenado');
END $$

/* ======================================================
   4. ORQUESTADOR MAESTRO (LLENADO MASIVO)
   ====================================================== */

DROP PROCEDURE IF EXISTS sp_ejecutar_llenado_total $$
CREATE PROCEDURE sp_ejecutar_llenado_total()
BEGIN
    -- Variables de control para bucles
    DECLARE i INT DEFAULT 1;
    DECLARE v_temp_pais VARCHAR(75);
    DECLARE v_temp_tienda VARCHAR(50);
    DECLARE v_temp_producto VARCHAR(50);

    -- 1. BOOTSTRAP DE AUDITORÍA (Indispensable para que sp_registrar_log funcione) (Sin logs hasta que existan catálogos)
    CALL sp_llenar_catalogos_logs('sources', 'Sistema Llenado', 'Proceso de carga masiva');
    CALL sp_llenar_catalogos_logs('sources', 'Motor IA', 'Generación de contenido dinámico');
    CALL sp_llenar_catalogos_logs('sources', 'Ventas',  'Procesador de Órdenes');
    CALL sp_llenar_catalogos_logs('sources', 'Logística',  'Procesador de Envíos');
    CALL sp_llenar_catalogos_logs('sources', 'Finanzas',  'Procesador de Costos');
    CALL sp_llenar_catalogos_logs('logTypes', 'Transaccional', 'Registro de operaciones DB');
    CALL sp_llenar_catalogos_logs('severities', 'Info', 'Ejecución normal');
    CALL sp_llenar_catalogos_logs('severities', 'Critical', 'Fallo de integridad');
    CALL sp_llenar_event_types('Transaccional', 'Paso Completado', 'Éxito en procedimiento');
    CALL sp_llenar_event_types('Transaccional', 'Excepción', 'Error capturado en handler');

    -- 1.5. A partir de aquí ya se pueden registrar logs
    CALL sp_registrar_log('Bootstrap completo. Iniciando orquestación de 5 países, 9 tiendas y 100 productos', 'Paso Completado', 'Info', 'Sistema Llenado');

    -- 2. GEOGRAFÍA Y FINANZAS (5 Países)
    -- Insertamos USD como base primero
    INSERT IGNORE INTO monedas (nombre, codigoISO) VALUES ('Dólar', 'USD');

    CALL sp_llenar_geografia('Costa Rica', 'CRI', 'San José', 'Escazú');
    CALL sp_llenar_monedas_tasas('Colón', '₡', 'CRC', 'Costa Rica', 0.0022);

    CALL sp_llenar_geografia('México', 'MEX', 'CDMX', 'Coyoacán');
    CALL sp_llenar_monedas_tasas('Peso Mexicano', '$', 'MXN', 'México', 0.058);

    CALL sp_llenar_geografia('Colombia', 'COL', 'Antioquia', 'Medellín');
    CALL sp_llenar_monedas_tasas('Peso Colombiano', '$', 'COP', 'Colombia', 0.00028);

    CALL sp_llenar_geografia('Panamá', 'PAN', 'Panamá', 'Casco Viejo');
    CALL sp_llenar_monedas_tasas('Balboa', 'B/.', 'PAB', 'Panamá', 1.00);

    CALL sp_llenar_geografia('Guatemala', 'GUA', 'Guatemala', 'Mixco');
    CALL sp_llenar_monedas_tasas('Quetzal', 'Q', 'GTQ', 'Guatemala', 0.13);

    -- 3. CATÁLOGOS IA (5 datos por tabla)
    -- Tipos de Datos
    CALL sp_llenar_catalogos_ia('Atributo', 'Alfanumérico');
    CALL sp_llenar_catalogos_ia('Atributo', 'Numérico');
    CALL sp_llenar_catalogos_ia('Atributo', 'Booleano');
    CALL sp_llenar_catalogos_ia('Atributo', 'Fecha');
    CALL sp_llenar_catalogos_ia('Atributo', 'JSON');

    -- Unidades de Medida
    CALL sp_llenar_catalogos_ia('Medida', 'Mililitros');
    CALL sp_llenar_catalogos_ia('Medida', 'Gramos');
    CALL sp_llenar_catalogos_ia('Medida', 'Onzas');
    CALL sp_llenar_catalogos_ia('Medida', 'Unidades');
    CALL sp_llenar_catalogos_ia('Medida', 'Litros');

    -- Estados y Eventos
    CALL sp_llenar_catalogos_ia('Orden', 'Pendiente');
    CALL sp_llenar_catalogos_ia('Orden', 'Pagado');
    CALL sp_llenar_catalogos_ia('Orden', 'Cancelado');
    CALL sp_llenar_catalogos_ia('Orden', 'Enviado');
    CALL sp_llenar_catalogos_ia('Orden', 'Entregado');

    CALL sp_llenar_catalogos_ia('Envio', 'En Bodega');
    CALL sp_llenar_catalogos_ia('Envio', 'En Tránsito');
    CALL sp_llenar_catalogos_ia('Envio', 'Reparto Local');
    CALL sp_llenar_catalogos_ia('Envio', 'Retenido');
    CALL sp_llenar_catalogos_ia('Envio', 'Devuelto');

    CALL sp_llenar_catalogos_ia('EventoEnvio', 'Recolección');
    CALL sp_llenar_catalogos_ia('EventoEnvio', 'Salida de Aduana');
    CALL sp_llenar_catalogos_ia('EventoEnvio', 'Llegada a Hub');
    CALL sp_llenar_catalogos_ia('EventoEnvio', 'Intento de Entrega');
    CALL sp_llenar_catalogos_ia('EventoEnvio', 'Confirmación de Firma');

    -- Atributos EAV
    CALL sp_llenar_atributos_base('Aroma', 'Fragancia natural del producto');
    CALL sp_llenar_atributos_base('Pureza', 'Porcentaje de concentración');
    CALL sp_llenar_atributos_base('Origen Bio', 'Certificación de origen orgánico');
    CALL sp_llenar_atributos_base('PH', 'Nivel de acidez/alcalinidad');
    CALL sp_llenar_atributos_base('Vida Útil', 'Meses antes de caducar');

    -- 4. TIENDAS DINÁMICAS (9 Sitios)
    SET i = 1;
    WHILE i <= 9 DO
        SET v_temp_pais = CASE (i % 5) 
            WHEN 0 THEN 'Costa Rica' WHEN 1 THEN 'México' WHEN 2 THEN 'Colombia' 
            WHEN 3 THEN 'Panamá' ELSE 'Guatemala' END;
        
        SET v_temp_tienda = CONCAT('Ethereal Shop ', i);
        
        CALL sp_crear_tiendas_dinamicas(
            v_temp_tienda, 
            CONCAT('tienda', i, '.ethereal.com'), 
            v_temp_pais, 
            CONCAT('Concepto de bienestar número ', i), 
            JSON_OBJECT('color_primario', '#2ecc71', 'fuente', 'Roboto')
        );
        SET i = i + 1;
    END WHILE;

    -- 5. PRODUCTOS Y ETIQUETAS (100 Productos)
    SET i = 1;
    WHILE i <= 100 DO
        -- Rotamos los productos entre las 9 tiendas creadas
        SET v_temp_tienda = CONCAT('Ethereal Shop ', (i % 9) + 1);
        SET v_temp_producto = CONCAT('Producto Natural ', i);
        
        CALL sp_crear_productos_marcas_blancas(
            v_temp_tienda, 
            v_temp_producto, 
            'Mililitros', 
            'Pureza', 
            '99.9%', 
            'Alfanumérico',
            i
        );
        
        -- Generar etiqueta para el producto recién creado
        CALL sp_generar_etiquetas_productos(
            v_temp_producto, 
            JSON_OBJECT('sku', CONCAT('SKU-', 1000+i), 'lote', CONCAT('L-', i)), 
            'Manténgase en un lugar fresco y seco.',
            i
        );
        SET i = i + 1;
    END WHILE;

    -- 6. LOGÍSTICA (20 Clientes y 10 Couriers)
    SET i = 1;
    WHILE i <= 20 DO
        CALL sp_llenar_clientes(
            CONCAT('Persona', i),   -- Nombre
            CONCAT('ApellidoA', i),            -- Primer Apellido
            CONCAT('ApellidoB', i),            -- Segundo Apellido
            CONCAT('8000-', 1000+i) -- Teléfono
        );
        SET i = i + 1;
    END WHILE;

    SET i = 1;
    WHILE i <= 10 DO
        CALL sp_llenar_couriers(
            CONCAT('Courier Logística ', i), 
            CONCAT('3-101-', 100000 + i), 
            'Escazú', 
            CONCAT('Bodega Industrial sección ', i)
        );
        SET i = i + 1;
    END WHILE;

    CALL sp_registrar_log('Llenado masivo completado con éxito.', 'Paso Completado', 'Info', 'Sistema Llenado');

END $$

DELIMITER ;


-- Stored procedures para crear ordenes y envios --

USE DynamicBrands;

DELIMITER $$

/* ======================================================
   1. REGISTRO DE ÓRDENES (JSON + DIRECCIÓN DINÁMICA)
   ====================================================== */
DROP PROCEDURE IF EXISTS sp_registrar_orden_maestra $$
CREATE PROCEDURE sp_registrar_orden_maestra(
    IN p_tienda_nombre VARCHAR(50),
    IN p_cliente_correo VARCHAR(100),
    IN p_ciudad_nombre VARCHAR(50),
    IN p_primera_linea VARCHAR(150),
    IN p_notas VARCHAR(300),
    IN p_productos_json JSON,
    OUT p_ordenId INT
)
BEGIN
    DECLARE v_ordenId INT;
    DECLARE v_tiendaId, v_clienteId, v_direccionId, v_ciudadId, v_estadoId, v_paisId, v_monedaId, v_usdId, v_exRateId INT;
    DECLARE v_tasa DECIMAL(18,6);
    DECLARE v_montoLocalTotal, v_montoTotal DECIMAL(18,6) DEFAULT 0;
    DECLARE i INT DEFAULT 0;
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_prod_cant INT;
    DECLARE v_productoMarcaId INT;
    DECLARE v_prod_nombre VARCHAR(50);
    DECLARE v_prod_precio, v_prod_montoLocal, v_prod_monto DECIMAL(18,6);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Orden: ', @msg), 'Excepción', 'Critical', 'Ventas');
    END;

    -- Búsqueda de IDs
    SELECT tiendaId, paisId INTO v_tiendaId, v_paisId FROM tiendas WHERE nombre = p_tienda_nombre LIMIT 1;
    SELECT clienteId INTO v_clienteId FROM clientes WHERE correo = p_cliente_correo LIMIT 1;
    SELECT ciudadId INTO v_ciudadId FROM ciudades WHERE nombre = p_ciudad_nombre LIMIT 1;
    SELECT estadoOrdenId INTO v_estadoId FROM estadosOrden WHERE nombre = 'Pendiente' LIMIT 1;
    
    SELECT monedaId INTO v_monedaId FROM monedas WHERE paisId = v_paisId LIMIT 1;
    SELECT monedaId INTO v_usdId FROM monedas WHERE codigoISO = 'USD' LIMIT 1;

    SELECT exchangeRateId, exchangeRate INTO v_exRateId, v_tasa 
    FROM exchangeRates WHERE monedaOrigenId = v_monedaId AND monedaDestinoId = v_usdId AND esActual = 1 LIMIT 1;

    -- Gestión de Dirección
    SELECT direccionId INTO v_direccionId FROM direcciones WHERE ciudadId = v_ciudadId AND primeraLinea = p_primera_linea AND deleted = 0 LIMIT 1;
    IF v_direccionId IS NULL THEN
        INSERT INTO direcciones (ciudadId, primeraLinea, postTime) VALUES (v_ciudadId, p_primera_linea, NOW());
        SET v_direccionId = LAST_INSERT_ID();
    END IF;

    -- Cálculos Totales
    SET i = 0;
    SET v_count = JSON_LENGTH(p_productos_json);
    WHILE i < v_count DO
        SET v_prod_precio = JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', i, '].precioUnitario')));
        SET v_prod_cant = JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', i, '].cantidad')));
        SET v_montoLocalTotal = v_montoLocalTotal + (v_prod_cant * v_prod_precio);
        SET i = i + 1;
    END WHILE;
    SET v_montoTotal = v_montoLocalTotal * v_tasa;

    -- Inserción Orden e Historial Inicial
    INSERT INTO ordenes (tiendaId, clienteId, estadoOrdenId, monedaId, direccionEnvioId, montoLocal, monto, exchangeRateId, notas)
    VALUES (v_tiendaId, v_clienteId, v_estadoId, v_monedaId, v_direccionId, v_montoLocalTotal, v_montoTotal, v_exRateId, p_notas);
    SET v_ordenId = LAST_INSERT_ID();
    SET p_ordenId = v_ordenId;

    CALL sp_registrar_log(CONCAT('Orden: ', v_ordenId, ' creada'), 'Paso Completado', 'Info', 'Ventas');

    INSERT INTO historialEstadosOrdenes (ordenId, estadoNuevoId, fechaRegistro) VALUES (v_ordenId, v_estadoId, NOW());
    CALL sp_registrar_log(CONCAT('Historial del estado de la orden ', v_ordenId, ' registrado'), 'Paso Completado', 'Info', 'Ventas');

    -- Detalle de Productos
    SET i = 0;
    SET v_count = JSON_LENGTH(p_productos_json);
    WHILE i < v_count DO
        SET v_prod_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', i, '].nombre')));
        SET v_prod_cant = JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', i, '].cantidad')));
        SET v_prod_precio = JSON_UNQUOTE(JSON_EXTRACT(p_productos_json, CONCAT('$[', i, '].precioUnitario')));
        SET v_prod_montoLocal = v_prod_cant * v_prod_precio;
        SET v_prod_monto = v_prod_montoLocal * v_tasa;
        
        SELECT productoMarcaBlancaId INTO v_productoMarcaId FROM productosMarcasBlancas WHERE nombreComercial = v_prod_nombre LIMIT 1;
        
        IF v_productoMarcaId IS NULL THEN
            CALL sp_registrar_log(CONCAT('Producto NO encontrado: ', v_prod_nombre, ' tiendaId: ', v_tiendaId), 'Excepción', 'Critical', 'Ventas');
        ELSE
            INSERT INTO productosOrdenes (ordenId, productoMarcaBlancaId, cantidad, monedaId, precioUnitario, montoLocal, monto, exchangeRateId)
            VALUES (v_ordenId, v_productoMarcaId, v_prod_cant, v_monedaId, v_prod_precio, v_prod_montoLocal, v_prod_monto, v_exRateId);
        END IF;

        SET i = i + 1;
    END WHILE;
    CALL sp_registrar_log(CONCAT('Orden ', v_ordenId, ' creada, con sus productos'), 'Paso Completado', 'Info', 'Ventas');
END $$

/* ======================================================
   2. GESTIÓN DE ENVÍOS Y RASTREO
   ====================================================== */
DROP PROCEDURE IF EXISTS sp_registrar_envio_completo $$
CREATE PROCEDURE sp_registrar_envio_completo(
    IN p_orden_id INT,
    IN p_courier_nombre VARCHAR(100),
    IN p_estado_envio VARCHAR(50),
    IN p_evento_inicial VARCHAR(75),
    IN p_ciudad_rastreo VARCHAR(50),
    IN p_linea_rastreo VARCHAR(150),
    OUT p_envioId INT
)
BEGIN
    DECLARE v_envId INT;
    DECLARE v_courId, v_estEnvId, v_eveId, v_dirId INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Envío: ', @msg), 'Excepción', 'Critical', 'Logística');
    END;

    SELECT courierId INTO v_courId FROM couriers WHERE nombre = p_courier_nombre LIMIT 1;
    SELECT estadoEnvioId INTO v_estEnvId FROM estadosEnvio WHERE nombre = p_estado_envio LIMIT 1;
    SELECT eventoEnvioId INTO v_eveId FROM eventosEnvio WHERE nombre = p_evento_inicial LIMIT 1;
    SELECT direccionId INTO v_dirId FROM direcciones WHERE primeraLinea = p_linea_rastreo LIMIT 1;

    INSERT INTO envios (ordenId, courierId, estadoEnvioId, fechaDespacho) VALUES (p_orden_id, v_courId, v_estEnvId, NOW());
    SET v_envId = LAST_INSERT_ID();
    SET p_envioId = v_envId;

    INSERT INTO rastreosEnvios (envioId, eventoEnvioId, direccionId, fecha, comentario)
    VALUES (v_envId, v_eveId, v_dirId, NOW(), 'Inicio de tránsito logístico');
    
    CALL sp_registrar_log(CONCAT('Envío ', v_envId, ' iniciado'), 'Paso Completado', 'Info', 'Logística');
END $$

/* ======================================================
   3. COSTOS LOGÍSTICOS
   ====================================================== */
DROP PROCEDURE IF EXISTS sp_registrar_costo_logistico_inicial $$
CREATE PROCEDURE sp_registrar_costo_logistico_inicial(
    IN p_envio_id INT,
    IN p_monto_local DECIMAL(18,6),
    IN p_tipo_costo_id INT 
)
BEGIN
    DECLARE v_ordId, v_exRateId, v_costoId INT;
    DECLARE v_tasa, v_monto DECIMAL(18,6);
    DECLARE v_monedaId INT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION 
    BEGIN
        GET DIAGNOSTICS CONDITION 1 @msg = MESSAGE_TEXT;
        CALL sp_registrar_log(CONCAT('Error Costo Logístico: ', @msg), 'Excepción', 'Critical', 'Procesador Finanzas');
    END;

    -- 1. BÚSQUEDA (Heredar de la orden vinculada al envío)
    SELECT ordenId INTO v_ordId FROM envios WHERE envioId = p_envio_id LIMIT 1;
    SELECT exchangeRateId INTO v_exRateId FROM ordenes WHERE ordenId = v_ordId LIMIT 1;
    SELECT exchangeRate INTO v_tasa FROM exchangeRates WHERE exchangeRateId = v_exRateId LIMIT 1;
    SELECT monedaId INTO v_monedaId FROM ordenes WHERE ordenId = v_ordId LIMIT 1;

    -- 2. CÁLCULOS
    SET v_monto = p_monto_local * v_tasa;

    -- 3. ESCRITURAS
    INSERT INTO costosLogistica (envioId, monedaId, montoLocal, monto, exchangeRateId, tipoCostoId)
    VALUES (p_envio_id, v_monedaId, p_monto_local, v_monto, v_exRateId, p_tipo_costo_id);
    
    SET v_costoId = LAST_INSERT_ID();

    -- Registro en Historial de Costos (Movimiento Inicial)
    INSERT INTO historialCostosLogistica (costoLogisticaId, monedaLocal, exchangeRateId, montoLocalAnterior, montoAnterior, montoLocalNuevo, montoNuevo, comentario)
    VALUES (v_costoId, v_monedaId, v_exRateId, 0.00, 0.00, p_monto_local, v_monto, 'Apertura de costos de envío');

    -- 4. REGISTRO DE LOG
    CALL sp_registrar_log(CONCAT('Costo logístico registrado. ID: ', v_costoId, ' para Envío: ', p_envio_id), 'Paso Completado', 'Info', 'Finanzas');
END $$

/* ======================================================
   4. ORQUESTADOR DE TRANSACCIONES (50 ÓRDENES)
   ====================================================== */
DROP PROCEDURE IF EXISTS sp_llenado_transaccional_masivo $$
CREATE PROCEDURE sp_llenado_transaccional_masivo()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE v_json_prod JSON;
    DECLARE v_correo VARCHAR(100);
    DECLARE v_ordenId INT;
    DECLARE v_envioId INT;

    WHILE i <= 50 DO
        -- Generar JSON con 2 productos dinámicos que coincidan con los 100 creados antes
        -- Construcción del correo:
        -- Si i=2, resulta: persona2.apellidoa2@mail.com
        SET v_correo = LOWER(CONCAT('persona', (i % 20) + 1, '.apellidoa', (i % 20) + 1, '@mail.com'));

        -- Generar JSON de productos
        SET v_json_prod = JSON_ARRAY(
            JSON_OBJECT('nombre', CONCAT('Producto Natural ', (i % 100) + 1), 'cantidad', 2.0, 'precioUnitario', (1500.00 * i)),
            JSON_OBJECT('nombre', CONCAT('Producto Natural ', ((i + 1) % 100) + 1), 'cantidad', 3.0, 'precioUnitario', (3000.00 * i))
        );

        -- 1. Crear la orden
        CALL sp_registrar_orden_maestra(
            CONCAT('Ethereal Shop ', (i % 9) + 1),
            v_correo, 
            'Escazú',
            CONCAT('Avenida Central, Casa ', i),
            'Nota de entrega',
            v_json_prod,
            v_ordenId
        );

        -- 2. Crear Envío usando el ID real
        CALL sp_registrar_envio_completo(
            v_ordenId, 
            CONCAT('Courier Logística ', (i % 10) + 1),
            'En Tránsito',
            'Recolección',
            'Escazú',
            CONCAT('Avenida Central, Casa ', i),
            v_envioId
        );

        -- 3. Registrar Costo usando el ID del envío real
        CALL sp_registrar_costo_logistico_inicial(v_envioId, (2500.00 * i), (i % 6) + 1);

        SET i = i + 1;
    END WHILE;
    
    CALL sp_registrar_log('Generación masiva de 50 órdenes completada.', 'Paso Completado', 'Info', 'Sistema');
END $$

DELIMITER ;


-- LLamados para ejecutar los stored procedures --

USE DynamicBrands;
-- Llenado de datos base
CALL sp_ejecutar_llenado_total();
-- Llenado de ordenes y envios
CALL sp_llenado_transaccional_masivo();


-- Revisar logs registrados --

-- USE DynamicBrands;

-- SELECT * FROM logs ORDER BY logId DESC;
