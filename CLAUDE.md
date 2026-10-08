# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository deploys Coder on Docker Desktop or Rancher Desktop Kubernetes and provisions cloud development workspaces with a custom Claude Code devcontainer environment.

## Common Commands

### Initial Deployment

```bash
# Deploy Coder platform to Kubernetes
./deploy.sh

# Deploy the Claude Code devcontainer template
./deploy-template.sh

# Fix RBAC permissions if workspace creation fails
./fix-rbac.sh

# Complete cleanup (destroys all data)
./cleanup.sh
```

### Workspace Management

```bash
# Create workspace via Terraform
cd workspace-provisioning
terraform init
terraform apply

# Create workspace via Coder CLI
coder create my-workspace --template claude-devcontainer \
  --parameter namespace=coder-workspaces \
  --parameter cpu=2 \
  --parameter memory=4 \
  --parameter disk_size=10

# Access workspace
coder ssh my-workspace

# Delete workspace
terraform destroy  # or: coder delete my-workspace
```

### Template Development

```bash
# Test template changes
cd coder-template
coder templates push claude-devcontainer --directory . --yes

# Validate template
terraform fmt
terraform validate
```

### Kubernetes Operations

```bash
# Check Coder deployment status
kubectl get pods -n coder

# Check workspace pods
kubectl get pods -n coder-workspaces

# View workspace logs
kubectl logs -n coder-workspaces <pod-name> --tail=100

# Debug workspace issues
kubectl describe pod -n coder-workspaces <pod-name>
```

## Architecture

### Component Structure

1. **Coder Platform** (`/` root): Helm-based Coder deployment on Docker Desktop or Rancher Desktop Kubernetes
2. **Workspace Template** (`coder-template/`): Terraform template defining workspace infrastructure
3. **Workspace Provisioning** (`workspace-provisioning/`): Terraform configuration for creating workspaces as code

### Deployment Flow

```
deploy.sh
  ├─> Creates 'coder' namespace
  ├─> Deploys PostgreSQL (Bitnami Helm chart)
  ├─> Creates database connection secret
  └─> Deploys Coder (official Helm chart)

deploy-template.sh
  ├─> Authenticates with Coder
  ├─> Creates 'coder-workspaces' namespace
  └─> Pushes template from coder-template/

workspace-provisioning/
  └─> Uses coder CLI to create workspaces
      (not Coder Terraform provider, uses null_resource)
```

### Template Architecture (Envbuilder-based)

The `coder-template/main.tf` uses **Coder's envbuilder** instead of pre-built images:

1. **Runtime Image**: `ghcr.io/coder/envbuilder:latest`
2. **Build Source**: `https://github.com/srlynch1/claude-devcontainer-no-cloud`
3. **Devcontainer Path**: `.devcontainer/devcontainer.json`
4. **Build Strategy**: On-demand from source during workspace creation

**Key Configuration**:
```hcl
env {
  name  = "ENVBUILDER_GIT_URL"
  value = "https://github.com/srlynch1/claude-devcontainer-no-cloud"
}
env {
  name  = "ENVBUILDER_DEVCONTAINER_DIR"
  value = ".devcontainer"
}
env {
  name  = "ENVBUILDER_WORKSPACE_FOLDER"
  value = "/workspace"
}
env {
  name  = "ENVBUILDER_CACHE_DIR"
  value = "/workspace/.envbuilder-cache"
}
```

**Critical Security Context**:
- No `run_as_user` restrictions (envbuilder requires root for build)
- `privileged: true` for Docker-in-Docker and container builds
- `allow_privilege_escalation: true` for envbuilder functionality

### Storage Architecture

**Workspace PVCs** (per workspace):
- `coder-{owner}-{workspace}`: Main workspace data (10-100 GB, configurable)
- `claude-config-{owner}-{workspace}`: Claude Code config (1 GB, persistent)

**Notable Decisions**:
- Bash history PVC removed (devcontainer creates `/commandhistory` itself)
- Docker socket mount removed (incompatible with Docker Desktop Kubernetes nodes)
- `wait_until_bound = false` on all PVCs (avoids deadlock with WaitForFirstConsumer binding mode)

### Workspace Provisioning Pattern

