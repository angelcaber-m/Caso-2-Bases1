-- Agregar a la tabla dim_tiempo los datos del año 2026
DO $$
DECLARE
    fecha_inicio DATE := '2026-01-01';
    fecha_fin DATE := '2026-12-31';
    fecha_actual DATE;
BEGIN
    fecha_actual := fecha_inicio;
    WHILE fecha_actual <= fecha_fin LOOP
        INSERT INTO dim_tiempo (
            tiempo_key, 
            fecha, 
            anio, 
            mes, 
            mes_nombre, 
            trimestre, 
            dia_semana_nombre
        ) VALUES (
            CAST(TO_CHAR(fecha_actual, 'YYYYMMDD') AS INT),
            fecha_actual,
            EXTRACT(YEAR FROM fecha_actual),
            EXTRACT(MONTH FROM fecha_actual),
            -- TMMonth quita espacios extra y sigue el idioma del servidor
            TRIM(TO_CHAR(fecha_actual, 'TMMonth')), 
            EXTRACT(QUARTER FROM fecha_actual),
            TRIM(TO_CHAR(fecha_actual, 'TMDay'))
        );
        fecha_actual := fecha_actual + INTERVAL '1 day';
    END LOOP;
    
    RAISE NOTICE 'Dimensión Tiempo cargada exitosamente para el año 2026';
END $$;