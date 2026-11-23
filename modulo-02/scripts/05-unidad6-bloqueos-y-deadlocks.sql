-- ============================================================================
-- MÓDULO 2 - UNIDAD 6: BLOQUEOS (BLOCKING) E INTERBLOQUEOS (DEADLOCKS)
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

USE LabRendimientoSQL;
GO

-- ============================================================================
-- 1. IDENTIFICAR CADENAS DE BLOQUEO Y BLOQUEADOR PRINCIPAL (HEAD BLOCKER)
-- ============================================================================
SELECT
    r.session_id,
    r.blocking_session_id,
    r.wait_type,
    r.wait_time,
    r.wait_resource,
    t.text AS query_text,
    r.status,
    r.command
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0
ORDER BY r.wait_time DESC;
GO

-- ============================================================================
-- 2. CONSULTAR GRÁFICOS DE INTERBLOQUEO DESDE EXTENDED EVENTS (system_health)
--    (En Azure SQL Database se usa CREATE EVENT SESSION [deadlocks] ON DATABASE
--     con el evento sqlserver.database_xml_deadlock_report)
-- ============================================================================
SELECT
    xed.value('@timestamp', 'datetime2') AS deadlock_time,
    xed.query('.') AS deadlock_xml_graph
FROM (
    SELECT CAST(target_data AS XML) AS target_data
    FROM sys.dm_xe_session_targets AS st
    INNER JOIN sys.dm_xe_sessions AS s
        ON s.address = st.event_session_address
    WHERE s.name = N'system_health'
      AND st.target_name = N'ring_buffer'
) AS data
CROSS APPLY target_data.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS xevents(xed)
ORDER BY deadlock_time DESC;
GO

-- ============================================================================
-- 3. PATRÓN DE REINTENTO EN APLICACIÓN / T-SQL PARA ERROR 1205 (DEADLOCK)
-- ============================================================================
DECLARE @RetryCount INT = 0;
DECLARE @MaxRetries INT = 3;
DECLARE @Success BIT = 0;

WHILE @RetryCount < @MaxRetries AND @Success = 0
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Products
        SET StockCount = StockCount
        WHERE ProductID = 42;

        COMMIT TRANSACTION;
        SET @Success = 1;
        PRINT 'Transacción completada exitosamente sin interbloqueos.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 1205
        BEGIN
            SET @RetryCount += 1;
            PRINT 'Error 1205 (Deadlock detectado). Reintentando (' + CAST(@RetryCount AS VARCHAR(5)) + ')...';
            WAITFOR DELAY '00:00:01'; -- Pausa breve antes de reintentar
        END
        ELSE
        BEGIN
            THROW;
        END
    END CATCH
END
GO