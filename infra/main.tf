
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-${var.environment}-rg"
  location = var.location

  tags = {
    project     = "iris-ml-api"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_container_registry" "main" {
  name                = "${var.project_name}${var.environment}${var.registry_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = "francecentral"
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    project     = "iris-ml-api"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-logs"
  location            = var.container_app_location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    project     = "iris-ml-api"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_container_app_environment" "main" {
  name                       = "${var.project_name}-${var.environment}-env"
  location                   = var.container_app_location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  tags = {
    project     = "iris-ml-api"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_user_assigned_identity" "api" {
  name                = "${var.project_name}-${var.environment}-identity"
  location            = var.container_app_location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    project     = "iris-ml-api"
    environment = var.environment
    managed_by  = "terraform"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app" "api" {
  name                         = "${var.project_name}-${var.environment}-api"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  template {
    min_replicas = 0
    max_replicas = 1

    http_scale_rule {
      name                = "http-scaler"
      concurrent_requests = "10"
    }

    container {
      name   = "iris-ml-api"
      image  = "${azurerm_container_registry.main.login_server}/iris-ml-api:1.0"
      cpu    = 0.25
      memory = "0.5Gi"

      liveness_probe {
        transport        = "HTTP"
        port             = 8000
        path             = "/health"
        initial_delay    = 10
        interval_seconds = 30
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  tags = {
    project     = "iris-ml-api"
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]

  lifecycle {
    ignore_changes = [
      template[0].container[0].image
    ]
  }
}
