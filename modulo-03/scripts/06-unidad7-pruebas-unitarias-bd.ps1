# ============================================================================
# MÓDULO 3 - UNIDAD 7: PRUEBAS UNITARIAS DE BASE DE DATOS (POSITIVAS Y NEGATIVAS)
# Proyecto: Optimización y Seguridad en SQL Server / Azure SQL
# ============================================================================

$connString = "Server=localhost,1433;Database=LabDevOpsSQL;User Id=sa;Password=SeguridadSQL2026!;TrustServerCertificate=True;"
$projDir    = "modulo-03\MyDatabaseProject"
$testDir    = "modulo-03\DatabaseTests"

# 1. Agregar procedimiento almacenado con regla de negocio (usp_CancelOrder)
@"
CREATE PROCEDURE [dbo].[usp_CancelOrder]
    @OrderID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CurrentStatus INT;
    SELECT @CurrentStatus = [StatusID] FROM [dbo].[Orders] WHERE [OrderID] = @OrderID;

    IF @CurrentStatus IS NULL
        THROW 50002, 'El pedido especificado no existe.', 1;

    -- Si el pedido ya fue entregado (StatusID = 4), lanzar error controlado (Severity 16, State 1)
    IF @CurrentStatus = 4
        THROW 50001, 'No se puede cancelar un pedido que ya fue entregado.', 1;

    UPDATE [dbo].[Orders]
    SET [StatusID] = 5 -- Cancelled
    WHERE [OrderID] = @OrderID;
END;
"@ | Set-Content -Path "$projDir\StoredProcedures\usp_CancelOrder.sql" -Encoding UTF8

# 2. Compilar y publicar el esquema actualizado en LabDevOpsSQL
Write-Host "`n--- 1. Compilando y desplegando esquema actualizado en LabDevOpsSQL ---" -ForegroundColor Cyan
dotnet build "$projDir\MyDatabaseProject.sqlproj"
sqlpackage /Action:Publish /SourceFile:"$projDir\bin\Debug\MyDatabaseProject.dacpac" /TargetConnectionString:$connString

# 3. Crear proyecto MSTest en .NET para ejecutar pruebas unitarias con 'dotnet test'
Write-Host "`n--- 2. Creando proyecto MSTest (DatabaseTests) ---" -ForegroundColor Cyan
if (Test-Path $testDir) { Remove-Item -Recurse -Force $testDir }
dotnet new mstest -n DatabaseTests -o $testDir | Out-Null
dotnet add "$testDir\DatabaseTests.csproj" package Microsoft.Data.SqlClient | Out-Null

@"
using Microsoft.Data.SqlClient;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System;

namespace DatabaseTests
{
    [TestClass]
    public class OrderProceduresTests
    {
        private const string ConnStr = "Server=localhost,1433;Database=LabDevOpsSQL;User Id=sa;Password=SeguridadSQL2026!;TrustServerCertificate=True;";

        [TestInitialize]
        public void SetupTestData()
        {
            using var conn = new SqlConnection(ConnStr);
            conn.Open();
            using var cmd = conn.CreateCommand();
            cmd.CommandText = @"
                DELETE FROM [dbo].[Orders] WHERE [OrderID] IN (9001, 9002);
                DELETE FROM [dbo].[Customers] WHERE [CustomerID] = 9001;
                INSERT INTO [dbo].[Customers] ([CustomerID], [FirstName], [LastName], [Email])
                VALUES (9001, N'Test', N'Customer', N'test@utp.ac.pa');
                INSERT INTO [dbo].[Orders] ([OrderID], [CustomerID], [StatusID], [TotalAmount])
                VALUES (9001, 9001, 1, 250.00), -- Pending (cancelable)
                       (9002, 9001, 4, 500.00); -- Delivered (no cancelable)";
            cmd.ExecuteNonQuery();
        }

        [TestMethod]
        public void uspCancelOrder_PendingOrder_UpdatesStatusToCancelled()
        {
            using var conn = new SqlConnection(ConnStr);
            conn.Open();
            using var execCmd = new SqlCommand("EXEC [dbo].[usp_CancelOrder] @OrderID = 9001;", conn);
            execCmd.ExecuteNonQuery();

            using var verifyCmd = new SqlCommand("SELECT [StatusID] FROM [dbo].[Orders] WHERE [OrderID] = 9001;", conn);
            int statusId = Convert.ToInt32(verifyCmd.ExecuteScalar());
            Assert.AreEqual(5, statusId, "El pedido pendiente debe cambiar a estado Cancelled (5).");
        }

        [TestMethod]
        public void uspCancelOrder_DeliveredOrder_ThrowsSqlException()
        {
            using var conn = new SqlConnection(ConnStr);
            conn.Open();
            using var execCmd = new SqlCommand("EXEC [dbo].[usp_CancelOrder] @OrderID = 9002;", conn);

            var ex = Assert.ThrowsException<SqlException>(() => execCmd.ExecuteNonQuery());
            Assert.AreEqual(50001, ex.Number);
            Assert.AreEqual((byte)16, ex.Class);
            Assert.AreEqual((byte)1, ex.State);
        }
    }
}
"@ | Set-Content -Path "$testDir\UnitTest1.cs" -Encoding UTF8

# 4. Ejecutar suite de pruebas unitarias mediante dotnet test (igual que en GitHub Actions)
Write-Host "`n--- 3. Ejecutando pruebas unitarias con dotnet test ---" -ForegroundColor Cyan
dotnet test "$testDir\DatabaseTests.csproj" --logger "console;verbosity=normal"