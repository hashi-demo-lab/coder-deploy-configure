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

provider "coder" {}

provider "kubernetes" {}

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
  default      = "4"
  mutable      = true
  type         = "number"
  validation {
    min = 2
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of memory in GB"
  default      = "8"
  mutable      = true
  type         = "number"
  validation {
    min = 4
    max = 16
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "Size of the persistent volume"
  default      = "20"
  mutable      = false
  type         = "number"
  validation {
    min = 10
    max = 100
  }
}

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

# Coder agent
resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"

  startup_script = <<-EOT
    #!/bin/bash
    set -e

    # Configure shell
    if [ ! -f ~/.zshrc ]; then
      cp /etc/skel/.zshrc ~/.zshrc 2>/dev/null || true
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
    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }

    container {
      name  = "dev"
      image = "codercom/enterprise-node:ubuntu"
      command = ["sh", "-c", coder_agent.main.init_script]

      security_context {
        run_as_user = 1000
      }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
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
        mount_path = "/home/coder/workspace"
      }

      volume_mount {
        name       = "claude-config"
        mount_path = "/home/coder/.claude"
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

# Coder app for VS Code Web
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337?folder=/home/coder/workspace"
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
  command      = "bash"
  share        = "owner"
}
