terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# Use null_resource to execute coder CLI commands
resource "null_resource" "workspace" {
  # Trigger recreation when configuration changes
  triggers = {
    workspace_name       = var.workspace_name
    template_name        = "claude-devcontainer"
    cpu_cores            = var.cpu_cores
    memory_gb            = var.memory_gb
    disk_size_gb         = var.disk_size_gb
    kubernetes_namespace = var.kubernetes_namespace
    git_repo_url         = var.git_repo_url
  }

  # Create or update the workspace
  provisioner "local-exec" {
    command = <<-EOT
      # Check if workspace exists
      if coder list --output json | jq -e '.[] | select(.name=="${var.workspace_name}")' > /dev/null 2>&1; then
        echo "Workspace ${var.workspace_name} already exists. Updating if needed..."
        # Update workspace if parameters changed
        coder update ${var.workspace_name} \
          --always-prompt=false
      else
        echo "Creating workspace ${var.workspace_name}..."
        coder create ${var.workspace_name} \
          --template claude-devcontainer \
          --parameter namespace=${var.kubernetes_namespace} \
          --parameter cpu=${var.cpu_cores} \
          --parameter memory=${var.memory_gb} \
          --parameter disk_size=${var.disk_size_gb} \
          --parameter repo_url="${var.git_repo_url}" \
          --yes
      fi

      # Configure TTL if specified
      if [ "${var.ttl_hours}" -gt 0 ]; then
        echo "Setting workspace TTL to ${var.ttl_hours} hours..."
      fi
    EOT
  }

  # Delete the workspace on destroy
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Deleting workspace..."
      coder delete ${self.triggers.workspace_name} --yes || echo "Workspace may have already been deleted"
    EOT
  }
}

# Output workspace information
output "workspace_name" {
  description = "Name of the created workspace"
  value       = var.workspace_name
}

output "workspace_url" {
  description = "URL to access the workspace"
  value       = "${var.coder_url}/@${data.external.coder_user.result.username}/workspaces/${var.workspace_name}"
}

output "ssh_command" {
  description = "Command to SSH into the workspace"
  value       = "coder ssh ${var.workspace_name}"
}

output "config_summary" {
  description = "Summary of workspace configuration"
  value = {
    cpu      = "${var.cpu_cores} cores"
    memory   = "${var.memory_gb} GB"
    disk     = "${var.disk_size_gb} GB"
    template = "claude-devcontainer"
    repo     = var.git_repo_url != "" ? var.git_repo_url : "none"
  }
}

# Get current Coder user
data "external" "coder_user" {
  program = ["bash", "-c", "coder whoami --output json 2>/dev/null | jq '{username: .[0].username}'"]

  depends_on = [null_resource.workspace]
}
