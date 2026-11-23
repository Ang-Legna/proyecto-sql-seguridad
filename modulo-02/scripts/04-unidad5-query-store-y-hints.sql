-- ============================================================================
-- MÓDULO 2 - UNIDAD 5: ALMACÉN DE CONSULTAS (QUERY STORE) Y QUERY HINTS
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

USE LabRendimientoSQL;
GO

-- 1. Configurar captura de estadísticas de espera, limpieza automática y tamaño
ALTER DATABASE CURRENT
SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    SIZE_BASED_CLEANUP_MODE = AUTO,
    MAX_STORAGE_SIZE_MB = 1024,
    WAIT_STATS_CAPTURE_MODE = ON
);
GO

-- 2. Ejecutar una consulta de prueba para asegurar registros recientes en Query Store
SELECT COUNT(*) AS TotalPedidos, SUM(Monto) AS MontoTotal
FROM dbo.VentasHistoricas
WHERE Region = 'Azuero';
GO

-- ============================================================================
-- 3. CONSULTA DEL ALMACÉN DE CONSULTAS (TOP 10 POR DURACIÓN MEDIA)
-- ============================================================================
SELECT TOP 10
    qt.query_sql_text,
    q.query_id,
    p.plan_id,
    ROUND(CONVERT(FLOAT, SUM(rs.avg_duration * rs.count_executions))
        / NULLIF(SUM(rs.count_executions), 0), 2) AS avg_duration,
    SUM(rs.count_executions) AS total_executions
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
INNER JOIN sys.query_store_plan AS p
    ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
WHERE rs.last_execution_time > DATEADD(HOUR, -1, GETUTCDATE())
GROUP BY qt.query_sql_text, q.query_id, p.plan_id
ORDER BY avg_duration DESC;
GO

-- ============================================================================
-- 4. DEMOSTRACIÓN DINÁMICA: FORZAR PLAN Y APLICAR QUERY STORE HINTS
-- ============================================================================
DECLARE @TargetQueryID BIGINT;
DECLARE @TargetPlanID BIGINT;

SELECT TOP 1
    @TargetQueryID = q.query_id,
    @TargetPlanID = p.plan_id
FROM sys.query_store_query AS q
INNER JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
INNER JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE '%VentasHistoricas%'
  AND qt.query_sql_text NOT LIKE '%sys.query_store%';

IF @TargetQueryID IS NOT NULL AND @TargetPlanID IS NOT NULL
BEGIN
    -- Forzar el plan de ejecución conocido
    EXEC sp_query_store_force_plan
        @query_id = @TargetQueryID,
        @plan_id = @TargetPlanID;

    -- Aplicar sugerencias de rendimiento sin modificar el código de aplicación
    EXEC sp_query_store_set_hints
        @query_id = @TargetQueryID,
        @query_hints = N'OPTION (MAXDOP 1, MAX_GRANT_PERCENT = 10)';

    -- Consultar sugerencias activas registradas
    SELECT query_hint_id, query_id, query_hint_text, source_desc
    FROM sys.query_store_query_hints
    WHERE query_id = @TargetQueryID;

    -- Limpiar sugerencias y desforzar plan para dejar el entorno limpio
    EXEC sp_query_store_clear_hints @query_id = @TargetQueryID;
    EXEC sp_query_store_unforce_plan
        @query_id = @TargetQueryID,
        @plan_id = @TargetPlanID;
END
GO

-- ============================================================================
-- 5. AUDITORÍA DE SALUD Y ALMACENAMIENTO DE QUERY STORE
-- ============================================================================
SELECT 
    actual_state_desc,
    desired_state_desc,
    current_storage_size_mb,
    max_storage_size_mb,
    readonly_reason,
    wait_stats_capture_mode_desc
FROM sys.database_query_store_options;
GO