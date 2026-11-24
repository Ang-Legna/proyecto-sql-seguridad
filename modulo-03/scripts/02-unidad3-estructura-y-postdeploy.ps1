# ============================================================================
# MÓDULO 3 - UNIDAD 3: ESTRUCTURA DE PROYECTO, .GITIGNORE Y SCRIPTS IDEMPOTENTES
# Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
# ============================================================================

Set-Location "modulo-03\MyDatabaseProject"

# Limpiar artefactos de prueba de la Unidad 2 dentro de la carpeta del proyecto
Remove-Item -Force -ErrorAction SilentlyContinue "deploy-script.sql", "report.xml"

# 1. Crear archivo .gitignore para excluir artefactos compilados
@"
bin/
obj/
*.dacpac
*.user
"@ | Set-Content -Path ".gitignore" -Encoding UTF8

# 2. Crear estructura estándar de carpetas por tipo de objeto
$folders = @(
    "Tables",
    "Views",
    "StoredProcedures",
    "Scripts\PreDeployment",
    "Scripts\PostDeployment"
)
foreach ($f in $folders) {
    New-Item -ItemType Directory -Force -Path $f | Out-Null
}

# 3. Agregar tablas adicionales: OrderStatuses y Orders
@"
CREATE TABLE [dbo].[OrderStatuses]
(
    [StatusID] INT NOT NULL PRIMARY KEY,
    [StatusName] NVARCHAR(50) NOT NULL
);
"@ | Set-Content -Path "Tables\OrderStatuses.sql" -Encoding UTF8

@"
CREATE TABLE [dbo].[Orders]
(
    [OrderID] INT NOT NULL PRIMARY KEY,
    [CustomerID] INT NOT NULL REFERENCES [dbo].[Customers]([CustomerID]),
    [StatusID] INT NOT NULL REFERENCES [dbo].[OrderStatuses]([StatusID]),
    [OrderDate] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    [TotalAmount] DECIMAL(12, 2) NOT NULL
);
"@ | Set-Content -Path "Tables\Orders.sql" -Encoding UTF8

# 4. Agregar vista y procedimiento almacenado
@"
CREATE VIEW [dbo].[vw_ActiveCustomers]
AS
SELECT
    [CustomerID],
    [FirstName],
    [LastName],
    [Email]
FROM [dbo].[Customers]
WHERE [Email] IS NOT NULL;
"@ | Set-Content -Path "Views\vw_ActiveCustomers.sql" -Encoding UTF8

@"
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
"@ | Set-Content -Path "StoredProcedures\usp_GetCustomerOrders.sql" -Encoding UTF8

# 5. Crear script PreDeploy y script PostDeploy idempotente con MERGE e inclusión SQLCMD (:r)
@"
-- Script de pre-implementación: verificación de entorno antes del despliegue
PRINT 'Iniciando validación previa al despliegue en LabDevOpsSQL...';
"@ | Set-Content -Path "prep-db.sql" -Encoding UTF8

@"
MERGE INTO [dbo].[OrderStatuses] AS target
USING (VALUES
    (1, N'Pending'),
    (2, N'Processing'),
    (3, N'Shipped'),
    (4, N'Delivered'),
    (5, N'Cancelled')
) AS source ([StatusID], [StatusName])
ON target.[StatusID] = source.[StatusID]
WHEN MATCHED THEN
    UPDATE SET [StatusName] = source.[StatusName]
WHEN NOT MATCHED THEN
    INSERT ([StatusID], [StatusName])
    VALUES (source.[StatusID], source.[StatusName]);
"@ | Set-Content -Path "Scripts\PostDeployment\seed-statuses.sql" -Encoding UTF8

@"
:r .\Scripts\PostDeployment\seed-statuses.sql
"@ | Set-Content -Path "PostDeploy.sql" -Encoding UTF8

# 6. Configurar PreDeploy, PostDeploy y exclusión de sub-scripts en MyDatabaseProject.sqlproj
$projPath = "MyDatabaseProject.sqlproj"
[xml]$xml = Get-Content $projPath

# Eliminar ItemGroups previos de scripts si se re-ejecuta
$existing = $xml.Project.ItemGroup | Where-Object { $_.PreDeploy -or $_.PostDeploy -or $_.Build }
foreach ($node in $existing) { $xml.Project.RemoveChild($node) | Out-Null }

$itemGroup = $xml.CreateElement("ItemGroup")

$pre = $xml.CreateElement("PreDeploy")
$pre.SetAttribute("Include", "prep-db.sql")
$itemGroup.AppendChild($pre) | Out-Null

$post = $xml.CreateElement("PostDeploy")
$post.SetAttribute("Include", "PostDeploy.sql")
$itemGroup.AppendChild($post) | Out-Null

$buildRemove = $xml.CreateElement("Build")
$buildRemove.SetAttribute("Remove", "Scripts\PostDeployment\seed-statuses.sql")
$itemGroup.AppendChild($buildRemove) | Out-Null

$noneInclude = $xml.CreateElement("None")
$noneInclude.SetAttribute("Include", "Scripts\PostDeployment\seed-statuses.sql")
$itemGroup.AppendChild($noneInclude) | Out-Null

$xml.Project.AppendChild($itemGroup) | Out-Null
$xml.Save((Resolve-Path $projPath))

# 7. Compilar el proyecto actualizado para validar referencias y generar el nuevo .dacpac
dotnet build $projPath

# Volver a la raíz del repositorio
Set-Location ..\..