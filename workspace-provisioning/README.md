# Coder Workspace Provisioning with Terraform

This directory contains Terraform configuration to provision Coder workspaces from the `claude-devcontainer` template.

## Overview

Instead of manually creating workspaces through the Coder UI or CLI, you can use Terraform to:
- Provision workspaces as code
- Version control workspace configurations
- Automate workspace creation for teams
- Integrate workspace provisioning into CI/CD pipelines

## Prerequisites

1. **Coder is deployed and running**: See parent directory for deployment instructions
2. **Template is installed**: The `claude-devcontainer` template must be deployed
3. **Terraform CLI**: Version 1.0 or later
4. **Coder authentication**: You must be logged in to Coder

## Quick Start

### 1. Authenticate with Coder

First, log in to Coder to get your session token:

```bash
coder login http://localhost:8080
```

Your session token is stored in `~/.config/coder/session` and will be used by the Terraform provider.

### 2. Configure Your Workspace

Copy the example configuration:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to customize your workspace:

```hcl
workspace_name = "my-dev-workspace"
cpu_cores      = 4
memory_gb      = 8
disk_size_gb   = 20
git_repo_url   = "https://github.com/your-org/your-project.git"
```

### 3. Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Create the workspace
terraform apply
```

### 4. Access Your Workspace

After creation, Terraform outputs the workspace URL:

```bash
terraform output workspace_url
```

Open this URL in your browser or use the Coder CLI:

```bash
coder ssh $(terraform output -raw workspace_name)
```

## Configuration Options

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `workspace_name` | Unique name for the workspace | `"john-dev-env"` |

### Optional Variables

| Variable | Description | Default | Range |
|----------|-------------|---------|-------|
| `coder_url` | Coder deployment URL | `"http://localhost:8080"` | - |
| `coder_organization` | Coder organization | `"coder"` | - |
| `kubernetes_namespace` | K8s namespace | `"coder-workspaces"` | - |
| `cpu_cores` | CPU cores | `2` | 1-8 |
| `memory_gb` | Memory in GB | `4` | 2-16 |
| `disk_size_gb` | Disk size in GB | `10` | 10-100 |
| `git_repo_url` | Git repo to clone | `""` | - |
| `autostart_schedule` | Cron schedule for auto-start | `""` | Cron format |
| `ttl_hours` | Auto-stop after N hours | `8` | 0-168 |

## Examples

### Basic Workspace

```hcl
workspace_name = "basic-workspace"
```

### High-Performance Workspace

```hcl
workspace_name = "ml-workspace"
cpu_cores      = 8
memory_gb      = 16
disk_size_gb   = 50
ttl_hours      = 24
```

### Team Workspace with Git Repo

```hcl
workspace_name = "team-infra-project"
cpu_cores      = 4
memory_gb      = 8
git_repo_url   = "https://github.com/company/infra-repo.git"
```

### Scheduled Workspace

```hcl
workspace_name       = "scheduled-workspace"
autostart_schedule   = "0 9 * * MON-FRI"  # 9 AM weekdays
ttl_hours           = 10                   # Stop at 7 PM
```

## Managing Workspaces

### Update Workspace Configuration

Modify `terraform.tfvars` and run:

```bash
terraform apply
```

**Note**: Some changes (like CPU/memory) may require workspace restart.

### Stop Workspace

To stop without deleting:

```bash
coder stop $(terraform output -raw workspace_name)
```

### Start Workspace

```bash
coder start $(terraform output -raw workspace_name)
```

### Delete Workspace

```bash
terraform destroy
```

**Warning**: This deletes all workspace data. Persistent volumes are removed.

## Advanced Usage

### Multiple Workspaces

To manage multiple workspaces, create separate directories or use Terraform workspaces:

```bash
# Create separate directories
mkdir -p workspaces/dev workspaces/staging workspaces/prod
cp -r . workspaces/dev/

# Or use Terraform workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace select dev
terraform apply -var="workspace_name=dev-workspace"
```

### Environment Variables

Instead of `terraform.tfvars`, use environment variables:

```bash
export TF_VAR_workspace_name="my-workspace"
export TF_VAR_cpu_cores=4
export TF_VAR_memory_gb=8
terraform apply
```

### CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Provision Coder Workspace

on:
  push:
    branches: [main]

jobs:
  provision:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        working-directory: workspace-provisioning
        run: terraform init

      - name: Terraform Apply
        working-directory: workspace-provisioning
        env:
          CODER_URL: ${{ secrets.CODER_URL }}
          CODER_SESSION_TOKEN: ${{ secrets.CODER_SESSION_TOKEN }}
        run: |
          terraform apply -auto-approve \
            -var="workspace_name=${{ github.actor }}-workspace"
```

## Troubleshooting

### Authentication Errors

If you get authentication errors:

```bash
# Re-login to Coder
coder login http://localhost:8080

# Verify session
coder whoami
```

### Template Not Found

Ensure the template is deployed:

```bash
coder templates list
```

You should see `claude-devcontainer` in the list.

### Workspace Creation Timeout

Large workspaces or first-time builds can take 5-10 minutes. Increase Terraform timeout:

```hcl
resource "coder_workspace" "dev" {
  # ... other config ...

  timeouts {
    create = "20m"
    update = "20m"
  }
}
```

### Kubernetes Resource Limits

If workspace fails to start, check Kubernetes resources:

```bash
kubectl get pods -n coder-workspaces
kubectl describe pod <workspace-pod> -n coder-workspaces
```

## State Management

### Local State (Default)

By default, Terraform stores state in `terraform.tfstate` locally.

**Important**: Don't commit this file to Git (it contains sensitive data).

### Remote State (Recommended for Teams)

Configure remote state for team collaboration:

```hcl
terraform {
  backend "s3" {
    bucket = "company-terraform-state"
    key    = "coder/workspaces/workspace-name/terraform.tfstate"
    region = "us-east-1"
  }
}
```

Or use Terraform Cloud:

```hcl
terraform {
  cloud {
    organization = "your-org"
    workspaces {
      name = "coder-workspace-provisioning"
    }
  }
}
```

## Outputs

After applying, the following outputs are available:

```bash
# Get workspace URL
terraform output workspace_url

# Get workspace ID
terraform output workspace_id

# Get workspace status
terraform output workspace_status
```

## Best Practices

1. **Use Remote State**: For team environments, always use remote state
2. **Version Control**: Commit `terraform.tfvars` (without secrets) to Git
3. **Naming Convention**: Use consistent workspace names (e.g., `{user}-{project}-{env}`)
4. **Resource Limits**: Start small and scale up as needed
5. **Auto-stop**: Configure TTL to save resources
6. **Documentation**: Document custom configurations in comments

## Resources

- [Coder Terraform Provider](https://registry.terraform.io/providers/coder/coder/latest/docs)
- [Coder Documentation](https://coder.com/docs)
- [Parent Directory](../README.md): Coder deployment instructions
- [Template Directory](../coder-template/): Template source code
