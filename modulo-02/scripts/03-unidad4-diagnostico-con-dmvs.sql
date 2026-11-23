-- ============================================================================
-- MÓDULO 2 - UNIDAD 4: DIAGNÓSTICO DE RENDIMIENTO CON VISTAS DINÁMICAS (DMV)
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

USE LabRendimientoSQL;
GO

-- 0. Generar carga de trabajo de prueba para poblar estadísticas en las DMVs
IF OBJECT_ID('dbo.VentasHistoricas', 'U') IS NOT NULL DROP TABLE dbo.VentasHistoricas;
GO

CREATE TABLE dbo.VentasHistoricas (
    VentaID INT IDENTITY(1,1) PRIMARY KEY,
    ClienteID INT NOT NULL,
    Region NVARCHAR(30) NOT NULL,
    Monto DECIMAL(10,2) NOT NULL,
    FechaVenta DATE NOT NULL
);

-- Insertar 10,000 filas de prueba
INSERT INTO dbo.VentasHistoricas (ClienteID, Region, Monto, FechaVenta)
SELECT TOP 10000
    ABS(CHECKSUM(NEWID())) % 500 + 1,
    CASE ABS(CHECKSUM(NEWID())) % 4
        WHEN 0 THEN 'Azuero'
        WHEN 1 THEN 'Panama'
        WHEN 2 THEN 'Chiriqui'
        ELSE 'Colon'
    END,
    CAST((ABS(CHECKSUM(NEWID())) % 10000) / 10.0 AS DECIMAL(10,2)),
    DATEADD(DAY, -(ABS(CHECKSUM(NEWID())) % 365), GETDATE())
FROM sys.all_objects a CROSS JOIN sys.all_objects b;

-- Ejecutar consultas repetidas sin índice en ClienteID/Region para generar actividad DMV
SELECT Region, COUNT(*) AS TotalVentas, SUM(Monto) AS Ingresos
FROM dbo.VentasHistoricas
WHERE ClienteID = 125 AND Region = 'Azuero'
GROUP BY Region;
GO 5

-- ============================================================================
-- 1. IDENTIFICAR LAS 10 CONSULTAS MÁS COSTOSAS POR CPU Y LECTURAS LÓGICAS
-- ============================================================================
SELECT TOP 10
    qs.total_worker_time / qs.execution_count AS avg_cpu_time,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2) + 1) AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY avg_cpu_time DESC;
GO

-- ============================================================================
-- 2. SUPERVISAR CONSULTAS ACTIVAS EN TIEMPO REAL Y DETECCIÓN DE BLOQUEOS
-- ============================================================================
SELECT
    r.session_id,
    r.status,
    r.command,
    r.wait_type,
    r.wait_time,
    r.blocking_session_id,
    r.cpu_time,
    r.logical_reads,
    t.text AS query_text
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC;
GO

-- ============================================================================
-- 3. DETECCIÓN DE ÍNDICES FALTANTES RECOMENDADOS POR EL OPTIMIZADOR
-- ============================================================================
SELECT
    mid.statement AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.avg_total_user_cost * migs.avg_user_impact *
        (migs.user_seeks + migs.user_scans) AS improvement_measure
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;
GO