USE LabDataAPI;
GO

-- ============================================================================
-- MÓDULO 4 - UNIDAD 4: VISTAS, PROCEDIMIENTOS ALMACENADOS Y RELACIONES COMPLEJAS
-- ============================================================================

-- 1. CREACIÓN DE VISTA DE INVENTARIO (dbo.ProductInventory)
CREATE OR ALTER VIEW dbo.ProductInventory AS
SELECT 
    p.ProductID,
    p.ProductName,
    p.UnitPrice,
    p.UnitsInStock,
    c.CategoryName,
    CASE 
        WHEN p.UnitsInStock = 0 THEN 'Out of Stock'
        WHEN p.UnitsInStock < 10 THEN 'Low Stock'
        ELSE 'Available'
    END AS StockStatus
FROM dbo.Products p
INNER JOIN dbo.Categories c ON p.CategoryID = c.CategoryID;
GO

-- 2. PROCEDIMIENTO ALMACENADO DE CONSULTA (operation: "query")
CREATE OR ALTER PROCEDURE dbo.GetProductsByPriceRange
    @MinPrice DECIMAL(10,2),
    @MaxPrice DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductID, ProductName, UnitPrice, UnitsInStock
    FROM dbo.Products
    WHERE UnitPrice BETWEEN @MinPrice AND @MaxPrice
    ORDER BY UnitPrice;
END;
GO

-- 3. ESQUEMA TRANSACCIONAL PARA PEDIDOS Y PROVEEDORES (Relaciones N:M y Multi-nivel)
IF OBJECT_ID('dbo.OrderDetails', 'U') IS NOT NULL DROP TABLE dbo.OrderDetails;
IF OBJECT_ID('dbo.Orders', 'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID('dbo.Customers', 'U') IS NOT NULL DROP TABLE dbo.Customers;
IF OBJECT_ID('dbo.ProductSuppliers', 'U') IS NOT NULL DROP TABLE dbo.ProductSuppliers;
IF OBJECT_ID('dbo.Suppliers', 'U') IS NOT NULL DROP TABLE dbo.Suppliers;
GO

CREATE TABLE dbo.Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CompanyName NVARCHAR(100) NOT NULL,
    ContactName NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL FOREIGN KEY REFERENCES dbo.Customers(CustomerID),
    OrderDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    Status NVARCHAR(30) NOT NULL
);

CREATE TABLE dbo.OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL FOREIGN KEY REFERENCES dbo.Orders(OrderID),
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dbo.Products(ProductID),
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL
);

-- Tablas para relación muchos a muchos (Product <-> ProductSuppliers <-> Suppliers)
CREATE TABLE dbo.Suppliers (
    SupplierID INT IDENTITY(1,1) PRIMARY KEY,
    SupplierName NVARCHAR(100) NOT NULL
);

CREATE TABLE dbo.ProductSuppliers (
    ProductID INT NOT NULL FOREIGN KEY REFERENCES dbo.Products(ProductID),
    SupplierID INT NOT NULL FOREIGN KEY REFERENCES dbo.Suppliers(SupplierID),
    PRIMARY KEY (ProductID, SupplierID)
);
GO

INSERT INTO dbo.Customers (CompanyName, ContactName) VALUES
('Autoridad del Canal de Panamá', 'Ing. Roberto Méndez'),
('Banco Nacional de Panamá', 'Lic. Elena Torres');

INSERT INTO dbo.Suppliers (SupplierName) VALUES
('Microsoft Enterprise Latam'),
('Palo Alto Networks Corp.');

INSERT INTO dbo.ProductSuppliers (ProductID, SupplierID) VALUES (1, 1), (2, 2);
GO

-- 4. PROCEDIMIENTO ALMACENADO QUE MODIFICA DATOS (operation: "mutation")
CREATE OR ALTER PROCEDURE dbo.CreateOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @OrderID INT;

        INSERT INTO dbo.Orders (CustomerID, OrderDate, Status)
        VALUES (@CustomerID, GETDATE(), 'Pending');

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO dbo.OrderDetails (OrderID, ProductID, Quantity, UnitPrice)
        SELECT @OrderID, @ProductID, @Quantity, UnitPrice
        FROM dbo.Products
        WHERE ProductID = @ProductID;

        UPDATE dbo.Products
        SET UnitsInStock = UnitsInStock - @Quantity
        WHERE ProductID = @ProductID;

        COMMIT TRANSACTION;
        SELECT @OrderID AS OrderID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 5. PRUEBAS DE VERIFICACIÓN DE LOS TRES OBJETOS
SELECT * FROM dbo.ProductInventory;
EXEC dbo.GetProductsByPriceRange @MinPrice = 1000.00, @MaxPrice = 5000.00;
EXEC dbo.CreateOrder @CustomerID = 1, @ProductID = 2, @Quantity = 2;
SELECT * FROM dbo.ProductInventory WHERE ProductID = 2;
GO