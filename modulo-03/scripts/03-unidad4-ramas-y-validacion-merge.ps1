# ============================================================================
# MÓDULO 3 - UNIDAD 4: RAMAS DE CARACTERÍSTICAS, CONFLICTOS Y VALIDACIÓN BUILD
# Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
# ============================================================================

$sandbox = "modulo-03\git-branch-lab"
if (Test-Path $sandbox) { Remove-Item -Recurse -Force $sandbox }
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null

# 1. Copiar proyecto limpio al sandbox de simulación Git (sin bin/obj)
Copy-Item "modulo-03\MyDatabaseProject\MyDatabaseProject.sqlproj" "$sandbox\"
Copy-Item "modulo-03\MyDatabaseProject\.gitignore" "$sandbox\"
Copy-Item -Recurse "modulo-03\MyDatabaseProject\Tables" "$sandbox\Tables"
Copy-Item -Recurse "modulo-03\MyDatabaseProject\Views" "$sandbox\Views"
Copy-Item -Recurse "modulo-03\MyDatabaseProject\StoredProcedures" "$sandbox\StoredProcedures"

Set-Location $sandbox

# 2. Inicializar repositorio Git aislado en rama main
git init -b main | Out-Null
git config user.email "utp-lab@proyecto-sql.local"
git config user.name "Equipo UTP Azuero"
git add .
git commit -m "Initial commit of database project" | Out-Null

# 3. Rama 1: feature/add-customer-phone (fusionada a main)
git checkout -b feature/add-customer-phone | Out-Null
@"
CREATE TABLE [dbo].[Customers]
(
    [CustomerID] INT NOT NULL PRIMARY KEY,
    [FirstName] NVARCHAR(50) NOT NULL,
    [LastName] NVARCHAR(50) NOT NULL,
    [Email] NVARCHAR(100) NULL,
    [Phone] NVARCHAR(20) NULL
);
"@ | Set-Content -Path "Tables\Customers.sql" -Encoding UTF8
git add Tables\Customers.sql
git commit -m "Add Phone column to Customers table" | Out-Null

git checkout main | Out-Null
git merge feature/add-customer-phone | Out-Null

# 4. Rama 2: feature/add-customer-address (creada desde el commit inicial, genera conflicto)
git checkout -b feature/add-customer-address HEAD~1 | Out-Null
@"
CREATE TABLE [dbo].[Customers]
(
    [CustomerID] INT NOT NULL PRIMARY KEY,
    [FirstName] NVARCHAR(50) NOT NULL,
    [LastName] NVARCHAR(50) NOT NULL,
    [Email] NVARCHAR(100) NULL,
    [Address] NVARCHAR(200) NULL
);
"@ | Set-Content -Path "Tables\Customers.sql" -Encoding UTF8
git add Tables\Customers.sql
git commit -m "Add Address column to Customers table" | Out-Null

# 5. Intentar traer main a la rama de características (provoca merge conflict)
Write-Host "`n--- Ejecutando git merge main (se espera conflicto en Tables/Customers.sql) ---" -ForegroundColor Yellow
git merge main

# 6. Resolver el conflicto combinando ambas columnas (Phone y Address)
@"
CREATE TABLE [dbo].[Customers]
(
    [CustomerID] INT NOT NULL PRIMARY KEY,
    [FirstName] NVARCHAR(50) NOT NULL,
    [LastName] NVARCHAR(50) NOT NULL,
    [Email] NVARCHAR(100) NULL,
    [Phone] NVARCHAR(20) NULL,
    [Address] NVARCHAR(200) NULL
);
"@ | Set-Content -Path "Tables\Customers.sql" -Encoding UTF8

git add Tables\Customers.sql
git commit -m "Resolve merge conflict: include both Phone and Address columns" | Out-Null

# 7. Validar integridad de esquema y referencias tras resolver conflictos
Write-Host "`n--- Validando modelo tras resolución de conflictos con dotnet build ---" -ForegroundColor Cyan
dotnet build MyDatabaseProject.sqlproj

# 8. Mostrar historial de ramas y volver a la raíz
git log --oneline --graph --all
Set-Location ..\..