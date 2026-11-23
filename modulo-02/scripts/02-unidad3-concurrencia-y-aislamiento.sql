-- ============================================================================
-- MÓDULO 2 - UNIDAD 3: CONCURRENCIA, BLOQUEOS Y NIVELES DE AISLAMIENTO
-- Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
-- ============================================================================

USE LabRendimientoSQL;
GO

-- 1. Preparar tablas de inventario y pedidos del escenario de concurrencia
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE dbo.Products;
GO

CREATE TABLE dbo.Products (
    ProductID INT PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    StockCount INT NOT NULL
);

CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT NOT NULL REFERENCES dbo.Products(ProductID),
    Quantity INT NOT NULL,
    OrderDate DATETIME2 DEFAULT SYSDATETIME()
);

-- Insertar producto 42 con 1 sola unidad en inventario
INSERT INTO dbo.Products (ProductID, ProductName, StockCount)
VALUES (42, 'Tarjeta Gráfica Ed. Limitada', 1);
GO

-- ============================================================================
-- 2. HABILITAR CONCURRENCIA OPTIMISTA (VERSIONADO DE FILAS EN TEMPDB / PVS)
-- ============================================================================
ALTER DATABASE LabRendimientoSQL SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE LabRendimientoSQL SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;
GO

-- ============================================================================
-- 3. CONTROL DE TRANSACCIÓN SEGURA (EVITA SOBREVENTA CON SERIALIZABLE / UPDLOCK)
-- ============================================================================
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRANSACTION;

DECLARE @Stock INT;

-- El hint UPDLOCK adquiere un bloqueo de actualización desde la lectura,
-- impidiendo que una segunda sesión lea el mismo stock=1 simultáneamente.
SELECT @Stock = StockCount
FROM dbo.Products WITH (UPDLOCK)
WHERE ProductID = 42;

IF @Stock >= 1
BEGIN
    UPDATE dbo.Products
    SET StockCount = StockCount - 1
    WHERE ProductID = 42;

    INSERT INTO dbo.Orders (ProductID, Quantity)
    VALUES (42, 1);

    COMMIT TRANSACTION;
    PRINT 'Compra confirmada de forma segura. Stock actualizado a 0.';
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
    PRINT 'Compra rechazada: Sin existencias disponibles.';
END
GO

-- Restablecer nivel de aislamiento por defecto de la sesión
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
GO

-- ============================================================================
-- 4. AUDITORÍA DE NIVELES DE AISLAMIENTO Y VERSIONADO EN LA BASE DE DATOS
-- ============================================================================
SELECT 
    name AS BaseDeDatos,
    snapshot_isolation_state_desc AS SnapshotIsolation,
    is_read_committed_snapshot_on AS RCSI_Habilitado
FROM sys.databases
WHERE name = 'LabRendimientoSQL';

SELECT * FROM dbo.Products;
SELECT * FROM dbo.Orders;
GO