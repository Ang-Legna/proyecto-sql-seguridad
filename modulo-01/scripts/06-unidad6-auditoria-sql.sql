USE master;
GO

-- ============================================================================
-- 1. CREAR Y HABILITAR AUDITORÍA DE SERVIDOR (Adaptado a ruta de Docker Linux)
-- ============================================================================
CREATE SERVER AUDIT SecurityAudit
TO FILE (FILEPATH = '/var/opt/mssql/data/', MAXSIZE = 100 MB, MAX_ROLLOVER_FILES = 10)
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
GO

-- Habilitar la auditoría de servidor
ALTER SERVER AUDIT SecurityAudit WITH (STATE = ON);
GO

-- ============================================================================
-- 2. CREAR ESPECIFICACIÓN DE AUDITORÍA A NIVEL DE SERVIDOR
-- ============================================================================
CREATE SERVER AUDIT SPECIFICATION ServerAuditSpec
FOR SERVER AUDIT SecurityAudit
ADD (FAILED_LOGIN_GROUP),
ADD (SUCCESSFUL_LOGIN_GROUP),
ADD (SERVER_PERMISSION_CHANGE_GROUP),
ADD (DATABASE_PERMISSION_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- ============================================================================
-- 3. CREAR TABLA SENSIBLE Y ESPECIFICACIÓN DE AUDITORÍA DE BASE DE DATOS
-- ============================================================================
USE LabSeguridad;
GO

CREATE TABLE dbo.SensitiveData (
    RecordID INT PRIMARY KEY,
    InfoConfidencial VARCHAR(100)
);
GO

INSERT INTO dbo.SensitiveData VALUES 
(1, 'Plan Estrategico 2026'),
(2, 'Presupuesto Confidencial');
GO

CREATE DATABASE AUDIT SPECIFICATION DatabaseAuditSpec
FOR SERVER AUDIT SecurityAudit
ADD (SELECT, INSERT, UPDATE, DELETE ON dbo.SensitiveData BY public),
ADD (EXECUTE ON SCHEMA::dbo BY public),
ADD (DATABASE_ROLE_MEMBER_CHANGE_GROUP)
WITH (STATE = ON);
GO

-- ============================================================================
-- 4. GENERAR ACTIVIDAD AUDITADA Y CONSULTAR LOS REGISTROS (.sqlaudit)
-- ============================================================================
-- Ejecutar una consulta sobre la tabla auditada para generar un evento
SELECT * FROM dbo.SensitiveData;
GO

-- Esperar 2 segundos para que el búfer (QUEUE_DELAY = 1000 ms) escriba en disco
WAITFOR DELAY '00:00:02';
GO

-- Leer y analizar los registros generados con fn_get_audit_file
SELECT TOP 15
    event_time,
    action_id,
    succeeded,
    session_server_principal_name AS UserName,
    database_name,
    object_name,
    statement
FROM fn_get_audit_file('/var/opt/mssql/data/*.sqlaudit', DEFAULT, DEFAULT)
WHERE event_time > DATEADD(day, -7, GETUTCDATE())
ORDER BY event_time DESC;
GO

-- ============================================================================
-- 5. AUDITORÍA EN AZURE SQL, PLANTILLA ARM Y KUSTO (KQL) (Referencia Azure)
-- ============================================================================
/*
-- Habilitar auditoría en Azure Blob Storage:
ALTER DATABASE AUDIT SPECIFICATION AzureAuditSpec
ADD (SELECT, INSERT, UPDATE, DELETE ON DATABASE::MyDatabase BY public)
WITH (STATE = ON);

-- Ejemplo de configuración JSON (ARM Template):
{
  "properties": {
    "state": "Enabled",
    "storageEndpoint": "https://myauditlogs.blob.core.windows.net",
    "retentionDays": 90,
    "auditActionsAndGroups": [
      "SUCCESSFUL_DATABASE_AUTHENTICATION_GROUP",
      "FAILED_DATABASE_AUTHENTICATION_GROUP",
      "BATCH_COMPLETED_GROUP"
    ]
  }
}

-- Consulta KQL en Log Analytics:
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| where TimeGenerated > ago(7d)
| where action_name_s == "SELECT"
| summarize count() by client_ip_s, server_principal_name_s
| order by count_ desc
*/