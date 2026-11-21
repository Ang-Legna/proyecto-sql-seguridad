USE master;
GO

-- Crear base de datos limpia para el laboratorio práctico del Módulo 1
IF DB_ID('LabEjercicio01') IS NOT NULL
BEGIN
    ALTER DATABASE LabEjercicio01 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LabEjercicio01;
END
GO

CREATE DATABASE LabEjercicio01;
GO

USE LabEjercicio01;
GO

-- ============================================================================
-- 1. CREATE SAMPLE TABLES & INSERT SAMPLE DATA
-- ============================================================================
CREATE TABLE dbo.Employees (
    EmployeeID int PRIMARY KEY IDENTITY(1,1),
    FirstName nvarchar(50) NOT NULL,
    LastName nvarchar(50) NOT NULL,
    Email nvarchar(100) NOT NULL,
    SSN char(11) NOT NULL,
    Salary decimal(18,2) NOT NULL,
    Department nvarchar(50) NOT NULL
);

CREATE TABLE dbo.Customers (
    CustomerID int PRIMARY KEY IDENTITY(1,1),
    CompanyName nvarchar(100) NOT NULL,
    ContactName nvarchar(100) NOT NULL,
    Phone nvarchar(20) NOT NULL,
    CreditCardNumber nvarchar(19) NOT NULL,
    SalesRegion nvarchar(20) NOT NULL
);
GO

INSERT INTO dbo.Employees (FirstName, LastName, Email, SSN, Salary, Department)
VALUES 
    ('Sarah', 'Chen', 'sarah.chen@contoso.com', '123-45-6789', 95000.00, 'Engineering'),
    ('Marcus', 'Johnson', 'marcus.johnson@contoso.com', '234-56-7890', 75000.00, 'Engineering'),
    ('Emily', 'Williams', 'emily.williams@contoso.com', '345-67-8901', 82000.00, 'Sales'),
    ('David', 'Brown', 'david.brown@contoso.com', '456-78-9012', 68000.00, 'Sales'),
    ('Lisa', 'Garcia', 'lisa.garcia@contoso.com', '567-89-0123', 71000.00, 'HR');

INSERT INTO dbo.Customers (CompanyName, ContactName, Phone, CreditCardNumber, SalesRegion)
VALUES 
    ('Northwind Traders', 'John Smith', '206-555-0100', '4111-1111-1111-1111', 'West'),
    ('Adventure Works', 'Jane Doe', '425-555-0150', '5500-0000-0000-0004', 'East'),
    ('Fabrikam Inc', 'Bob Wilson', '503-555-0175', '3400-0000-0000-009', 'West'),
    ('Contoso Ltd', 'Alice Brown', '360-555-0125', '6011-0000-0000-0004', 'East');
GO

-- ============================================================================
-- 2. IMPLEMENT DYNAMIC DATA MASKING (DDM)
-- ============================================================================
-- Enmascarar columnas sensibles de Employees
ALTER TABLE dbo.Employees
ALTER COLUMN SSN ADD MASKED WITH (FUNCTION = 'partial(0, "XXX-XX-", 4)');

ALTER TABLE dbo.Employees
ALTER COLUMN Salary ADD MASKED WITH (FUNCTION = 'random(50000, 150000)');

ALTER TABLE dbo.Employees
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');

-- Enmascarar columnas sensibles de Customers
ALTER TABLE dbo.Customers
ALTER COLUMN CreditCardNumber ADD MASKED WITH (FUNCTION = 'partial(0, "XXXX-XXXX-XXXX-", 4)');

ALTER TABLE dbo.Customers
ALTER COLUMN Phone ADD MASKED WITH (FUNCTION = 'partial(0, "XXX-XXX-", 4)');
GO

-- Crear usuario sin permiso UNMASK y verificar enmascaramiento
CREATE USER MaskedViewer WITHOUT LOGIN;
GRANT SELECT ON dbo.Employees TO MaskedViewer;
GRANT SELECT ON dbo.Customers TO MaskedViewer;
GO

-- Consulta como MaskedViewer (datos enmascarados)
EXECUTE AS USER = 'MaskedViewer';
SELECT FirstName, LastName, Email, SSN, Salary FROM dbo.Employees;
SELECT CompanyName, ContactName, Phone, CreditCardNumber FROM dbo.Customers;
REVERT;
GO

-- Consulta como administrador (datos sin enmascarar)
SELECT FirstName, LastName, Email, SSN, Salary FROM dbo.Employees;
GO

-- ============================================================================
-- 3. IMPLEMENT ROW-LEVEL SECURITY (RLS)
-- ============================================================================
CREATE USER WestSalesRep WITHOUT LOGIN;
CREATE USER EastSalesRep WITHOUT LOGIN;

GRANT SELECT ON dbo.Customers TO WestSalesRep;
GRANT SELECT ON dbo.Customers TO EastSalesRep;
GO

CREATE SCHEMA Security;
GO

CREATE FUNCTION Security.fn_RegionFilter(@SalesRegion nvarchar(20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS AccessGranted
    WHERE @SalesRegion = 
        CASE USER_NAME()
            WHEN 'WestSalesRep' THEN 'West'
            WHEN 'EastSalesRep' THEN 'East'
            ELSE @SalesRegion -- Admins ven todas las regiones
        END
        OR IS_MEMBER('db_owner') = 1;
GO

CREATE SECURITY POLICY CustomerRegionPolicy
ADD FILTER PREDICATE Security.fn_RegionFilter(SalesRegion)
    ON dbo.Customers
WITH (STATE = ON);
GO

-- Pruebas de Row-Level Security por región (y combinación con DDM)
-- Prueba 1: WestSalesRep (solo región West)
EXECUTE AS USER = 'WestSalesRep';
SELECT * FROM dbo.Customers;
REVERT;

-- Prueba 2: EastSalesRep (solo región East)
EXECUTE AS USER = 'EastSalesRep';
SELECT * FROM dbo.Customers;
REVERT;

-- Prueba 3: Admin (ve los 4 clientes y datos completos)
SELECT * FROM dbo.Customers;
GO

-- ============================================================================
-- 4. CLEANUP (Referencia del laboratorio - Comentado para conservar evidencia)
-- ============================================================================
/*
DROP SECURITY POLICY IF EXISTS CustomerRegionPolicy;
DROP FUNCTION IF EXISTS Security.fn_RegionFilter;
DROP SCHEMA IF EXISTS Security;

DROP USER IF EXISTS MaskedViewer;
DROP USER IF EXISTS WestSalesRep;
DROP USER IF EXISTS EastSalesRep;

DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Employees;
*/