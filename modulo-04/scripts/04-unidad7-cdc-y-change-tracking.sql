USE LabDataAPI;
GO

-- ============================================================================
-- MÓDULO 4 - UNIDAD 7: CHANGE TRACKING Y CHANGE DATA CAPTURE (CDC)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. HABILITAR CHANGE TRACKING (Requerido por Azure Functions SQL Trigger)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_databases WHERE database_id = DB_ID('LabDataAPI'))
BEGIN
    ALTER DATABASE LabDataAPI
    SET CHANGE_TRACKING = ON
    (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.change_tracking_tables WHERE object_id = OBJECT_ID('dbo.Orders'))
BEGIN
    ALTER TABLE dbo.Orders
    ENABLE CHANGE_TRACKING
    WITH (TRACK_COLUMNS_UPDATED = ON);
END
GO

-- ----------------------------------------------------------------------------
-- 2. HABILITAR CHANGE DATA CAPTURE - CDC (Auditoría histórica completa)
-- Nota: Si SQL Server Agent no está activo en Docker, la captura registra
-- metadatos y puede iniciarse con EXEC sys.sp_cdc_start_job;
-- ----------------------------------------------------------------------------
IF (SELECT is_cdc_enabled FROM sys.databases WHERE name = 'LabDataAPI') = 0
BEGIN
    EXEC sys.sp_cdc_enable_db;
END
GO

IF NOT EXISTS (SELECT 1 FROM cdc.change_tables WHERE source_object_id = OBJECT_ID('dbo.Orders'))
BEGIN
    EXEC sys.sp_cdc_enable_table
        @source_schema = N'dbo',
        @source_name = N'Orders',
        @role_name = NULL,
        @capture_instance = N'dbo_Orders',
        @supports_net_changes = 1;
END
GO

-- ----------------------------------------------------------------------------
-- 3. GENERAR EVENTOS DE PRUEBA (INSERT Y UPDATE SOBRE dbo.Orders)
-- ----------------------------------------------------------------------------
DECLARE @CurrentVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION();

INSERT INTO dbo.Orders (CustomerID, OrderDate, Status)
VALUES (2, SYSUTCDATETIME(), 'Processing');

UPDATE dbo.Orders
SET Status = 'Completed'
WHERE OrderID = 1;
GO

-- ----------------------------------------------------------------------------
-- 4. CONSULTAR CAMBIOS MEDIANTE CHANGE TRACKING (CHANGETABLE)
-- ----------------------------------------------------------------------------
SELECT 
    ct.OrderID,
    ct.SYS_CHANGE_VERSION,
    ct.SYS_CHANGE_OPERATION AS Operacion_CT, -- 'I' = Insert, 'U' = Update, 'D' = Delete
    o.CustomerID,
    o.Status
FROM CHANGETABLE(CHANGES dbo.Orders, 0) AS ct
LEFT JOIN dbo.Orders AS o ON ct.OrderID = o.OrderID;
GO

-- ----------------------------------------------------------------------------
-- 5. VERIFICAR CONFIGURACIÓN ACTIVA DE CDC Y CHANGE TRACKING
-- ----------------------------------------------------------------------------
SELECT 
    name AS BaseDatos,
    is_cdc_enabled AS CDC_Habilitado
FROM sys.databases
WHERE name = 'LabDataAPI';

SELECT 
    capture_instance AS Instancia_CDC,
    supports_net_changes AS Soporta_Cambios_Netos,
    create_date AS Fecha_Creacion
FROM cdc.change_tables;
GO