terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

# Coder provider configuration
provider "coder" {}

# Kubernetes provider configuration
# Use in-cluster configuration when running inside Kubernetes (Coder),
# fall back to kubeconfig for local development
provider "kubernetes" {
  # Leave empty to use in-cluster config or KUBECONFIG environment variable
}

# Workspace metadata
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Parameters
data "coder_parameter" "namespace" {
  name         = "namespace"
  display_name = "Kubernetes Namespace"
  description  = "The Kubernetes namespace to deploy the workspace into"
  default      = "coder-workspaces"
  mutable      = false
}

data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores"
  default      = "2"
  mutable      = true
  type         = "number"
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of memory in GB"
  default      = "4"
  mutable      = true
  type         = "number"
  validation {
    min = 2
    max = 16
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "Size of the persistent volume"
  default      = "10"
  mutable      = false
  type         = "number"
  validation {
    min = 10
    max = 100
  }
}

# Git repository to clone
data "coder_parameter" "repo_url" {
  name         = "repo_url"
  display_name = "Git Repository URL"
  description  = "Git repository to clone into workspace"
  default      = ""
  mutable      = true
}

# Reference the existing namespace (must be created beforehand)
# The namespace should be created by the Coder administrator
locals {
  namespace = data.coder_parameter.namespace.value
}

# Persistent Volume Claim for workspace storage
resource "kubernetes_persistent_volume_claim" "workspace" {
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
    namespace = local.namespace
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }
}

# Persistent Volume Claim for Claude config
resource "kubernetes_persistent_volume_claim" "claude_config" {
  metadata {
    name      = "claude-config-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
    namespace = local.namespace
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

# Kubernetes Pod for the workspace
resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = data.coder_workspace.me.name
      "app.kubernetes.io/owner"    = data.coder_workspace_owner.me.name
    }
  }

  spec {
    container {
      name  = "dev"
      image = "ghcr.io/coder/envbuilder:latest"

      security_context {
        allow_privilege_escalation = true
        privileged                 = true
        capabilities {
          add = ["NET_ADMIN", "NET_RAW"]
        }
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }

      env {
        name  = "ENVBUILDER_GIT_URL"
        value = "https://github.com/srlynch1/claude-devcontainer-no-cloud"
      }

      env {
        name  = "ENVBUILDER_DEVCONTAINER_DIR"
        value = ".devcontainer"
      }

      env {
        name  = "ENVBUILDER_INIT_SCRIPT"
        value = coder_agent.main.init_script
      }

      env {
        name  = "ENVBUILDER_WORKSPACE_FOLDER"
        value = "/workspace"
      }

      env {
        name  = "ENVBUILDER_CACHE_DIR"
        value = "/workspace/.envbuilder-cache"
      }

      env {
        name  = "NODE_OPTIONS"
        value = "--max-old-space-size=4096"
      }

      env {
        name  = "CLAUDE_CONFIG_DIR"
        value = "/home/node/.claude"
      }

      env {
        name  = "CLAUDE_GITHUB_MCP_ENABLED"
        value = "true"
      }

      env {
        name  = "POWERLEVEL9K_DISABLE_GITSTATUS"
        value = "true"
      }

      # Environment variables for credentials (to be set by user or secrets)
      env {
        name  = "GITHUB_TOKEN"
        value = ""
      }

      env {
        name  = "TFE_TOKEN"
        value = ""
      }

      env {
        name  = "AWS_ACCESS_KEY_ID"
        value = ""
      }

      env {
        name  = "AWS_SECRET_ACCESS_KEY"
        value = ""
      }

      resources {
        requests = {
          "cpu"    = "${data.coder_parameter.cpu.value}"
          "memory" = "${data.coder_parameter.memory.value}Gi"
        }
        limits = {
          "cpu"    = "${data.coder_parameter.cpu.value}"
          "memory" = "${data.coder_parameter.memory.value}Gi"
        }
      }

      volume_mount {
        name       = "workspace"
        mount_path = "/workspace"
      }

      volume_mount {
        name       = "claude-config"
        mount_path = "/home/node/.claude"
      }
    }

    volume {
      name = "workspace"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.workspace.metadata[0].name
      }
    }

    volume {
      name = "claude-config"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.claude_config.metadata[0].name
      }
    }
  }
}

# Coder agent
resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Clone repository if specified
    if [ -n "${data.coder_parameter.repo_url.value}" ]; then
      if [ ! -d "/workspace/.git" ]; then
        git clone ${data.coder_parameter.repo_url.value} /workspace/repo
      fi
    fi

    # Configure Terraform credentials if TFE_TOKEN is set
    if [ -n "$TFE_TOKEN" ]; then
      mkdir -p ~/.terraform.d
      cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "$TFE_TOKEN"
    }
  }
}
EOF
    fi

    echo "Workspace ready!"
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 10
    timeout      = 1
    script       = "coder stat cpu"
  }

  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 10
    timeout      = 1
    script       = "coder stat mem"
  }

  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 60
    timeout      = 1
    script       = "df -h /workspace | awk 'NR==2{print $5}'"
  }
}

# Coder app for VS Code Web
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337?folder=/workspace"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
}

# Coder app for terminal
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
  command      = "zsh"
  share        = "owner"
}
