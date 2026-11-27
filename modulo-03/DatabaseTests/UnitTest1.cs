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
