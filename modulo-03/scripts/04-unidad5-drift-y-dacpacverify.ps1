# ============================================================================
# MÓDULO 3 - UNIDAD 5: DETECCIÓN DE DESFASE (DRIFT) Y DACPACVERIFY
# Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
# ============================================================================

$connString = "Server=localhost,1433;Database=LabDevOpsSQL;User Id=sa;Password=SeguridadSQL2026!;TrustServerCertificate=True;"
$dacpacPath = "modulo-03\MyDatabaseProject\bin\Debug\MyDatabaseProject.dacpac"
$driftDir   = "modulo-03\drift-check-output"

# 1. Instalar herramienta global DacpacVerify si no está presente
if (-not (Get-Command dacpacverify -ErrorAction SilentlyContinue)) {
    dotnet tool install -g microsoft.dacpacverify
}

# 2. Publicar el estado esperado del proyecto hacia LabDevOpsSQL
Write-Host "`n--- 1. Publicando modelo base en LabDevOpsSQL ---" -ForegroundColor Cyan
sqlpackage /Action:Publish /SourceFile:$dacpacPath /TargetConnectionString:$connString

# 3. Simular un desfase manual (Schema Drift) directamente en la base de datos
Write-Host "`n--- 2. Simulando cambio manual (Schema Drift) en dbo.Customers ---" -ForegroundColor Yellow
docker exec sql-lab /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "SeguridadSQL2026!" -C -d LabDevOpsSQL -Q "
IF COL_LENGTH('dbo.Customers', 'ManualAuditNote') IS NULL
    ALTER TABLE dbo.Customers ADD ManualAuditNote NVARCHAR(100) NULL;
"

# 4. Extraer el esquema real organizado por tipo de objeto (ExtractTarget=SchemaObjectType)
if (Test-Path $driftDir) { Remove-Item -Recurse -Force $driftDir }
Write-Host "`n--- 3. Extrayendo esquema activo con /p:ExtractTarget=SchemaObjectType ---" -ForegroundColor Cyan
sqlpackage /Action:Extract /SourceConnectionString:$connString /TargetFile:$driftDir /p:ExtractTarget=SchemaObjectType

# 5. Generar DeployReport XML y script de reconciliación (Deployment.sql) antes de aplicar
Write-Host "`n--- 4. Generando DeployReport.xml y Deployment.sql para revisar diferencias ---" -ForegroundColor Cyan
sqlpackage /Action:DeployReport /SourceFile:$dacpacPath /TargetConnectionString:$connString /OutputPath:"$driftDir\DeployReport.xml"
sqlpackage /Action:Script /SourceFile:$dacpacPath /TargetConnectionString:$connString /DeployScriptPath:"$driftDir\Deployment.sql"

# 6. Comparar el .dacpac compilado contra un .dacpac extraído de la BD con desfase usando DacpacVerify
Write-Host "`n--- 5. Ejecutando DacpacVerify entre el proyecto y la BD con desfase ---" -ForegroundColor Cyan
sqlpackage /Action:Extract /SourceConnectionString:$connString /TargetFile:"$driftDir\live-drifted.dacpac"
dacpacverify $dacpacPath "$driftDir\live-drifted.dacpac"