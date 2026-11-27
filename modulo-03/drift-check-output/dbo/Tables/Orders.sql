CREATE TABLE [dbo].[Orders] (
    [OrderID]     INT             NOT NULL,
    [CustomerID]  INT             NOT NULL,
    [StatusID]    INT             NOT NULL,
    [OrderDate]   DATETIME2 (7)   DEFAULT (sysutcdatetime()) NOT NULL,
    [TotalAmount] DECIMAL (12, 2) NOT NULL,
    PRIMARY KEY CLUSTERED ([OrderID] ASC),
    FOREIGN KEY ([CustomerID]) REFERENCES [dbo].[Customers] ([CustomerID]),
    FOREIGN KEY ([StatusID]) REFERENCES [dbo].[OrderStatuses] ([StatusID])
);


GO

