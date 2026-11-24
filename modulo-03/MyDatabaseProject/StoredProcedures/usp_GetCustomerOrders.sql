CREATE PROCEDURE [dbo].[usp_GetCustomerOrders]
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        o.[OrderID],
        o.[OrderDate],
        os.[StatusName],
        o.[TotalAmount]
    FROM [dbo].[Orders] o
    INNER JOIN [dbo].[OrderStatuses] os ON o.[StatusID] = os.[StatusID]
    WHERE o.[CustomerID] = @CustomerID;
END;
