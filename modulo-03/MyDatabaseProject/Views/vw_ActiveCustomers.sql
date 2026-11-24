CREATE VIEW [dbo].[vw_ActiveCustomers]
AS
SELECT
    [CustomerID],
    [FirstName],
    [LastName],
    [Email]
FROM [dbo].[Customers]
WHERE [Email] IS NOT NULL;
