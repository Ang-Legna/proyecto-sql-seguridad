#!/bin/bash
# ============================================================================
# CONFIGURACIÓN DE TELEMETRÍA Y ALERTAS PROACTIVAS PARA DATA API BUILDER (DAB)
# ============================================================================

# 1. Habilitar integración automática con Application Insights mediante variable de entorno
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=your-key;IngestionEndpoint=https://region.in.applicationinsights.azure.com/"

# 2. Vincular el entorno de Azure Container Apps a un área de trabajo de Log Analytics
az containerapp env update \
  --name myContainerAppEnv \
  --resource-group myResourceGroup \
  --logs-workspace-id "<workspace-id>"

# 3. Crear regla de alerta proactiva cuando la tasa de fallos supera el 5% en 5 minutos
az monitor metrics alert create \
  --name "DAB-HighErrorRate" \
  --resource-group myResourceGroup \
  --scopes "/subscriptions/.../components/myAppInsights" \
  --condition "avg requests/failed > 5" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action-group myActionGroup