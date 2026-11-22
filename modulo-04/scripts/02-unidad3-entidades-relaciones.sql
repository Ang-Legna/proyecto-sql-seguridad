USE LabDataAPI;
GO

-- ============================================================================
-- MÓDULO 4 - UNIDAD 3: ESQUEMA RELACIONAL PARA ENTIDADES REST Y GRAPHQL
-- ============================================================================

-- 1. Crear tabla maestra dbo.Categories (referenciada en la lección)
IF OBJECT_ID('dbo.Products', 'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Categories', 'U') IS NOT NULL DROP TABLE dbo.Categories;
GO

CREATE TABLE dbo.Categories (
    CategoryID INT IDENTITY(1,1) PRIMARY KEY,
    CategoryName NVARCHAR(50) NOT NULL UNIQUE
);
GO

-- 2. Recrear dbo.Products con clave foránea hacia dbo.Categories
CREATE TABLE dbo.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    UnitsInStock INT NOT NULL,
    CategoryID INT NOT NULL FOREIGN KEY REFERENCES dbo.Categories(CategoryID)
);
GO

-- 3. Insertar datos de prueba
INSERT INTO dbo.Categories (CategoryName) VALUES
('Software Empresarial'),
('Seguridad Perimetral'),
('Criptografía y HSM'),
('Infraestructura de Red');
GO

INSERT INTO dbo.Products (ProductName, UnitPrice, UnitsInStock, CategoryID) VALUES
('Licencia SQL Server 2022 Enterprise', 4500.00, 15, 1),
('Firewall Perimetral Next-Gen', 2850.50, 8, 2),
('Módulo de Seguridad de Hardware (HSM)', 6200.00, 4, 3),
('Switch Administrable Capa 3 - 48 Puertos', 1490.00, 22, 4),
('SIEM Enterprise Collector', 3200.00, 10, 2);
GO

-- 4. Consulta de verificación que simula el recorrido relacional de GraphQL
SELECT 
    p.ProductID AS id,
    p.ProductName AS name,
    p.UnitPrice AS price,
    p.UnitsInStock AS stockQuantity,
    c.CategoryName AS categoryName
FROM dbo.Products p
INNER JOIN dbo.Categories c ON p.CategoryID = c.CategoryID
WHERE p.UnitPrice > 100 AND p.UnitsInStock > 0
ORDER BY p.ProductID;
GO