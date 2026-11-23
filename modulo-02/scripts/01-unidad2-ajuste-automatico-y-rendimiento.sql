-- ============================================================================
-- MÓDULO 2 - UNIDAD 2: AJUSTE AUTOMÁTICO Y CONFIGURACIÓN DE RENDIMIENTO
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

-- 1. Crear base de datos de laboratorio para el Módulo 2
IF DB_ID('LabRendimientoSQL') IS NULL
BEGIN
    CREATE DATABASE LabRendimientoSQL;
END
GO

USE LabRendimientoSQL;
GO

-- 2. Habilitar Query Store (requisito previo para que el ajuste automático
--    detecte regresiones de planes de ejecución)
ALTER DATABASE LabRendimientoSQL
SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE);
GO

-- 3. Configurar Ajuste Automático (Automatic Tuning)
--    En SQL Server 2022 local se soporta FORCE_LAST_GOOD_PLAN = ON.
--    (Nota: En Azure SQL Database también se admiten CREATE_INDEX y DROP_INDEX).
ALTER DATABASE LabRendimientoSQL
SET AUTOMATIC_TUNING (FORCE_LAST_GOOD_PLAN = ON);
GO

-- 4. Verificar y establecer el Nivel de Compatibilidad
--    SQL Server 2022 soporta hasta nivel 160 (Azure SQL / SQL 2025 soporta 170).
ALTER DATABASE LabRendimientoSQL
SET COMPATIBILITY_LEVEL = 160;
GO

-- 5. Reducir el sobredimensionamiento de la caché de planes ad-hoc
ALTER DATABASE SCOPED CONFIGURATION
SET OPTIMIZE_FOR_AD_HOC_WORKLOADS = ON;
GO

-- 6. Habilitar Recuperación Acelerada de Bases de Datos (ADR)
ALTER DATABASE LabRendimientoSQL
SET ACCELERATED_DATABASE_RECOVERY = ON;
GO

-- ============================================================================
-- 7. CONSULTAS DE AUDITORÍA Y VERIFICACIÓN DE CONFIGURACIÓN
-- ============================================================================
SELECT 
    d.name AS BaseDeDatos,
    d.compatibility_level AS NivelCompatibilidad,
    d.is_accelerated_database_recovery_on AS ADR_Habilitado,
    q.actual_state_desc AS EstadoQueryStore,
    q.query_capture_mode_desc AS ModoCapturaQueryStore
FROM sys.databases d
CROSS JOIN sys.database_query_store_options q
WHERE d.name = 'LabRendimientoSQL';

SELECT 
    name,
    desired_state_desc,
    actual_state_desc,
    reason_desc
FROM sys.database_automatic_tuning_options;

SELECT 
    name,
    value,
    value_for_secondary
FROM sys.database_scoped_configurations
WHERE name = 'OPTIMIZE_FOR_AD_HOC_WORKLOADS';
GO