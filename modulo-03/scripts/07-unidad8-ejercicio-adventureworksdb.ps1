# ============================================================================
# MÓDULO 3 - UNIDAD 8 (EJERCICIO): IMPLEMENT CI/CD WITH SQL DATABASE PROJECTS
# Ejecución completa sobre SQL Server en Docker (sql-lab)
# ============================================================================

$ErrorActionPreference = "Stop"
$baseDir = "modulo-03\AdventureWorksDB"
$dbConn  = "Server=localhost,1433;Database=AdventureWorksLT;User Id=sa;Password=SeguridadSQL2026!;TrustServerCertificate=True;"

function Invoke-DockerSql {
    param([string]$Database = "master", [string]$Query)
    docker exec sql-lab /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "SeguridadSQL2026!" -d $Database -C -Q $Query
}

# 1. Crear base de datos AdventureWorksLT en el contenedor Docker si no existe
Write-Host "`n--- 1. Provisionando base de datos AdventureWorksLT en Docker (sql-lab) ---" -ForegroundColor Cyan
Invoke-DockerSql -Query "IF DB_ID('AdventureWorksLT') IS NULL CREATE DATABASE [AdventureWorksLT];"

# 2. Inicializar proyecto SQL SDK-style
if (Test-Path $baseDir) { Remove-Item -Recurse -Force $baseDir }
New-Item -ItemType Directory -Force -Path $baseDir | Out-Null
Push-Location $baseDir

Write-Host "`n--- 2. Inicializando proyecto SDK-style (AdventureWorksDB.sqlproj) ---" -ForegroundColor Cyan
dotnet new sqlproj -tp SqlAzureV12

New-Item -ItemType Directory -Force -Path "Tables", "StoredProcedures", ".github\workflows" | Out-Null

# 3. Crear definición declarativa inicial de tabla y procedimiento almacenado
@"
CREATE TABLE [dbo].[InventoryLog] (
    [LogID] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [ProductID] INT NOT NULL,
    [ChangeDate] DATETIME2 NOT NULL DEFAULT GETDATE(),
    [QuantityChange] INT NOT NULL,
    [ChangeType] NVARCHAR(20) NOT NULL
);
"@ | Set-Content -Path "Tables\InventoryLog.sql" -Encoding UTF8

@"
CREATE PROCEDURE [dbo].[uspLogInventoryChange]
    @ProductID INT,
    @QuantityChange INT,
    @ChangeType NVARCHAR(20)
AS
BEGIN
    INSERT INTO [dbo].[InventoryLog] (ProductID, QuantityChange, ChangeType)
    VALUES (@ProductID, @QuantityChange, @ChangeType);
END;
"@ | Set-Content -Path "StoredProcedures\uspLogInventoryChange.sql" -Encoding UTF8

@"
bin/
obj/
"@ | Set-Content -Path ".gitignore" -Encoding UTF8

# 4. Guardar plantilla de GitHub Actions requerida por el laboratorio
@"
name: Build and Deploy SQL Database Project

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Setup .NET SDK
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.x'
      - name: Build SQL project
        run: dotnet build AdventureWorksDB.sqlproj
      - name: Install SqlPackage
        run: dotnet tool install -g microsoft.sqlpackage
      - name: Deploy to Azure SQL Database
        uses: azure/sql-action@v2.3
        with:
          connection-string: `${{ secrets.SQL_CONNECTION_STRING }}
          path: ./bin/Debug/AdventureWorksDB.dacpac
          action: publish
"@ | Set-Content -Path ".github\workflows\build-deploy.yml" -Encoding UTF8

# 5. Compilar y ejecutar primer despliegue hacia Docker (AdventureWorksLT)
Write-Host "`n--- 3. Compilando y desplegando v1 (InventoryLog + uspLogInventoryChange) ---" -ForegroundColor Cyan
dotnet build
sqlpackage /Action:Publish /SourceFile:"bin\Debug\AdventureWorksDB.dacpac" /TargetConnectionString:$dbConn

# Verificar objetos creados en v1
Invoke-DockerSql -Database "AdventureWorksLT" -Query "SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'InventoryLog'; SELECT ROUTINE_SCHEMA, ROUTINE_NAME FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_NAME = 'uspLogInventoryChange';"

# 6. Simular 'Push a schema change': agregar columna [Notes] de forma declarativa
Write-Host "`n--- 4. Evolucionando esquema declarativo (agregando columna [Notes]) ---" -ForegroundColor Cyan
@"
CREATE TABLE [dbo].[InventoryLog] (
    [LogID] INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    [ProductID] INT NOT NULL,
    [ChangeDate] DATETIME2 NOT NULL DEFAULT GETDATE(),
    [QuantityChange] INT NOT NULL,
    [ChangeType] NVARCHAR(20) NOT NULL,
    [Notes] NVARCHAR(200) NULL
);
"@ | Set-Content -Path "Tables\InventoryLog.sql" -Encoding UTF8

dotnet build
sqlpackage /Action:Publish /SourceFile:"bin\Debug\AdventureWorksDB.dacpac" /TargetConnectionString:$dbConn

# Verificar que SqlPackage generó y ejecutó el ALTER TABLE automáticamente
Write-Host "`n--- 5. Verificando estructura final de dbo.InventoryLog en Docker ---" -ForegroundColor Green
Invoke-DockerSql -Database "AdventureWorksLT" -Query "SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'InventoryLog';"

Pop-Location