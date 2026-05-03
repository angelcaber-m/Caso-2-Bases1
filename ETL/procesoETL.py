import pandas as pd
from sqlalchemy import create_engine, text
import datetime
import time

# --- CONFIG ESPERA DE BASES DE DATOS ---
MAX_RETRIES = 30
RETRY_DELAY = 5  # segundos

# --- CONEXIONES ---
engine_etheria = create_engine('postgresql+psycopg2://postgres:123456@postgres_etheria:5432/EtheriaGlobal')

engine_dynamic = create_engine('mysql+pymysql://root:123456@mysql_dynamic:3306/DynamicBrands')

engine_dw = create_engine('postgresql+psycopg2://postgres:123456@postgres_central:5432/RepositorioCentralCaso2')

# --- FUNCIÓN DE ESPERA ---
def wait_for_connection(engine, name):
    for i in range(MAX_RETRIES):
        try:
            with engine.connect() as conn:
                conn.execute(text("SELECT 1"))
            print(f"✅ Conexión lista: {name}")
            return
        except Exception:
            print(f"⏳ Esperando conexión a {name}... ({i+1}/{MAX_RETRIES})")
            time.sleep(RETRY_DELAY)
    raise Exception(f"No se pudo conectar a {name}")



def limpiar_repositorio():
    tablas = ['fact_operaciones_globales', 'dim_productos', 'dim_tiendas', 'dim_geografia']
    with engine_dw.connect() as conn:
        for tabla in tablas:
            conn.execute(text(f"TRUNCATE TABLE {tabla} RESTART IDENTITY CASCADE;"))
            conn.commit()
    print("🧹 Repositorio limpio.")


