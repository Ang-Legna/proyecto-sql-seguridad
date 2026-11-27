# ============================================================================
# MÓDULO 3 - UNIDAD 6: CANALIZACIONES CI/CD (GITHUB ACTIONS / AZURE DEVOPS)
# Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
# ============================================================================

$cicdDir = "modulo-03\cicd-templates"
New-Item -ItemType Directory -Force -Path "$cicdDir\.github\workflows" | Out-Null

# 1. Crear flujo de GitHub Actions (.github/workflows/sql-deploy.yml)
@"
name: Build and Deploy SQL Project
on:
  push:
    branches: [main]
    paths:
      - 'modulo-03/MyDatabaseProject/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build SQL project
        run: dotnet build ./modulo-03/MyDatabaseProject/MyDatabaseProject.sqlproj -o ./output

      - name: Upload dacpac artifact
        uses: actions/upload-artifact@v4
        with:
          name: dacpac
          path: ./output/MyDatabaseProject.dacpac

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Download dacpac artifact
        uses: actions/download-artifact@v4
        with:
          name: dacpac

      - name: Install SqlPackage
        run: dotnet tool install -g microsoft.sqlpackage

      - uses: azure/login@v2
        with:
          client-id: `${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: `${{ secrets.AZURE_TENANT_ID }}
          subscription-id: `${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - uses: azure/sql-action@v2.3
        with:
          connection-string: `${{ secrets.AZURE_SQL_CONNECTION_STRING }}
          path: './MyDatabaseProject.dacpac'
          action: 'publish'
"@ | Set-Content -Path "$cicdDir\.github\workflows\sql-deploy.yml" -Encoding UTF8

# 2. Crear canalización equivalente de Azure DevOps (azure-pipelines.yml)
@"
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - modulo-03/MyDatabaseProject/*

pool:
  vmImage: 'windows-latest'

steps:
  - task: DotNetCoreCLI@2
    displayName: 'Build SQL Database Project'
    inputs:
      command: 'build'
      projects: './modulo-03/MyDatabaseProject/MyDatabaseProject.sqlproj'
      arguments: '-o `$(Build.ArtifactStagingDirectory)'

  - task: PublishBuildArtifacts@1
    displayName: 'Publish DACPAC Artifact'
    inputs:
      PathtoPublish: '`$(Build.ArtifactStagingDirectory)/MyDatabaseProject.dacpac'
      ArtifactName: 'dacpac'

  - task: SqlAzureDacpacDeployment@1
    displayName: 'Deploy DACPAC to Azure SQL'
    inputs:
      azureSubscription: 'your-service-connection'
      AuthenticationType: 'server'
      ServerName: 'your-server.database.windows.net'
      DatabaseName: 'LabDevOpsSQL'
      SqlUsername: '`$(SqlUser)'
      SqlPassword: '`$(SqlPassword)'
      deployType: 'DacpacTask'
      DeploymentAction: 'Publish'
      DacpacFile: '`$(Build.ArtifactStagingDirectory)/MyDatabaseProject.dacpac'
"@ | Set-Content -Path "$cicdDir\azure-pipelines.yml" -Encoding UTF8

# 3. Crear archivo de gobernanza CODEOWNERS para revisión obligatoria de cambios SQL
@"
# .github/CODEOWNERS - Revisión obligatoria para cambios de esquema
/modulo-03/MyDatabaseProject/ @db-team
*.sql @db-team @dba-lead
"@ | Set-Content -Path "$cicdDir\.github\CODEOWNERS" -Encoding UTF8

# 4. Simular localmente el paso de Build del pipeline hacia una carpeta de artefactos
Write-Host "`n--- Simulando etapa CI Build hacia $cicdDir\artifact-output ---" -ForegroundColor Cyan
dotnet build "modulo-03\MyDatabaseProject\MyDatabaseProject.sqlproj" -o "$cicdDir\artifact-output"

Write-Host "`nArchivos CI/CD generados correctamente en $cicdDir" -ForegroundColor Green