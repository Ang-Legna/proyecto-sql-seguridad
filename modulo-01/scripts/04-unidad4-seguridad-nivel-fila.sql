USE LabSeguridad;
GO

-- ============================================================================
-- 0. PREPARACIÓN DE ESQUEMA, ROL Y TABLAS BASE DE LA UNIDAD 4
-- ============================================================================
CREATE SCHEMA Security;
GO

CREATE ROLE SalesManagers;
GO

-- Tablas para el escenario Multitenant (TenantID)
CREATE TABLE dbo.Orders (
    OrderID INT PRIMARY KEY,
    TenantID INT,
    Descripcion VARCHAR(100)
);

CREATE TABLE dbo.OrderDetails (
    DetailID INT PRIMARY KEY,
    OrderID INT,
    TenantID INT,
    Monto DECIMAL(10,2)
);

CREATE TABLE dbo.Shipments (
    ShipmentID INT PRIMARY KEY,
    TenantID INT,
    Destino VARCHAR(100)
);

-- Tabla para el escenario de Representantes de Ventas (SalesRepID)
CREATE TABLE dbo.CustomerAccounts (
    AccountID INT PRIMARY KEY,
    SalesRepID INT,
    NombreCuenta VARCHAR(100)
);

-- Tabla para el escenario Jerárquico (Employees)
CREATE TABLE dbo.Employees (
    EmployeeID INT PRIMARY KEY,
    ManagerID INT NULL,
    Nombre VARCHAR(100)
);
GO

-- Insertar datos de prueba para verificar el filtrado por TenantID
INSERT INTO dbo.Orders VALUES 
(1, 42, 'Pedido Cliente Tenant 42'),
(2, 99, 'Pedido Cliente Tenant 99');

INSERT INTO dbo.OrderDetails VALUES 
(10, 1, 42, 500.00),
(20, 2, 99, 850.00);

INSERT INTO dbo.Shipments VALUES 
(100, 42, 'Ciudad de Panama'),
(200, 99, 'David, Chiriqui');
GO

-- ============================================================================
-- 1. CREACIÓN DE PREDICADOS DE FILTRO (Unidad 4)
-- ============================================================================
-- Predicado A: Escenario Multitenant con SESSION_CONTEXT
CREATE FUNCTION Security.fn_TenantAccessPredicate(@TenantID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_TenantAccessPredicate_Result
    WHERE @TenantID = CAST(SESSION_CONTEXT(N'TenantID') AS int);
GO

-- Predicado B: Basado en usuario de BD y rol SalesManagers
CREATE FUNCTION Security.fn_SalesRepPredicate(@SalesRepID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS fn_SalesRepPredicate_Result
    WHERE @SalesRepID = DATABASE_PRINCIPAL_ID()
       OR IS_MEMBER('SalesManagers') = 1;
GO

-- Predicado C: Patrón de acceso jerárquico recursivo
CREATE FUNCTION Security.fn_HierarchyPredicate(@OwnerID int)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    WITH EmployeeHierarchy AS (
        SELECT EmployeeID, ManagerID
        FROM dbo.Employees
        WHERE EmployeeID = DATABASE_PRINCIPAL_ID()

        UNION ALL

        SELECT e.EmployeeID, e.ManagerID
        FROM dbo.Employees e
        INNER JOIN EmployeeHierarchy h ON e.ManagerID = h.EmployeeID
    )
    SELECT 1 AS fn_HierarchyPredicate_Result
    WHERE @OwnerID IN (SELECT EmployeeID FROM EmployeeHierarchy);
GO

-- ============================================================================
-- 2. CREACIÓN DE DIRECTIVAS DE SEGURIDAD (SECURITY POLICIES)
-- ============================================================================
-- Directiva Multitenant (FILTER PREDICATE)
CREATE SECURITY POLICY TenantSecurityPolicy
ADD FILTER PREDICATE Security.fn_TenantAccessPredicate(TenantID)
    ON dbo.Orders,
ADD FILTER PREDICATE Security.fn_TenantAccessPredicate(TenantID)
    ON dbo.OrderDetails
WITH (STATE = ON);
GO

-- Directiva de Ventas (FILTER + BLOCK PREDICATES)
CREATE SECURITY POLICY SalesSecurityPolicy
ADD FILTER PREDICATE Security.fn_SalesRepPredicate(SalesRepID)
    ON dbo.CustomerAccounts,
ADD BLOCK PREDICATE Security.fn_SalesRepPredicate(SalesRepID)
    ON dbo.CustomerAccounts AFTER INSERT,
ADD BLOCK PREDICATE Security.fn_SalesRepPredicate(SalesRepID)
    ON dbo.CustomerAccounts AFTER UPDATE
WITH (STATE = ON);
GO

-- ============================================================================
-- 3. ADMINISTRACIÓN DE DIRECTIVAS DE SEGURIDAD
-- ============================================================================
-- Deshabilitar temporalmente la directiva
ALTER SECURITY POLICY TenantSecurityPolicy
WITH (STATE = OFF);
GO

-- Agregar nuevo predicado a la directiva existente (dbo.Shipments)
ALTER SECURITY POLICY TenantSecurityPolicy
ADD FILTER PREDICATE Security.fn_TenantAccessPredicate(TenantID)
    ON dbo.Shipments;
GO

-- Quitar un predicado cuando una tabla ya no requiere filtrado (dbo.Orders)
ALTER SECURITY POLICY TenantSecurityPolicy
DROP FILTER PREDICATE ON dbo.Orders;
GO

-- Volver a habilitar la directiva para probarla
ALTER SECURITY POLICY TenantSecurityPolicy
WITH (STATE = ON);
GO

-- ============================================================================
-- 4. PRUEBAS DE VERIFICACIÓN Y CONSULTA DE METADATOS (Para tu evidencia)
-- ============================================================================
-- A) Consultar las directivas de seguridad activas y sus tablas asociadas
SELECT p.name AS PolicyName,
       p.is_enabled,
       o.name AS TableName,
       pred.predicate_definition
FROM sys.security_policies p
INNER JOIN sys.security_predicates pred ON p.object_id = pred.object_id
INNER JOIN sys.objects o ON pred.target_object_id = o.object_id;
GO

-- B) Establecer contexto de sesión para TenantID = 42 y consultar Shipments
EXEC sp_set_session_context @key = N'TenantID', @value = 42;

SELECT 'Con TenantID = 42 (Solo devuelve fila de Tenant 42)' AS Prueba, * 
FROM dbo.Shipments;
GO