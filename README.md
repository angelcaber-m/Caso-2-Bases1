# Caso #2  

**Curso:** Bases de Datos 1  
**Semestre:** Primer Semestre 2026  
**Institución:** Tecnológico de Costa Rica – Escuela de Ingeniería en Computación  

## Integrantes

| Carnet      | Nombre completo               | 
|-------------|-------------------------------|
| 2024253434  | Angélica Cabrera Bermúdez     |
| 2024800621  | Estefanía Portuguez Víquez    |

# Ejecutar el proyecto 

<details>
  <summary>Desplegar pasos</summary>

## 1) Bases de datos y repositorio central
1. Levantar el entorno.
- Desde la raíz del proyecto:
```bash
docker-compose up --build
```
2. Esperar a que finalice el proceso ETL.

## 2) Dashboard
1. Abrir la carpeta Dashboard.
   
2. Abrir el archivo "Dashboard Caso 2.pbix" con Power BI Desktop.
   
3. Conectarse a la base de datos PostgreSQL:
    - Servidor: localhost:5432
    - Base de datos: RepositorioCentralCaso2
    - Usuario: postgres
    - Contraseña: 123456
