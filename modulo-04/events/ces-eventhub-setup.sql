-- ============================================================================
-- MÓDULO 4 - UNIDAD 7: CHANGE EVENT STREAMING (CES) HACIA AZURE EVENT HUBS
-- ============================================================================

-- Crear grupo de transmisión de eventos sin latencia de sondeo
CREATE EVENT STREAMING GROUP MyOrderStream
WITH (
    TARGET_TYPE = 'eventhub',
    TARGET_NAME = 'orders-eventhub',
    TARGET_CONNECTION = '<event-hub-connection-string>'
);

-- Suscribir la tabla dbo.Orders al flujo de eventos
ALTER EVENT STREAMING GROUP MyOrderStream
ADD TABLE dbo.Orders;