def run_full_etl():
    print(f"[{datetime.datetime.now()}] Iniciando ETL...")

    try:
        # Se espera a que se hayan conectado las bases
        wait_for_connection(engine_etheria, "EtheriaGlobal")
        wait_for_connection(engine_dynamic, "DynamicBrands")
        wait_for_connection(engine_dw, "RepositorioCentralCaso2")
        
        limpiar_repositorio()

        # =============================
        # 1. DIM_GEOGRAFIA
        # =============================
        df_geo = pd.concat([
            pd.read_sql("SELECT nombre FROM paises", engine_etheria),
            pd.read_sql("SELECT nombre FROM paises", engine_dynamic)
        ]).drop_duplicates()

        df_geo.rename(columns={'nombre': 'pais_nombre'}, inplace=True)
        df_geo.to_sql('dim_geografia', engine_dw, if_exists='append', index=False)
        print("✔ Geografía")

        # =============================
        # 2. DIM_TIENDAS
        # =============================
        df_tiendas = pd.read_sql("""
            SELECT 
                t.tiendaId as tienda_id_origen,
                t.nombre as nombre_tienda,
                p.nombre as pais_tienda,
                m.codigoISO as moneda_nativa
            FROM tiendas t
            JOIN paises p ON t.paisId = p.paisId
            JOIN monedas m ON t.monedaId = m.monedaId
        """, engine_dynamic)

        df_tiendas['enfoque_marketing'] = 'General'
        df_tiendas.to_sql('dim_tiendas', engine_dw, if_exists='append', index=False)
        print("✔ Tiendas")

        # =============================
        # 3. DIM_PRODUCTOS
        # =============================
        df_eth_prod = pd.read_sql("""
            SELECT 
                pb.productobaseid as producto_base_id_origen,
                pb.nombre as nombre_insumo_base,
                c.nombre as categoria
            FROM productosbase pb
            JOIN categoriasbase c ON pb.categoriaid = c.categoriaid
        """, engine_etheria)

        df_dyn_prod = pd.read_sql("""
            SELECT 
                productoMarcaBlancaId as producto_marca_id_origen,
                productoBaseId as producto_base_id_origen,
                nombreComercial as nombre_marca_blanca
            FROM productosMarcasBlancas
        """, engine_dynamic)

        df_dim_prod = pd.merge(df_dyn_prod, df_eth_prod, on='producto_base_id_origen')

        df_dim_prod['categoria'] = df_dim_prod['categoria'].fillna('NA')

        df_dim_prod['sku_global'] = (
            df_dim_prod['categoria'].str[:3].str.upper() + "-" +
            df_dim_prod['producto_base_id_origen'].astype(str) + "-XX"
        )

        df_dim_prod.to_sql('dim_productos', engine_dw, if_exists='append', index=False)
        print("✔ Productos")

        # =============================
        # 4. FACT BASE
        # =============================
        df_ventas = pd.read_sql("""
            SELECT 
                o.ordenId as orden_id_mysql,
                o.tiendaId,
                o.monto as venta_bruta,
                o.fechaCreacion,
                cl.monto as costo_envio,
                op.productoMarcaBlancaId,
                e.numeroGuia as numero_guia_tracking
            FROM ordenes o
            LEFT JOIN envios e ON o.ordenId = e.ordenId
            LEFT JOIN costosLogistica cl ON e.envioId = cl.envioId
            JOIN productosOrdenes op ON o.ordenId = op.ordenId
        """, engine_dynamic)

        df_dw_prod = pd.read_sql("""
            SELECT producto_key, producto_marca_id_origen, categoria 
            FROM dim_productos
        """, engine_dw)

        df_dw_tienda = pd.read_sql("""
            SELECT tienda_key, tienda_id_origen, pais_tienda, moneda_nativa 
            FROM dim_tiendas
        """, engine_dw)

        df_geo_dw = pd.read_sql("""
            SELECT geografia_key, pais_nombre 
            FROM dim_geografia
        """, engine_dw)

        df_final = pd.merge(df_ventas, df_dw_prod,
                            left_on='productoMarcaBlancaId',
                            right_on='producto_marca_id_origen')

        df_final = pd.merge(df_final, df_dw_tienda,
                            left_on='tiendaId',
                            right_on='tienda_id_origen')

        # =============================
        # 5. JOIN GEOGRAFÍA
        # =============================
        df_final = pd.merge(df_final, df_geo_dw,
                            left_on='pais_tienda',
                            right_on='pais_nombre',
                            how='left')

        # =============================
        # 6. EXCHANGE RATES
        # =============================
        df_rates = pd.read_sql("""
            SELECT 
                m.codigoISO as moneda,
                er.exchangeRate
            FROM exchangeRates er
            JOIN monedas m ON er.monedaOrigenId = m.monedaId
            JOIN monedas md ON er.monedaDestinoId = md.monedaId
            WHERE md.codigoISO = 'USD'
                AND er.esActual = 1
        """, engine_dynamic)

        df_final = pd.merge(df_final, df_rates,
                            left_on='moneda_nativa',
                            right_on='moneda',
                            how='left')

        df_final['exchangeRate'] = df_final['exchangeRate'].replace(0, 1).fillna(1)

        # =============================
        # 7. CÁLCULOS
        # =============================
        df_final['tiempo_id'] = pd.to_datetime(df_final['fechaCreacion']).dt.strftime('%Y%m%d').astype(int)

        df_final['monto_venta_bruta_base'] = df_final['venta_bruta'] * df_final['exchangeRate']
        df_final['costo_envio_base'] = df_final['costo_envio'].fillna(0) * df_final['exchangeRate']

        costos_categoria = {
            'Categoría 1': 0.35,
            'Categoría 2': 0.40,
            'Categoría 3': 0.45,
            'Categoría 4': 0.50,
            'Categoría 5': 0.55,
            'Categoría 6': 0.60
        }

        df_final['costo_insumo_base'] = df_final.apply(
            lambda x: x['monto_venta_bruta_base'] * costos_categoria.get(x['categoria'], 0.45),
            axis=1
        )

        impuestos_pais = {
            'Costa Rica': 0.13,
            'México': 0.16,
            'Colombia': 0.19,
            'Panamá': 0.07,
            'Guatemala': 0.12
        }

        df_final['costo_arancel_impuestos_base'] = df_final.apply(
            lambda x: x['monto_venta_bruta_base'] * impuestos_pais.get(x['pais_tienda'], 0.12),
            axis=1
        )

        df_final['margen_contribucion_base'] = (
            df_final['monto_venta_bruta_base']
            - df_final['costo_insumo_base']
            - df_final['costo_envio_base']
            - df_final['costo_arancel_impuestos_base']
        )

        df_final['porcentaje_margen'] = (
            df_final['margen_contribucion_base'] /
            df_final['monto_venta_bruta_base']
        ) * 100

        # =============================
        # 8. CARGA FINAL
        # =============================
        df_fact = df_final[[
            'tiempo_id',
            'producto_key',
            'tienda_key',
            'geografia_key',
            'orden_id_mysql',
            'monto_venta_bruta_base',
            'costo_insumo_base',
            'costo_envio_base',
            'costo_arancel_impuestos_base',
            'margen_contribucion_base',
            'porcentaje_margen',
            'numero_guia_tracking'
        ]].rename(columns={
            'producto_key': 'producto_id',
            'tienda_key': 'tienda_id',
            'geografia_key': 'geografia_id'
        })

        df_fact.to_sql('fact_operaciones_globales', engine_dw, if_exists='append', index=False)

        print(f"✔ Hechos cargados: {len(df_fact)}")
        print(f"[{datetime.datetime.now()}] ETL COMPLETADO")

    except Exception as e:
        print(f"❌ ERROR EN ETL: {e}")


if __name__ == "__main__":
    run_full_etl()
