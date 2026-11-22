using System;
using System.Collections.Generic;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Sql;
using Microsoft.Extensions.Logging;

namespace LabDataAPI.Events
{
    public static class OrderChangedTrigger
    {
        [FunctionName("OrderChangedTrigger")]
        public static void Run(
            [SqlTrigger("[dbo].[Orders]", "SqlConnectionString")]
            IReadOnlyList<SqlChange<Order>> changes,
            ILogger log)
        {
            foreach (var change in changes)
            {
                log.LogInformation($"Change operation: {change.Operation}");
                log.LogInformation($"Order ID: {change.Item.OrderId}");

                if (change.Operation == SqlChangeOperation.Update)
                {
                    // Procesar actualización del pedido en tiempo real
                    log.LogInformation($"Order {change.Item.OrderId} updated to status: {change.Item.Status}");
                }
            }
        }
    }

    public class Order
    {
        public int OrderId { get; set; }
        public int CustomerId { get; set; }
        public DateTime OrderDate { get; set; }
        public string Status { get; set; }
    }
}