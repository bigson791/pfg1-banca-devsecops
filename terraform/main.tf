terraform {
  required_version = ">= 1.5.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

data "azurerm_client_config" "current" {}

# 1. Grupo de Recursos aislado
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Proyecto     = "pfg1-banca-devsecops"
    Programa     = "MIBC-2026"
    Cumplimiento = "PCI-DSS-v4"
  }
}

# 2. Azure Container Registry (Nivel Basic para cuidar créditos)
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false # Buena práctica DevSecOps: cero contraseñas estáticas
}

# 3. Azure Key Vault para gestión de secretos fuera del código
resource "azurerm_key_vault" "kv" {
  name                       = var.key_vault_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Permite limpiar el laboratorio con terraform destroy
}

# 4. Clúster Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "akspfg1banca"
  sku_tier            = "Free" # $0.00 por el plano de control

  default_node_pool {
    name            = "systempool"
    node_count      = 1
    vm_size         = "Standard_D2s_v5" # 2 vCPU, 8 GB RAM
    os_disk_size_gb = 30
  }

  identity {
    type = "SystemAssigned"
  }

  # Habilita NetworkPolicies reales en Kubernetes (indispensable para Zero Trust)
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  # Addon gratuito para inyectar secretos de Key Vault en los Pods
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = {
    Proyecto = "pfg1-banca-devsecops"
  }
}

# 5. Permiso RBAC para que AKS descargue imágenes de ACR sin credenciales
resource "azurerm_role_assignment" "aks_acr_pull" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}