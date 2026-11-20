USE LabSeguridad;
GO

-- ============================================================================
-- 1. CREAR TABLA CON MÚLTIPLES FUNCIONES DE ENMASCARAMIENTO (Unidad 3)
-- (Se incluye DateOfBirth para poder probar los ALTER TABLE de la lección)
-- ============================================================================
CREATE TABLE Customers (
    CustomerID int PRIMARY KEY,
    FirstName varchar(50),
    LastName varchar(50),
    Email varchar(100) MASKED WITH (FUNCTION = 'email()'),
    Phone varchar(20) MASKED WITH (FUNCTION = 'partial(3, "-XXX-XX", 2)'),
    CreditCardNumber varchar(19) MASKED WITH (FUNCTION = 'partial(0, "XXXX-XXXX-XXXX-", 4)'),
    Income decimal(18,2) MASKED WITH (FUNCTION = 'random(10000, 100000)'),
    SSN char(11) MASKED WITH (FUNCTION = 'default()'),
    DateOfBirth date
);
GO

-- Insertar datos de prueba
INSERT INTO Customers VALUES
(1, 'Maria', 'Gonzalez', 'maria.gonzalez@empresa.com', '507-6123-4589', '4532-1111-2222-9876', 45000.00, '123-45-6789', '1992-05-14'),
(2, 'Jorge', 'Mendoza', 'jorge.mendoza@correo.org', '507-6987-3210', '5412-9999-8888-1234', 62000.00, '987-65-4321', '1988-11-23');
GO

-- ============================================================================
-- 2. AGREGAR Y QUITAR MÁSCARAS EN COLUMNAS EXISTENTES (ALTER COLUMN)
-- ============================================================================
-- Agregar enmascaramiento a DateOfBirth
ALTER TABLE Customers
ALTER COLUMN DateOfBirth ADD MASKED WITH (FUNCTION = 'default()');
GO

-- Quitar el enmascaramiento de DateOfBirth
ALTER TABLE Customers
ALTER COLUMN DateOfBirth DROP MASKED;
GO

-- ============================================================================
-- 3. CONTROL GRANULAR CON PERMISOS UNMASK (SQL Server 2022)
-- ============================================================================
-- Crear esquema y usuarios de prueba sin inicio de sesión
CREATE SCHEMA Sales;
GO

CREATE USER DataAnalyst WITHOUT LOGIN;
CREATE USER SalesManager WITHOUT LOGIN;
CREATE USER CustomerService WITHOUT LOGIN;
CREATE USER TelemarketingTeam WITHOUT LOGIN;
GO

-- Dar permiso de lectura (SELECT) sobre la tabla Customers
GRANT SELECT ON Customers TO DataAnalyst;
GRANT SELECT ON Customers TO CustomerService;
GRANT SELECT ON Customers TO TelemarketingTeam;
GO

-- A) Permiso UNMASK a nivel de toda la base de datos:
GRANT UNMASK TO DataAnalyst;

-- B) Permiso UNMASK a nivel de esquema específico:
GRANT UNMASK ON SCHEMA::Sales TO SalesManager;

-- C) Permiso UNMASK a nivel de tabla específica:
GRANT UNMASK ON Customers TO CustomerService;

-- D) Permiso UNMASK a nivel de una sola columna (SQL Server 2022):
GRANT UNMASK ON Customers(Phone) TO TelemarketingTeam;
GO

-- ============================================================================
-- 4. PRUEBAS DE VERIFICACIÓN PARA LA EVIDENCIA
-- ============================================================================
-- Prueba 1: TelemarketingTeam (solo ve Phone real; Email, Tarjeta, Income y SSN salen enmascarados)
EXECUTE AS USER = 'TelemarketingTeam';
SELECT 'Vista TelemarketingTeam' AS Rol, FirstName, Email, Phone, CreditCardNumber, Income, SSN 
FROM Customers;
REVERT;
GO

-- Prueba 2: DataAnalyst (tiene UNMASK global, ve todos los datos reales)
EXECUTE AS USER = 'DataAnalyst';
SELECT 'Vista DataAnalyst' AS Rol, FirstName, Email, Phone, CreditCardNumber, Income, SSN 
FROM Customers;
REVERT;
GO