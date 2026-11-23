-- ============================================================================
-- MÓDULO 2 - EJERCICIO PRÁCTICO (PARTE 1): OPTIMIZACIÓN DE CONSULTAS
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

USE LabRendimientoSQL;
GO

-- ============================================================================
-- 0. PREPARAR ESQUEMA BASE DE ADVENTUREWORKSLT EN EL ENTORNO LOCAL
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'SalesLT')
    EXEC('CREATE SCHEMA SalesLT');
GO

IF OBJECT_ID('dbo.OrderHistory', 'U') IS NOT NULL DROP TABLE dbo.OrderHistory;
IF OBJECT_ID('SalesLT.Customer', 'U') IS NOT NULL DROP TABLE SalesLT.Customer;
IF OBJECT_ID('SalesLT.Product', 'U') IS NOT NULL DROP TABLE SalesLT.Product;
GO

CREATE TABLE SalesLT.Customer (
    CustomerID INT PRIMARY KEY,
    FullName NVARCHAR(100) NOT NULL
);

CREATE TABLE SalesLT.Product (
    ProductID INT PRIMARY KEY,
    Name NVARCHAR(100) NOT NULL,
    ProductNumber NVARCHAR(25) NOT NULL,
    ListPrice DECIMAL(10,2) NOT NULL
);

-- Poblar 850 clientes (incluyendo CustomerID = 1 y 29485 usados en la guía)
INSERT INTO SalesLT.Customer (CustomerID, FullName)
SELECT TOP 848 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 1,
       N'Cliente AdventureWorks #' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 1 AS NVARCHAR(10))
FROM sys.all_objects;

INSERT INTO SalesLT.Customer (CustomerID, FullName) VALUES (1, N'Cliente Corporativo VIP (Sesgo)');
INSERT INTO SalesLT.Customer (CustomerID, FullName) VALUES (29485, N'Cliente Servicio al Cliente');

-- Poblar 295 productos de catálogo
INSERT INTO SalesLT.Product (ProductID, Name, ProductNumber, ListPrice)
SELECT TOP 295 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 600,
       N'Producto AW-' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 600 AS NVARCHAR(10)),
       N'BK-M68B-' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 600 AS NVARCHAR(10)),
       CAST((ABS(CHECKSUM(NEWID())) % 500 + 25) * 1.50 AS DECIMAL(10,2))
FROM sys.all_objects;
GO

-- ============================================================================
-- 1. CREAR CARGA DE TRABAJO DE PRUEBA (80,000 PEDIDOS EN dbo.OrderHistory)
-- ============================================================================
CREATE TABLE dbo.OrderHistory (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    ProductID INT NOT NULL,
    OrderDate DATETIME NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    TotalAmount AS (Quantity * UnitPrice) PERSISTED,
    Status NVARCHAR(20) NOT NULL
);

INSERT INTO dbo.OrderHistory (CustomerID, ProductID, OrderDate, Quantity, UnitPrice, Status)
SELECT TOP 80000
    c.CustomerID,
    p.ProductID,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 10 + 1,
    p.ListPrice,
    CASE ABS(CHECKSUM(NEWID())) % 4
        WHEN 0 THEN N'Pending'
        WHEN 1 THEN N'Processing'
        WHEN 2 THEN N'Shipped'
        ELSE N'Delivered'
    END
FROM SalesLT.Customer AS c
CROSS JOIN SalesLT.Product AS p
ORDER BY NEWID();

-- Verificar las 80,000 filas insertadas
SELECT COUNT(*) AS TotalOrders FROM dbo.OrderHistory;
GO

-- ============================================================================
-- 2. HABILITAR Y CONFIGURAR QUERY STORE
-- ============================================================================
ALTER DATABASE CURRENT SET QUERY_STORE = ON (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    WAIT_STATS_CAPTURE_MODE = ON
);
GO

ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;
GO

SELECT actual_state_desc, desired_state_desc,
       current_storage_size_mb, max_storage_size_mb
FROM sys.database_query_store_options;
GO

-- ============================================================================
-- 3. ANALIZAR PLANES DE EJECUCIÓN Y AGREGAR ÍNDICE DE COBERTURA (COVERING INDEX)
-- ============================================================================
SET STATISTICS IO ON;

-- Ejecución ANTES del índice (Clustered Index Scan)
SELECT
    oh.OrderID, oh.OrderDate, p.Name AS ProductName,
    oh.Quantity, oh.UnitPrice, oh.TotalAmount, oh.Status
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p ON oh.ProductID = p.ProductID
WHERE oh.CustomerID = 29485
  AND oh.OrderDate >= DATEADD(MONTH, -3, GETDATE())
