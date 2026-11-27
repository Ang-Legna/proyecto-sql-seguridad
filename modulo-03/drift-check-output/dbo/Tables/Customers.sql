CREATE TABLE [dbo].[Customers] (
    [CustomerID]      INT            NOT NULL,
    [FirstName]       NVARCHAR (50)  NOT NULL,
    [LastName]        NVARCHAR (50)  NOT NULL,
    [Email]           NVARCHAR (100) NULL,
    [ManualAuditNote] NVARCHAR (100) NULL,
    PRIMARY KEY CLUSTERED ([CustomerID] ASC)
);


GO

