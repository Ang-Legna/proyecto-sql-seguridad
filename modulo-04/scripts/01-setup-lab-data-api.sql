USE master;
GO

-- Crear base de datos limpia para el Módulo 2: Data API Builder (DAB)
IF DB_ID('LabDataAPI') IS NOT NULL
BEGIN
    ALTER DATABASE LabDataAPI SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LabDataAPI;
END
GO

CREATE DATABASE LabDataAPI;
GO

USE LabDataAPI;
GO

-- 1. Tabla de productos (expuesta vía REST/GraphQL)
CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    SKU NVARCHAR(30) NOT NULL UNIQUE,
    ProductName NVARCHAR(100) NOT NULL,
    Category NVARCHAR(50) NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    StockQuantity INT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 DEFAULT SYSUTCDATETIME()
);
GO

INSERT INTO dbo.Products (SKU, ProductName, Category, UnitPrice, StockQuantity) VALUES
('SRV-SQL-2022', 'Licencia SQL Server 2022 Enterprise', 'Software', 4500.00, 15),
('FW-NGFW-500', 'Firewall Perimetral Next-Gen', 'Seguridad', 2850.50, 8),
('CLOUD-HSM-01', 'Módulo de Seguridad de Hardware (HSM)', 'Criptografía', 6200.00, 4),
('NET-SW-48P', 'Switch Administrable Capa 3 - 48 Puertos', 'Redes', 1490.00, 22);
GO

-- 2. Procedimiento de verificación para SESSION_CONTEXT (usado por DAB)
CREATE OR ALTER PROCEDURE dbo.usp_VerifyDabSessionContext
AS
BEGIN
    SET NOCOUNT ON;
    SELECT 
        SESSION_CONTEXT(N'UserId') AS DabUserId,
        SESSION_CONTEXT(N'Role') AS DabUserRole,
        ORIGINAL_LOGIN() AS DatabaseLogin,
        SYSUTCDATETIME() AS ExecutionTimestamp;
END;
GO

-- Simulación de lo que DAB ejecuta internamente al habilitar "set-session-context": true
EXEC sp_set_session_context @key = N'UserId', @value = N'angela.caballero@utp.ac.pa';
EXEC sp_set_session_context @key = N'Role', @value = N'authenticated';
EXEC dbo.usp_VerifyDabSessionContext;
GO

SELECT * FROM dbo.Products;
GO