USE LabSeguridad;
GO

-- ============================================================================
-- 1. TABLA DE SUPERVISIÓN Y AUDITORÍA DE LLAMADAS A IA (Unidad 7)
-- ============================================================================
CREATE TABLE dbo.AIEndpointLog (
    LogID int IDENTITY PRIMARY KEY,
    CallTimestamp datetime2 DEFAULT SYSUTCDATETIME(),
    CallerPrincipal nvarchar(128) DEFAULT ORIGINAL_LOGIN(),
    EndpointName nvarchar(256),
    InputLength int,
    ResponseStatus int,
    DurationMs int
);
GO

-- ============================================================================
-- 2. CONTROL DE ACCESO BASADO EN ROL PARA FUNCIONES DE IA
-- ============================================================================
CREATE ROLE AIFeatureUsers;
CREATE USER UsuarioIA_App WITHOUT LOGIN;
ALTER ROLE AIFeatureUsers ADD MEMBER UsuarioIA_App;
GO

-- Conceder permiso de inserción en el log al rol de usuarios de IA
GRANT INSERT, SELECT ON dbo.AIEndpointLog TO AIFeatureUsers;
GO

-- ============================================================================
-- 3. SIMULACIÓN DE REGISTROS Y DETECCIÓN DE PATRONES INUSUALES (Para evidencia)
-- ============================================================================
-- Insertar llamadas simuladas al endpoint 'text-embedding'
INSERT INTO dbo.AIEndpointLog (EndpointName, InputLength, ResponseStatus, DurationMs)
VALUES 
('text-embedding', 145, 200, 320),
('text-embedding', 512, 200, 480),
('text-embedding', 89, 200, 210),
('aml-inference-realtime', 1024, 200, 615);
GO

-- Consulta de la unidad para supervisar uso y detectar anomalías por usuario
SELECT 
    CallerPrincipal, 
    EndpointName,
    COUNT(*) AS CallCount, 
    AVG(DurationMs) AS AvgDurationMs
FROM dbo.AIEndpointLog
WHERE CallTimestamp > DATEADD(hour, -1, SYSUTCDATETIME())
GROUP BY CallerPrincipal, EndpointName
ORDER BY CallCount DESC;
GO

-- ============================================================================
-- 4. CONFIGURACIÓN DE IDENTIDAD ADMINISTRADA Y REST ENDPOINTS (Referencia Azure)
-- Nota: Comentado porque sp_invoke_external_rest_endpoint, TYPE = REST y 
-- Managed Identity son características exclusivas de Azure SQL Database.
-- ============================================================================
/*
-- PowerShell para asignar rol Cognitive Services User:
-- $sqlIdentity = (Get-AzSqlServer -ServerName myserver -ResourceGroupName myrg).Identity.PrincipalId
-- New-AzRoleAssignment -ObjectId $sqlIdentity -RoleDefinitionName "Cognitive Services User" -Scope "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{aoai-name}"

-- Credencial con identidad administrada para Azure OpenAI:
CREATE DATABASE SCOPED CREDENTIAL AzureOpenAICredential
WITH IDENTITY = 'Managed Identity',
SECRET = '{"resourceId": "https://cognitiveservices.azure.com/"}';

-- Origen de datos externo REST:
CREATE EXTERNAL DATA SOURCE AzureOpenAI
WITH (
    TYPE = REST,
    LOCATION = 'https://myopenai.openai.azure.com',
    CREDENTIAL = AzureOpenAICredential
);

-- Procedimiento almacenado con llamada REST y registro:
CREATE PROCEDURE dbo.GetEmbeddingWithLogging
    @InputText nvarchar(max),
    @Embedding nvarchar(max) OUTPUT
AS
BEGIN
    DECLARE @StartTime datetime2 = SYSUTCDATETIME();
    DECLARE @response nvarchar(max);

    EXEC sp_invoke_external_rest_endpoint
        @url = 'https://myopenai.openai.azure.com/openai/deployments/text-embedding/embeddings?api-version=2024-02-01',
        @method = 'POST',
        @payload = JSON_OBJECT('input': @InputText),
        @credential = AzureOpenAICredential,
        @response = @response OUTPUT;

    INSERT INTO dbo.AIEndpointLog (EndpointName, InputLength, ResponseStatus, DurationMs)
    VALUES ('text-embedding', LEN(@InputText), 200, DATEDIFF(millisecond, @StartTime, SYSUTCDATETIME()));

    SET @Embedding = JSON_VALUE(@response, '$.data[0].embedding');
END;
GO

GRANT EXECUTE ON dbo.GetEmbeddingWithLogging TO AIFeatureUsers;

-- Credencial y origen de datos para Azure Machine Learning:
CREATE DATABASE SCOPED CREDENTIAL AMLCredential
WITH IDENTITY = 'Managed Identity',
SECRET = '{"resourceId": "https://ml.azure.com/"}';

CREATE EXTERNAL DATA SOURCE AMLEndpoint
WITH (
    TYPE = REST,
    LOCATION = 'https://myworkspace.region.inference.ml.azure.com',
    CREDENTIAL = AMLCredential
);
*/