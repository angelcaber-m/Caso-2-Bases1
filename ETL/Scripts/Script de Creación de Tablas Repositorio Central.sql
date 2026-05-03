-- ======================================================
-- REPOSITORIO CENTRAL: MODELO ESTRELLA OPTIMIZADO
-- Destino: PostgreSQL (RepositorioCentralCaso2)
-- ======================================================

-- 1. CONFIGURACIÓN Y PARÁMETROS DEL SISTEMA
CREATE TABLE sistema_parametros (
    parametro_id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE,
    valor VARCHAR(100),
    descripcion TEXT
);

INSERT INTO sistema_parametros (nombre, valor, descripcion) 
VALUES ('moneda_reporte_base', 'USD', 'Moneda de normalización para los hechos del Data Warehouse');

-- 2. DIMENSIONES (Contexto)

-- Dimensión de Tiempo
CREATE TABLE dim_tiempo (
    tiempo_key INT PRIMARY KEY, -- Formato YYYYMMDD
    fecha DATE NOT NULL,
    anio INT NOT NULL,
    mes INT NOT NULL,
    mes_nombre VARCHAR(20),
    trimestre INT NOT NULL,
    dia_semana_nombre VARCHAR(20),
    es_festivo BOOLEAN DEFAULT FALSE
);

-- Dimensión de Productos: Cruce Etheria (Insumo) <-> Dynamic (Marca Blanca)
-- Se agregaron los IDs de origen para facilitar el JOIN en el ETL
CREATE TABLE dim_productos (
    producto_key SERIAL PRIMARY KEY,
    producto_base_id_origen INT,      -- productoBaseld en Etheria
    producto_marca_id_origen INT,     -- productoMarcaBlancald en Dynamic Brands
    nombre_marca_blanca VARCHAR(255), 
    nombre_insumo_base VARCHAR(255),
    categoria VARCHAR(100),           -- De categoriasBase en Etheria
    pais_origen_insumo VARCHAR(100), 
    sku_global VARCHAR(50)            -- Generado por el ETL (CAT-ID-PAIS)
);

-- Dimensión de Tiendas: Incluye el país para segmentación geográfica
CREATE TABLE dim_tiendas (
    tienda_key SERIAL PRIMARY KEY,
    tienda_id_origen INT,             -- tiendaId en Dynamic
    nombre_tienda VARCHAR(150),
    pais_tienda VARCHAR(100),         -- Nombre del país normalizado
    enfoque_marketing TEXT,           -- Almacena el JSON o descripción del concepto
    moneda_nativa VARCHAR(5)          -- Moneda original (ej. MXN, COP, USD)
);

-- Dimensión de Geografía: Ubicaciones de entrega/clientes
CREATE TABLE dim_geografia (
    geografia_key SERIAL PRIMARY KEY,
    pais_nombre VARCHAR(100),
    region VARCHAR(100),
    ciudad VARCHAR(100),
    zona_logistica VARCHAR(100)
);

-- 3. TABLA DE HECHOS (Métricas de Operaciones y Rentabilidad)
-- Refleja los costos detallados en los scripts de origen
CREATE TABLE fact_operaciones_globales (
    operacion_key SERIAL PRIMARY KEY,
    
    -- Llaves foráneas
    tiempo_id INT REFERENCES dim_tiempo(tiempo_key),
    producto_id INT REFERENCES dim_productos(producto_key),
    tienda_id INT REFERENCES dim_tiendas(tienda_key),
    geografia_id INT REFERENCES dim_geografia(geografia_key),
    
    -- Métricas Financieras (Normalizadas a USD)
    monto_venta_bruta_base DECIMAL(18,2),         -- 'monto' en Dynamic Brands
    costo_insumo_base DECIMAL(18,2),               -- Estimado del 40% (Costo Etheria)
    costo_envio_base DECIMAL(18,2),                -- De tabla costosLogistica
    costo_arancel_impuestos_base DECIMAL(18,2),    -- Calculado (12% aprox)
    
    -- Cálculos de Rentabilidad
    margen_contribucion_base DECIMAL(18,2),        -- Neto después de costos
    porcentaje_margen DECIMAL(5,2),                -- (Margen / Venta) * 100
    
    -- Trazabilidad y Auditoría
    orden_id_mysql INT,                            -- Referencia a ordenes.ordenId
    lote_id_postgres INT,                          -- Referencia a lotes en Etheria
    numero_guia_tracking VARCHAR(100),             -- De la tabla envios
    fecha_carga_registro TIMESTAMP DEFAULT NOW()
);