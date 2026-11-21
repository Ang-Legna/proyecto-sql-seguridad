USE LabSeguridad;
GO

-- ============================================================================
-- 0. PREPARACIÓN DE ESQUEMAS, ROLES, USUARIOS Y TABLAS DE LA UNIDAD 5
-- ============================================================================
-- Nota: El esquema Sales ya se creó en la Unidad 3; creamos Reports y HR
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Reports')
    EXEC('CREATE SCHEMA Reports AUTHORIZATION dbo;');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'HR')
    EXEC('CREATE SCHEMA HR AUTHORIZATION dbo;');
GO

-- Crear tabla Sales.Orders y dbo.EmployeeSalaries referenciadas en la lección
CREATE TABLE Sales.Orders (
    OrderID INT PRIMARY KEY,
    Total DECIMAL(10,2)
);

CREATE TABLE dbo.EmployeeSalaries (
    EmployeeID INT PRIMARY KEY,
    Salary DECIMAL(10,2)
);
GO

-- Crear roles y usuarios de prueba sin inicio de sesión
CREATE ROLE SalesAnalyst;
CREATE ROLE ReportingUsers;
CREATE ROLE CustomerServiceRole;
CREATE ROLE OrderProcessingRole;
CREATE ROLE HRAssistants;
CREATE ROLE SalesTeam;
CREATE ROLE HRAdministrators;
CREATE ROLE DataReaders;
CREATE ROLE DataWriters;

CREATE USER JohnSmith WITHOUT LOGIN;
CREATE USER JaneDoc WITHOUT LOGIN;
GO

-- ============================================================================
-- 1. SEPARACIÓN DE ESQUEMAS Y PERMISOS POR ESQUEMA (Unidad 5)
-- ============================================================================
-- Conceder SELECT en todos los objetos del esquema Sales
GRANT SELECT ON SCHEMA::Sales TO SalesAnalyst;

-- Conceder EXECUTE en todos los procedimientos del esquema Reports
GRANT EXECUTE ON SCHEMA::Reports TO ReportingUsers;

-- Equipo de ventas puede leer y escribir datos en esquema Sales
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Sales TO SalesTeam;

-- RR.HH. tiene control total sobre su esquema HR
GRANT CONTROL ON SCHEMA::HR TO HRAdministrators;
GO

-- ============================================================================
-- 2. CONCESIÓN, DENEGACIÓN Y REVOCACIÓN DE PERMISOS (GRANT, DENY, REVOKE)
-- ============================================================================
-- Permitir lectura de datos en dbo.Customers
GRANT SELECT ON dbo.Customers TO CustomerServiceRole;

-- Permitir modificaciones de datos en dbo.Orders
GRANT INSERT, UPDATE ON dbo.Orders TO OrderProcessingRole;

-- Denegar explícitamente acceso a datos sensibles (anula cualquier GRANT)
DENY SELECT ON dbo.EmployeeSalaries TO HRAssistants;

-- Quitar un permiso sin denegarlo explícitamente
REVOKE INSERT ON dbo.Customers FROM CustomerServiceRole;
GO

-- ============================================================================
-- 3. CONTROL DE ACCESO BASADO EN ROL (RBAC)
-- ============================================================================
-- Conceder permisos adecuados a cada rol
GRANT SELECT ON SCHEMA::dbo TO DataReaders;
GRANT INSERT, UPDATE, DELETE ON SCHEMA::dbo TO DataWriters;

-- Agregar usuarios a los roles
ALTER ROLE DataReaders ADD MEMBER JohnSmith;
ALTER ROLE DataWriters ADD MEMBER JaneDoc;
GO

-- ============================================================================
-- 4. VISUALIZACIÓN Y AUDITORÍA DE PERMISOS (Consultas de verificación)
-- ============================================================================
-- Ver todos los permisos asignados a SalesAnalyst (y otros roles creados)
SELECT 
    prin.name AS PrincipalName,
    perm.permission_name,
    perm.state_desc AS PermissionState,
    COALESCE(obj.name, SCHEMA_NAME(perm.major_id)) AS ObjectOrSchemaName
FROM sys.database_permissions perm
INNER JOIN sys.database_principals prin ON perm.grantee_principal_id = prin.principal_id
LEFT JOIN sys.objects obj ON perm.major_id = obj.object_id
WHERE prin.name IN ('SalesAnalyst', 'HRAssistants', 'DataReaders', 'DataWriters');
GO

-- Comprobar permisos efectivos para el usuario actual sobre Sales.Orders
SELECT * FROM fn_my_permissions('Sales.Orders', 'OBJECT');
GO

-- ============================================================================
-- 5. CONFIGURACIÓN DE MICROSOFT ENTRA Y CADENAS SEGURAS (Referencia Azure)
-- Nota: Comentado porque requiere integración en la nube con Microsoft Entra ID.
-- ============================================================================
/*
-- Cadena de conexión segura recomendada (sin contraseñas en código):
-- Server=tcp:myserver.database.windows.net,1433;Database=mydb;Authentication=Active Directory Managed Identity;Encrypt=True;

CREATE USER [app-service-identity] FROM EXTERNAL PROVIDER;
CREATE USER [developer@contoso.com] FROM EXTERNAL PROVIDER;
CREATE USER [DataAnalystsGroup] FROM EXTERNAL PROVIDER;

ALTER ROLE db_datareader ADD MEMBER [developer@contoso.com];
ALTER ROLE db_datawriter ADD MEMBER [app-service-identity];
*/