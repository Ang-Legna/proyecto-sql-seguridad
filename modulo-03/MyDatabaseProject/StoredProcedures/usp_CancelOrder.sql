CREATE PROCEDURE [dbo].[usp_CancelOrder]
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentStatus INT;
    SELECT @CurrentStatus = [StatusID] FROM [dbo].[Orders] WHERE [OrderID] = @OrderID;

    IF @CurrentStatus IS NULL
        THROW 50002, 'El pedido especificado no existe.', 1;

    -- Si el pedido ya fue entregado (StatusID = 4), lanzar error controlado (Severity 16, State 1)
    IF @CurrentStatus = 4
        THROW 50001, 'No se puede cancelar un pedido que ya fue entregado.', 1;

    UPDATE [dbo].[Orders]
    SET [StatusID] = 5 -- Cancelled
    WHERE [OrderID] = @OrderID;
END;
