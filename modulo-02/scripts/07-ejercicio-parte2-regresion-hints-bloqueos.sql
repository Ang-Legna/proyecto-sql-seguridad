-- ============================================================================
-- MÓDULO 2 - EJERCICIO PRÁCTICO (PARTE 2): REGRESIÓN, HINTS Y BLOQUEOS
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

USE LabRendimientoSQL;
GO

-- ============================================================================
-- 0. ASEGURAR TABLA SalesLT.ProductCategory PARA LA CONSULTA ANALÍTICA
-- ============================================================================
IF COL_LENGTH('SalesLT.Product', 'ProductCategoryID') IS NULL
BEGIN
    ALTER TABLE SalesLT.Product ADD ProductCategoryID INT NULL;
END
GO

IF OBJECT_ID('SalesLT.ProductCategory', 'U') IS NULL
BEGIN
    CREATE TABLE SalesLT.ProductCategory (
        ProductCategoryID INT PRIMARY KEY,
        Name NVARCHAR(50) NOT NULL
    );

    INSERT INTO SalesLT.ProductCategory (ProductCategoryID, Name) VALUES
    (1, N'Bicicletas de Montaña'),
    (2, N'Bicicletas de Ruta'),
    (3, N'Componentes y Frenos'),
    (4, N'Accesorios de Ciclismo');

    UPDATE SalesLT.Product
    SET ProductCategoryID = (ProductID % 4) + 1;
END
GO

-- ============================================================================
-- 1. CAUSAR REGRESIÓN POR PARAMETER SNIFFING EN dbo.GetCustomerOrders
-- ============================================================================
-- 1.1 Compilar el plan RÁPIDO (Index Seek) con CustomerID = 29485 (< 100 filas)
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.GetCustomerOrders @CustomerID = 29485;
GO 10

-- 1.2 Limpiar caché y compilar el plan LENTO (Clustered Index Scan) con CustomerID = 1 (50,000+ filas)
ALTER DATABASE SCOPED CONFIGURATION CLEAR PROCEDURE_CACHE;
GO

EXEC dbo.GetCustomerOrders @CustomerID = 1;
GO

-- 1.3 Reutilizar el plan lento (regresión) para CustomerID = 29485
EXEC dbo.GetCustomerOrders @CustomerID = 29485;
GO 10

-- Volcar estadísticas de Query Store a disco inmediatamente
EXEC sp_query_store_flush_db;
GO

-- ============================================================================
-- 2. DETECTAR LA REGRESIÓN Y FORZAR EL PLAN MÁS RÁPIDO VÍA T-SQL
-- ============================================================================
DECLARE @RegressedQueryID BIGINT;
DECLARE @FastestPlanID BIGINT;

-- Buscar el query_id del procedimiento GetCustomerOrders y su plan con menor duración media
SELECT TOP 1
    @RegressedQueryID = q.query_id,
    @FastestPlanID = p.plan_id
FROM sys.query_store_query AS q
INNER JOIN sys.query_store_plan AS p ON q.query_id = p.query_id
INNER JOIN sys.query_store_runtime_stats AS rs ON p.plan_id = rs.plan_id
INNER JOIN sys.query_store_query_text AS qt ON q.query_text_id = qt.query_text_id
WHERE qt.query_sql_text LIKE '%oh.CustomerID = @CustomerID%'
  AND qt.query_sql_text NOT LIKE '%sys.query_store%'
GROUP BY q.query_id, p.plan_id
ORDER BY AVG(rs.avg_duration) ASC;

IF @RegressedQueryID IS NOT NULL AND @FastestPlanID IS NOT NULL
BEGIN
    EXEC sp_query_store_force_plan
        @query_id = @RegressedQueryID,
        @plan_id = @FastestPlanID;
END
GO

-- Confirmar plan forzado (is_forced_plan = 1 y force_failure_count = 0)
SELECT
    q.query_id,
    p.plan_id,
    p.is_forced_plan,
    p.force_failure_count,
    qt.query_sql_text
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q
    ON p.query_id = q.query_id
INNER JOIN sys.query_store_query_text AS qt
    ON q.query_text_id = qt.query_text_id
WHERE p.is_forced_plan = 1;
GO

-- Probar ejecución con ambos parámetros usando el plan forzado
EXEC dbo.GetCustomerOrders @CustomerID = 29485;
EXEC dbo.GetCustomerOrders @CustomerID = 1;
GO

-- Restaurar el índice de cobertura y limpiar procedimiento para la siguiente sección
DROP PROCEDURE IF EXISTS dbo.GetCustomerOrders;
DROP INDEX IF EXISTS IX_OrderHistory_CustomerDate ON dbo.OrderHistory;

CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC)
INCLUDE (ProductID, Quantity, UnitPrice, Status);
GO

-- ============================================================================
-- 3. APLICAR UNA SUGERENCIA (HINT) DE QUERY STORE: OPTION (MAXDOP 1)
-- ============================================================================
-- Ejecutar consulta analítica con funciones de ventana (candidata a paralelismo)
SELECT
    oh.CustomerID,
    p.Name AS ProductName,
    pc.Name AS CategoryName,
    oh.Status,
    COUNT(*) AS OrderCount,
    SUM(oh.TotalAmount) AS TotalRevenue,
    AVG(oh.TotalAmount) AS AvgOrderValue,
    STDEV(oh.TotalAmount) AS StdDevOrderValue,
    RANK() OVER (PARTITION BY oh.Status
        ORDER BY SUM(oh.TotalAmount) DESC) AS StatusRevenueRank,
    PERCENT_RANK() OVER (PARTITION BY pc.Name
        ORDER BY AVG(oh.TotalAmount)) AS CategoryPctRank,
    SUM(COUNT(*)) OVER (PARTITION BY oh.Status) AS StatusTotalOrders
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p
    ON oh.ProductID = p.ProductID
INNER JOIN SalesLT.ProductCategory AS pc
    ON p.ProductCategoryID = pc.ProductCategoryID
GROUP BY oh.CustomerID, p.Name, pc.Name, oh.Status
ORDER BY TotalRevenue DESC;
GO

-- Localizar query_id y aplicar hint MAXDOP 1 (ejecución en 1 solo hilo)
DECLARE @AggQueryID BIGINT;

SELECT TOP 1 @AggQueryID = q.query_id
FROM sys.query_store_query_text AS qt
INNER JOIN sys.query_store_query AS q
    ON qt.query_text_id = q.query_text_id
WHERE qt.query_sql_text LIKE '%StatusRevenueRank%PARTITION%'
  AND qt.query_sql_text NOT LIKE '%sys.query_store%';

IF @AggQueryID IS NOT NULL
BEGIN
    EXEC sp_query_store_set_hints
        @query_id = @AggQueryID,
        @query_hints = N'OPTION (MAXDOP 1)';

    SELECT query_hint_id, query_id, query_hint_text, source_desc
    FROM sys.query_store_query_hints
    WHERE query_id = @AggQueryID;

    -- Eliminar el hint al finalizar la prueba
    EXEC sp_query_store_clear_hints @query_id = @AggQueryID;
END
GO

-- ============================================================================
-- 4. CONSULTAS DE DIAGNÓSTICO DE BLOQUEOS (BLOCKING) Y LIMPIEZA FINAL
--    (Para probar bloqueo en vivo: abrir Ventana 1 con BEGIN TRAN + UPDATE
--     sin COMMIT, Ventana 2 con UPDATE sobre OrderID = 1, y ejecutar abajo)
-- ============================================================================
-- 4.1 Detectar sesiones bloqueadas (wait_type = LCK_M_X)
SELECT
    r.session_id AS blocked_session,
    r.blocking_session_id AS head_blocker,
    r.wait_type,
    r.wait_time AS wait_time_ms,
    r.wait_resource,
    t.text AS blocked_query
FROM sys.dm_exec_requests AS r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS t
WHERE r.blocking_session_id <> 0;

-- 4.2 Inspeccionar sesiones activas o en estado 'sleeping' con transacciones abiertas
SELECT
    s.session_id,
    s.status,
    s.open_transaction_count,
    s.program_name,
    s.host_name,
    t.text AS last_query
FROM sys.dm_exec_sessions AS s
LEFT JOIN sys.dm_exec_connections AS c
    ON s.session_id = c.session_id
OUTER APPLY sys.dm_exec_sql_text(c.most_recent_sql_handle) AS t
WHERE s.session_id > 50
  AND s.open_transaction_count > 0;
GO

-- 4.3 Limpieza final (Cleanup) de planes forzados en Query Store
DECLARE @qid INT, @pid INT;

SELECT TOP 1 @qid = q.query_id, @pid = p.plan_id
FROM sys.query_store_plan AS p
INNER JOIN sys.query_store_query AS q ON p.query_id = q.query_id
WHERE p.is_forced_plan = 1;

WHILE @@ROWCOUNT > 0
BEGIN
    EXEC sp_query_store_unforce_plan @query_id = @qid, @plan_id = @pid;

    SELECT TOP 1 @qid = q.query_id, @pid = p.plan_id
    FROM sys.query_store_plan AS p
    INNER JOIN sys.query_store_query AS q ON p.query_id = q.query_id
    WHERE p.is_forced_plan = 1;
END
GO