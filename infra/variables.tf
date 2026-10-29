
variable "location" {
  description = "Azure region for deployment"
  type        = string
  default     = "westeurope"
}

variable "project_name" {
  description = "Short name used to identify project resources"
  type        = string
  default     = "irismlapi"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "registry_suffix" {
  description = "Short globally unique suffix for the container registry"
  type        = string
  default     = "rm28"
}
variable "container_app_location" {
  description = "Azure region for Container Apps resources"
  type        = string
  default     = "francecentral"
}