The `workspace-provisioning/` module **does not use** the Coder Terraform provider. Instead:

```hcl
resource "null_resource" "workspace" {
  provisioner "local-exec" {
    command = <<-EOT
      coder create ${var.workspace_name} \
        --template claude-devcontainer \
        --parameter namespace=${var.kubernetes_namespace} \
        --yes
    EOT
  }
}
```

This approach uses Coder CLI instead of Terraform provider for simpler local development authentication.

## Dev Container Overview

The custom dev container is based on a modified version of [ai-iac-consumer-template](https://github.com/panchal-ravi/ai-iac-consumer-template), optimized for faster builds by removing cloud CLI tools. Source: [claude-devcontainer-no-cloud](https://github.com/srlynch1/claude-devcontainer-no-cloud).

Key modifications:
- Cloud CLI tools (AWS, Azure, GCP) removed to reduce build time from 10-15 minutes to 2-3 minutes
- All Terraform and IaC tools retained
- `cloud-cli-tools.sh` replaced with stub script

The dev container includes:

### Base Configuration
- **Base Image**: Node.js 20
- **Shell**: Zsh with Powerline10k theme
- **User**: node (non-root with sudo access)
- **Claude Code CLI**: Pre-installed via npm

### Installed Tools

#### Infrastructure as Code Tools (via terraform-tools.sh)
- **Terraform**: 1.13.4
- **terraform-docs**: 0.20.0 - Generate documentation from Terraform modules
- **tfsec**: Security scanner for Terraform code
- **terrascan**: Policy-based infrastructure scanner
- **tflint**: Terraform linter with cloud provider rulesets (AWS, Azure, GCP)
- **Checkov**: 3.2.489 - Infrastructure-as-code security scanner
- **Infracost**: 0.10.42 - Cloud cost estimation tool
- **pre-commit**: Git hooks framework for automated checks

#### Cloud CLIs (via cloud-cli-tools.sh)
- **SKIPPED**: Cloud CLI tools (AWS, Azure, GCP) are intentionally excluded to reduce build time from 10-15 minutes to 2-3 minutes
- The `cloud-cli-tools.sh` script is a stub that exits immediately

#### Development Tools
- **Git**: Version control with git-delta for improved diffs
- **Python 3**: With uv package manager
- **Node.js 20**: JavaScript runtime with 4GB memory allocation
- **jq**: JSON processor
- **curl**: Data transfer tool
- **fzf**: Fuzzy finder for command-line

#### VS Code Extensions
- **Claude Code** (Anthropic.claude-code): AI pair programming
- **Terraform** (hashicorp.terraform): Terraform syntax and validation
- **HCL** (HashiCorp.HCL): HashiCorp Configuration Language support
- **ESLint** (dbaeumer.vscode-eslint): JavaScript/TypeScript linting
- **Prettier** (esbenp.prettier-vscode): Code formatting
- **YAML** (redhat.vscode-yaml): YAML language support

### Features
- **Docker-in-Docker**: Full Docker daemon support with privileged access
- **Persistent Storage**:
  - Bash history via `/commandhistory`
  - Claude Code configuration via `/home/node/.claude`
  - Workspace data via `/workspace`
- **Auto-configuration**: Terraform credentials automatically configured from environment
- **Environment Injection**: GitHub, AWS, and Terraform tokens passed from host
- **Network Capabilities**: NET_ADMIN and NET_RAW for advanced networking

## Library Scripts

The devcontainer uses two library scripts during the build process:

### cloud-cli-tools.sh
**STUB SCRIPT** - Cloud CLI installation is skipped for faster builds:
- Original script installed AWS CLI v2, Azure CLI, and Google Cloud SDK
- Installation took 10-15 minutes and added hundreds of MBs
- Now replaced with a stub that exits immediately
- Build time reduced to 2-3 minutes
- Terraform and IaC tools are still fully installed

### terraform-tools.sh
Installs Terraform ecosystem tools with configurable versions:
- Terraform and terraform-docs from HashiCorp releases
- Security scanners: tfsec, terrascan, Checkov (in Python venv)
- Linting: tflint with AWS, Azure, and GCP provider plugins
- Cost analysis: Infracost
- Development: pre-commit framework via uv
- Configures tflint with all cloud provider plugins enabled

These scripts are automatically executed during the container build process and don't need to be managed separately.

## Coder Template Implementation

We've created a Terraform-based Coder template in `coder-template/main.tf` that automatically provisions workspaces with this dev container.

### How It Works

The template uses **Coder's envbuilder** to:

1. **Clone the devcontainer repository** from GitHub during workspace creation
2. **Build the container image** using the Dockerfile and devcontainer.json
3. **Execute library scripts** (cloud-cli-tools.sh, terraform-tools.sh) during build
4. **Install Coder agent** for connectivity
5. **Start the workspace** with all tools pre-configured

### Key Features

- **Automatic builds**: No pre-built images required; builds on-demand from source
- **Version control**: Changes to the devcontainer repo automatically propagate
- **Persistent storage**: Workspace data, bash history, and Claude config preserved
- **Resource customization**: Users can configure CPU, memory, and disk per workspace
- **Credential injection**: Environment variables for GitHub, AWS, and Terraform

## Required Environment Variables

The dev container expects these environment variables:

```bash
# GitHub
GITHUB_TOKEN

# Terraform Enterprise/Cloud
TFE_TOKEN

# AWS Credentials
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
AWS_SESSION_EXPIRATION

# Claude Code
CLAUDE_CONFIG_DIR=/home/node/.claude
CLAUDE_GITHUB_MCP_ENABLED=true

# Node.js
NODE_OPTIONS=--max-old-space-size=4096

# Timezone (optional)
TZ=Australia/Sydney
```

## Storage Requirements

- **Bash History**: Persistent volume for `/commandhistory`
- **Claude Config**: Persistent volume for `/home/node/.claude`
- **Workspace**: Bind mount for project files

## Deploying the Template to Coder

### Prerequisites

1. Coder is running and accessible (http://localhost:8080)
2. Coder CLI is installed
3. You have admin access to Coder

### Installation Steps

```bash
# 1. Install Coder CLI (if not already installed)
curl -L https://coder.com/install.sh | sh

# 2. Login to your Coder instance
coder login http://localhost:8080

# 3. Create the template
coder templates create claude-devcontainer \
  --directory ./coder-template \
  --variable namespace=coder-workspaces

# 4. Verify the template was created
coder templates list
```

### Creating a Workspace

After the template is deployed:

```bash
# Create a workspace from the CLI
coder create my-workspace --template claude-devcontainer

# Or use the Web UI:
# 1. Navigate to http://localhost:8080
# 2. Click "Workspaces" > "Create Workspace"
# 3. Select "claude-devcontainer" template
# 4. Configure parameters (CPU, memory, disk)
# 5. Click "Create"
```

### Accessing the Workspace

```bash
# SSH into the workspace
coder ssh my-workspace

# Open VS Code Web
coder open my-workspace

# Port forward services
coder port-forward my-workspace --tcp 8080:8080
```

## Setting Up Credentials

For the dev container to access cloud providers and services, configure environment variables:

### Via Coder Web UI

1. Go to Workspace Settings
2. Click "Variables"
3. Add environment variables:
   - `GITHUB_TOKEN`: Your GitHub PAT
   - `TFE_TOKEN`: Terraform Cloud token
   - `AWS_ACCESS_KEY_ID`: AWS key
   - `AWS_SECRET_ACCESS_KEY`: AWS secret
4. Restart the workspace

### Via Template Variables

Alternatively, modify the template to use Coder secrets:

```hcl
data "coder_parameter" "github_token" {
  name         = "github_token"
  display_name = "GitHub Token"
  description  = "Personal Access Token for GitHub"
  type         = "string"
  mutable      = true
  default      = ""
}

# Then reference in the container env
env {
  name  = "GITHUB_TOKEN"
  value = data.coder_parameter.github_token.value
}
```

## Critical Troubleshooting

### Envbuilder Build Failures

**Permission Denied Errors**:
- **Cause**: Restrictive security contexts (run_as_user, fsGroup)
- **Solution**: Remove pod-level and container-level `run_as_user` settings in coder-template/main.tf

**Directory Conflicts**:
- **Symptom**: `mkdir: cannot create directory '/commandhistory': File exists`
- **Cause**: Devcontainer tries to create directories already mounted as volumes
- **Solution**: Don't mount volumes where devcontainer expects to create directories (removed bash-history PVC)

**Cache/Features Directory Errors**:
- **Symptom**: `mkdir /.envbuilder/features: permission denied`
- **Cause**: Default cache directory is read-only
- **Solution**: Set `ENVBUILDER_CACHE_DIR=/workspace/.envbuilder-cache`

### RBAC Issues

If workspace creation fails with permissions errors:

```bash
# Grant Coder service account admin permissions in workspace namespace
./fix-rbac.sh

# Manual equivalent:
kubectl create rolebinding coder-workspace-admin \
  --clusterrole=admin \
  --serviceaccount=coder:coder \
  --namespace=coder-workspaces
```

### PVC Binding Deadlock

Docker Desktop uses `WaitForFirstConsumer` volume binding mode. Without `wait_until_bound = false`:
1. Terraform waits for PVC to bind
2. PVC waits for pod to be scheduled
3. Pod creation waits for PVC to bind
4. **Deadlock** → 5-minute timeout

**Solution**: Always set `wait_until_bound = false` on PVCs in coder-template/main.tf.

### Agent Connectivity Issues

**Symptom**: Workspace shows "healthy: false", agent cannot connect, logs show:
```
curl: (7) Failed to connect to localhost port 8080
error: failed to download coder agent
```

**Cause**: `CODER_ACCESS_URL` set to `http://localhost:8080` doesn't work from inside Kubernetes pods.

**Solution**: Set `CODER_ACCESS_URL` to an address reachable from workspace pods when deploying:
```bash
CODER_ACCESS_URL=http://<reachable-coder-address> ./deploy.sh
```

Use `kubectl port-forward --namespace coder service/coder 8080:80` for local browser access.

### Template Modification Guidelines

**Adding Environment Variables**:
```hcl
env {
  name  = "MY_VAR"
  value = "my_value"
}
```

**Changing Resource Limits**:
```hcl
data "coder_parameter" "cpu" {
  validation {
    min = 1
    max = 16  # Increase max CPU
  }
}
```

**Adding Persistent Volumes**:
1. Create PVC resource with `wait_until_bound = false`
2. Add volume reference to pod spec
3. Add volume_mount to container spec
4. Ensure mount path doesn't conflict with devcontainer

### Development Workflow

Iterating on template changes:

```bash
# 1. Modify coder-template/main.tf
# 2. Push updated template
coder templates push claude-devcontainer --directory ./coder-template --yes

# 3. Delete existing workspace (if testing)
coder rm test-workspace --orphan --yes
kubectl delete pod,pvc -n coder-workspaces -l app.kubernetes.io/owner={username}

# 4. Create fresh workspace
coder create test-workspace --template claude-devcontainer --yes

# 5. Monitor build
kubectl logs -n coder-workspaces <pod-name> -f
```

## Known Limitations

1. **Cloud CLI Tools**: AWS, Azure, and GCP CLIs not installed (skipped for faster builds)
2. **Docker-in-Docker**: Not available (Docker socket mount incompatible with Docker Desktop K8s)
3. **Resource Constraints**: Limited by Docker Desktop VM resources
4. **Persistence**: Data deleted when workspace is destroyed
5. **Networking**: LoadBalancer only works on localhost
6. **Build Time**: First workspace creation takes 2-3 minutes (reduced by skipping cloud CLIs)

## References

- [Source Repository](https://github.com/srlynch1/claude-devcontainer-no-cloud) - Modified devcontainer without cloud CLIs
- [Original Repository](https://github.com/panchal-ravi/ai-iac-consumer-template) - Original devcontainer with cloud CLIs
- [Devcontainer JSON](https://github.com/srlynch1/claude-devcontainer-no-cloud/blob/main/.devcontainer/devcontainer.json)
- [Dockerfile](https://github.com/srlynch1/claude-devcontainer-no-cloud/blob/main/.devcontainer/Dockerfile)
- [Coder Templates Documentation](https://coder.com/docs/templates)
- [Coder Envbuilder](https://github.com/coder/envbuilder)
