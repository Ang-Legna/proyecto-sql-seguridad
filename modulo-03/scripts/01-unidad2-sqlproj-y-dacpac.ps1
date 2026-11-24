# ============================================================================
# MÓDULO 3 - UNIDAD 2: PROYECTOS DE BASE DE DATOS (.sqlproj) Y SQLPACKAGE
# Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
# ============================================================================

# 1. Ubicarse en la carpeta del módulo 3
New-Item -ItemType Directory -Force -Path "modulo-03" | Out-Null
Set-Location "modulo-03"

# 2. Verificar SDK de .NET y herramienta global SqlPackage
dotnet --version
if (-not (Get-Command sqlpackage -ErrorAction SilentlyContinue)) {
    dotnet tool install --global microsoft.sqlpackage
}

# 3. Instalar plantilla Microsoft.Build.Sql si no está presente y crear proyecto SDK
dotnet new install Microsoft.Build.Sql.Templates --force | Out-Null
if (Test-Path "MyDatabaseProject") { Remove-Item -Recurse -Force "MyDatabaseProject" }
dotnet new sqlproj -n MyDatabaseProject

# 4. Ajustar plataforma de destino a SQL Server 2022 (Sql160) para Docker local
$projFile = "MyDatabaseProject\MyDatabaseProject.sqlproj"
(Get-Content $projFile) -replace 'Sql170|SqlAzureV12', 'Sql160' | Set-Content $projFile

# 5. Definir objeto de tabla declarativo: Tables/Customers.sql
New-Item -ItemType Directory -Force -Path "MyDatabaseProject\Tables" | Out-Null
@"
CREATE TABLE [dbo].[Customers]
(
    [CustomerID] INT NOT NULL PRIMARY KEY,
    [FirstName] NVARCHAR(50) NOT NULL,
    [LastName] NVARCHAR(50) NOT NULL,
    [Email] NVARCHAR(100) NULL
);
"@ | Set-Content -Path "MyDatabaseProject\Tables\Customers.sql" -Encoding UTF8

# 6. Compilar proyecto y generar el artefacto .dacpac
dotnet build "MyDatabaseProject\MyDatabaseProject.sqlproj"

# 7. Generar informe de implementación (DeployReport) y script incremental contra Docker local
$connString = "Server=localhost,1433;Database=LabDevOpsSQL;User Id=sa;Password=SeguridadSQL2026!;TrustServerCertificate=True;"
$dacpacPath = "MyDatabaseProject\bin\Debug\MyDatabaseProject.dacpac"

sqlpackage /Action:DeployReport /SourceFile:$dacpacPath /TargetConnectionString:$connString /OutputPath:"MyDatabaseProject\report.xml"
sqlpackage /Action:Script /SourceFile:$dacpacPath /TargetConnectionString:$connString /OutputPath:"MyDatabaseProject\deploy-script.sql"

# Volver a la raíz del repositorio
Set-Location ..