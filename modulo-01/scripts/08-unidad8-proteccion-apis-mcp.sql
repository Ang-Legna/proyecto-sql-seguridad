USE LabSeguridad;
GO

-- ============================================================================
-- 0. PREPARACIÓN DE ESQUEMAS Y TABLAS PARA LOS PROCEDIMIENTOS DE API Y MCP
-- ============================================================================
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'api')
    EXEC('CREATE SCHEMA api;');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'mcp')
    EXEC('CREATE SCHEMA mcp;');
GO

-- Tabla de control de acceso por cliente (referenciada en api.GetCustomerOrders)
CREATE TABLE dbo.CustomerAccess (
    AccessID INT IDENTITY PRIMARY KEY,
    CustomerID INT,
    UserPrincipal NVARCHAR(128)
);
GO

-- Insertar permiso para el usuario actual (sa) sobre el CustomerID = 1
INSERT INTO dbo.CustomerAccess (CustomerID, UserPrincipal)
VALUES (1, ORIGINAL_LOGIN());
GO

-- Agregar columnas esperadas por el procedimiento a dbo.Orders (si no existen)
IF COL_LENGTH('dbo.Orders', 'CustomerID') IS NULL
    ALTER TABLE dbo.Orders ADD CustomerID INT DEFAULT 1, OrderDate DATE DEFAULT GETDATE(), TotalAmount DECIMAL(10,2) DEFAULT 250.00;
GO

UPDATE dbo.Orders SET CustomerID = 1, OrderDate = '2026-11-20', TotalAmount = 499.99 WHERE OrderID = 1;
GO

-- ============================================================================
-- 1. PROCEDIMIENTO SEGURO PARA PUNTO DE CONEXIÓN REST / API (Unidad 8)
-- ============================================================================
CREATE PROCEDURE api.GetCustomerOrders
    @CustomerID int
AS
BEGIN
    -- Verificar que el usuario autenticado tenga acceso a este cliente
    IF NOT EXISTS (
        SELECT 1 FROM dbo.CustomerAccess
        WHERE CustomerID = @CustomerID
        AND UserPrincipal = ORIGINAL_LOGIN()
    )
    BEGIN
        THROW 50401, 'Unauthorized access to customer data', 1;
        RETURN;
    END

    SELECT OrderID, OrderDate, TotalAmount
    FROM dbo.Orders
    WHERE CustomerID = @CustomerID;
END;
GO

-- ============================================================================
-- 2. PROCEDIMIENTO DE VALIDACIÓN PARA PUNTO DE CONEXIÓN MCP (IA)
-- ============================================================================
CREATE PROCEDURE mcp.ExecuteQuery
    @QueryDescription nvarchar(max),
    @GeneratedQuery nvarchar(max) OUTPUT
AS
BEGIN
    -- Validar que la consulta generada por IA no acceda a objetos del sistema
    IF @GeneratedQuery LIKE '%sys.%' OR @GeneratedQuery LIKE '%INFORMATION_SCHEMA%'
    BEGIN
        THROW 50403, 'Access to system objects not permitted', 1;
        RETURN;
    END

    -- Asegurar que la consulta sea estrictamente de solo lectura
    IF @GeneratedQuery LIKE '%INSERT%' OR @GeneratedQuery LIKE '%UPDATE%'
        OR @GeneratedQuery LIKE '%DELETE%' OR @GeneratedQuery LIKE '%DROP%'
    BEGIN
        THROW 50403, 'Write operations not permitted', 1;
        RETURN;
    END

    -- Ejecutar la consulta validada
    EXEC sp_executesql @GeneratedQuery;
END;
GO

-- ============================================================================
-- 3. PRUEBAS DE VERIFICACIÓN PARA TU CAPTURA DE EVIDENCIA
-- ============================================================================
-- Prueba A: Llamada autorizada al API para CustomerID = 1 (devuelve los pedidos)
EXEC api.GetCustomerOrders @CustomerID = 1;
GO

-- Prueba B: Llamada segura desde MCP (solo lectura sobre Customers)
DECLARE @QuerySegura NVARCHAR(MAX) = N'SELECT CustomerID, FirstName, LastName, Email FROM dbo.Customers';
EXEC mcp.ExecuteQuery 
    @QueryDescription = N'Listar clientes activos', 
    @GeneratedQuery = @QuerySegura OUTPUT;
GO

-- ============================================================================
-- 4. REGLA DE FIREWALL A NIVEL DE SERVIDOR EN AZURE SQL (Referencia Azure)
-- ============================================================================
/*
EXECUTE sp_set_firewall_rule
    @name = 'AllowAppService',
    @start_ip_address = '10.0.0.1',
    @end_ip_address = '10.0.0.255';
*/