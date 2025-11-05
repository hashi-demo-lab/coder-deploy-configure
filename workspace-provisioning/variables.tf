variable "coder_url" {
  description = "URL of the Coder deployment"
  type        = string
  default     = "http://localhost:8080"
}

variable "coder_organization" {
  description = "Coder organization name"
  type        = string
  default     = "coder"
}

variable "workspace_name" {
  description = "Name of the workspace to create"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.workspace_name))
    error_message = "Workspace name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace for the workspace"
  type        = string
  default     = "coder-workspaces"
}

variable "cpu_cores" {
  description = "Number of CPU cores for the workspace"
  type        = number
  default     = 2
  validation {
    condition     = var.cpu_cores >= 1 && var.cpu_cores <= 8
    error_message = "CPU cores must be between 1 and 8."
  }
}

variable "memory_gb" {
  description = "Amount of memory in GB for the workspace"
  type        = number
  default     = 4
  validation {
    condition     = var.memory_gb >= 2 && var.memory_gb <= 16
    error_message = "Memory must be between 2 and 16 GB."
  }
}

variable "disk_size_gb" {
  description = "Disk size in GB for the workspace persistent volume"
  type        = number
  default     = 10
  validation {
    condition     = var.disk_size_gb >= 10 && var.disk_size_gb <= 100
    error_message = "Disk size must be between 10 and 100 GB."
  }
}

variable "git_repo_url" {
  description = "Git repository URL to clone into the workspace (optional)"
  type        = string
  default     = ""
}

variable "autostart_schedule" {
  description = "Cron schedule for auto-starting the workspace (optional)"
  type        = string
  default     = ""
}

variable "ttl_hours" {
  description = "Time-to-live in hours before workspace auto-stops (0 = never)"
  type        = number
  default     = 8
  validation {
    condition     = var.ttl_hours >= 0 && var.ttl_hours <= 168
    error_message = "TTL must be between 0 and 168 hours (1 week)."
  }
}
