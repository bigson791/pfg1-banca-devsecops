variable "resource_group_name" {
  description = "Nombre del grupo de recursos en Azure"
  type        = string
  default     = "rg-pfg1-banca-devsecops"
}

variable "location" {
  description = "Región de Azure (westus2 suele tener excelente disponibilidad para cuentas de prueba)"
  type        = string
  default     = "westus2"
}

variable "cluster_name" {
  description = "Nombre del clúster AKS"
  type        = string
  default     = "aks-pfg1-banca"
}

variable "acr_name" {
  description = "Nombre único global para el Container Registry (solo letras y números)"
  type        = string
  default     = "acrpfg1banca2026gt"
}

variable "key_vault_name" {
  description = "Nombre único global para Azure Key Vault (máx 24 caracteres)"
  type        = string
  default     = "kv-pfg1-banca-2026gt"
}