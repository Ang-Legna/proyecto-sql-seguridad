CREATE TABLE [dbo].[Orders]
(
    [OrderID] INT NOT NULL PRIMARY KEY,
    [CustomerID] INT NOT NULL REFERENCES [dbo].[Customers]([CustomerID]),
    [StatusID] INT NOT NULL REFERENCES [dbo].[OrderStatuses]([StatusID]),
    [OrderDate] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    [TotalAmount] DECIMAL(12, 2) NOT NULL
);