ORDER BY oh.OrderDate DESC;

-- Crear índice de cobertura con orden DESC en OrderDate
CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC)
INCLUDE (ProductID, Quantity, UnitPrice, Status);

-- Ejecución DESPUÉS del índice (Index Seek sin Key Lookups)
SELECT
    oh.OrderID, oh.OrderDate, p.Name AS ProductName,
    oh.Quantity, oh.UnitPrice, oh.TotalAmount, oh.Status
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p ON oh.ProductID = p.ProductID
WHERE oh.CustomerID = 29485
  AND oh.OrderDate >= DATEADD(MONTH, -3, GETDATE())
ORDER BY oh.OrderDate DESC;

SET STATISTICS IO OFF;
GO

-- ============================================================================
-- 4. USAR DMVs PARA IDENTIFICAR CONSULTAS COSTOSAS E ÍNDICES FALTANTES
-- ============================================================================
SELECT
    p.Name AS ProductName, p.ProductNumber,
    oh.OrderDate, oh.Quantity, oh.TotalAmount
FROM dbo.OrderHistory AS oh
INNER JOIN SalesLT.Product AS p ON oh.ProductID = p.ProductID
WHERE oh.Status = N'Pending'
  AND oh.OrderDate >= DATEADD(MONTH, -1, GETDATE())
ORDER BY oh.TotalAmount DESC;
GO 5

-- Top 5 consultas más costosas por tiempo de CPU
SELECT TOP 5
    qs.total_worker_time / qs.execution_count AS avg_cpu_time_us,
    qs.execution_count,
    qs.total_logical_reads / qs.execution_count AS avg_logical_reads,
    SUBSTRING(st.text, (qs.statement_start_offset / 2) + 1,
        ((CASE qs.statement_end_offset
            WHEN -1 THEN DATALENGTH(st.text)
            ELSE qs.statement_end_offset
        END - qs.statement_start_offset) / 2) + 1) AS query_text
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
ORDER BY avg_cpu_time_us DESC;

-- Detección global de índices faltantes
SELECT TOP 10
    mid.statement AS table_name,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    ROUND(migs.avg_total_user_cost * migs.avg_user_impact *
        (migs.user_seeks + migs.user_scans), 2) AS improvement_measure
FROM sys.dm_db_missing_index_groups AS mig
INNER JOIN sys.dm_db_missing_index_group_stats AS migs
    ON migs.group_handle = mig.index_group_handle
INNER JOIN sys.dm_db_missing_index_details AS mid
    ON mig.index_handle = mid.index_handle
ORDER BY improvement_measure DESC;
GO

-- ============================================================================
-- 5. PREPARAR ESCENARIO DE REGRESIÓN POR PARAMETER SNIFFING
-- ============================================================================
ALTER DATABASE CURRENT SET QUERY_STORE CLEAR;
GO

ALTER DATABASE CURRENT SET QUERY_STORE (
    QUERY_CAPTURE_MODE = ALL
);
GO

-- Reemplazar índice de cobertura por índice no cubierto (sin INCLUDE)
DROP INDEX IF EXISTS IX_OrderHistory_CustomerDate ON dbo.OrderHistory;

CREATE NONCLUSTERED INDEX IX_OrderHistory_CustomerDate
ON dbo.OrderHistory (CustomerID, OrderDate DESC);

-- Insertar 50,000 filas sesgadas para CustomerID = 1
INSERT INTO dbo.OrderHistory (CustomerID, ProductID, OrderDate, Quantity, UnitPrice, Status)
SELECT TOP 50000
    1,
    p.ProductID,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, GETDATE()),
    ABS(CHECKSUM(NEWID())) % 10 + 1,
    p.ListPrice,
    N'Pending'
FROM SalesLT.Product AS p
CROSS JOIN SalesLT.Product AS p2
ORDER BY NEWID();

UPDATE STATISTICS dbo.OrderHistory;
GO

-- Crear procedimiento almacenado vulnerable a Parameter Sniffing
CREATE OR ALTER PROCEDURE dbo.GetCustomerOrders
    @CustomerID INT
AS
BEGIN
    SELECT
        oh.OrderID,
        oh.OrderDate,
        p.Name AS ProductName,
        oh.Quantity,
        oh.UnitPrice,
        oh.TotalAmount,
        oh.Status
    FROM dbo.OrderHistory AS oh
    INNER JOIN SalesLT.Product AS p
        ON oh.ProductID = p.ProductID
    WHERE oh.CustomerID = @CustomerID
    ORDER BY oh.OrderDate DESC;
END;
GO