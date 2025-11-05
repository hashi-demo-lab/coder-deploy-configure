# Coder Deployment for Docker Desktop Kubernetes

This repository contains scripts and configuration files to deploy [Coder](https://coder.com) on Docker Desktop's built-in Kubernetes cluster for local development.

## Prerequisites

Before you begin, ensure you have the following installed and configured:

1. **Docker Desktop** with Kubernetes enabled
   - Open Docker Desktop Settings
   - Navigate to Kubernetes
   - Check "Enable Kubernetes"
   - Click "Apply & Restart"

2. **kubectl** (Kubernetes command-line tool)
   ```bash
   # Verify installation
   kubectl version --client
   ```

3. **Helm** (Kubernetes package manager, version 3.5+)
   ```bash
   # Verify installation
   helm version
   ```

## Quick Start

Deploy Coder with a single command:

```bash
./deploy.sh
```

This script will:
1. Create the `coder` namespace
2. Deploy PostgreSQL database using Bitnami Helm chart
3. Create database connection secrets
4. Install Coder using the official Helm chart
5. Wait for all components to be ready

Once deployment is complete, access Coder at: **http://localhost:8080**

## Deploying the Claude Code Dev Container Template

After Coder is running, deploy the custom Claude Code dev container template:

```bash
./deploy-template.sh
```

This will:
1. Install Coder CLI (if not already installed)
2. Login to your Coder instance
3. Create the workspace namespace in Kubernetes
4. Deploy the Claude Code dev container template

The template provides workspaces with:
- Claude Code CLI pre-installed
- Terraform 1.13.4 with full ecosystem tools
- Cloud CLIs (AWS, Azure, GCP)
- Docker-in-Docker support
- VS Code extensions for infrastructure-as-code
- Persistent storage for workspace data and configuration

See [claude.md](claude.md) for detailed documentation about the dev container.

## Creating Workspaces with Terraform

After deploying the template, you can provision workspaces using Terraform:

```bash
cd workspace-provisioning

# Copy and configure your workspace settings
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your desired configuration

# Initialize and apply
terraform init
terraform apply
```

This allows you to:
- Manage workspaces as code
- Version control workspace configurations
- Automate workspace provisioning
- Configure resources (CPU, memory, disk)
- Set auto-start/stop schedules

See [workspace-provisioning/README.md](workspace-provisioning/README.md) for detailed instructions.

## What's Deployed

### Components

- **Coder**: The main Coder control plane
- **PostgreSQL**: Database for storing Coder data (deployed in-cluster for local development)

### Kubernetes Resources

- Namespace: `coder`
- Helm Releases: `coder`, `postgresql`
- Services: LoadBalancer service for Coder (accessible on localhost)
- Secrets: Database connection string
- PersistentVolumeClaims: 10Gi for PostgreSQL data

## Configuration

The deployment is configured via `values.yaml`. Key settings include:

- **Access URL**: `http://localhost:8080`
- **Database**: PostgreSQL (user: `coder`, password: `coder`, database: `coder`)
- **Resources**:
  - Requests: 250m CPU, 512Mi memory
  - Limits: 1000m CPU, 2Gi memory
- **Replicas**: 1 (suitable for local development)

### Customizing the Deployment

Edit `values.yaml` to customize:
- Resource limits
- Access URLs
- Additional environment variables
- Service configuration

After modifying `values.yaml`, redeploy:

```bash
./deploy.sh
```

The script will upgrade the existing deployment with new values.

## Usage

### Accessing Coder

After deployment, open your browser and navigate to:

```
http://localhost:8080
```

You'll be prompted to create an initial admin account.

### Viewing Logs

To view Coder logs:

```bash
kubectl logs -n coder -l app.kubernetes.io/name=coder -f
```

To view PostgreSQL logs:

```bash
kubectl logs -n coder -l app.kubernetes.io/name=postgresql -f
```

### Checking Status

View all pods in the coder namespace:

```bash
kubectl get pods -n coder
```

View services:

```bash
kubectl get svc -n coder
```

View Helm releases:

```bash
helm list -n coder
```

## Cleanup

To completely remove Coder and all its components:

```bash
./cleanup.sh
```

This will:
- Uninstall Coder
- Uninstall PostgreSQL
- Delete all persistent volume claims (including data)
- Delete the `coder` namespace

**Warning**: This will delete all Coder data including workspaces, users, and templates.

## Troubleshooting

### Pods not starting

Check pod status and events:

```bash
kubectl describe pod -n coder <pod-name>
```

### Cannot access Coder at localhost:8080

1. Verify the LoadBalancer service is running:
   ```bash
   kubectl get svc -n coder
   ```

2. Check if port 8080 is available on your system:
   ```bash
   lsof -i :8080
   ```

3. Ensure Coder pod is running:
   ```bash
   kubectl get pods -n coder
   ```

### Database connection issues

Verify the database secret exists:

```bash
kubectl get secret coder-db-url -n coder
```

Check PostgreSQL is running:

```bash
kubectl get pods -n coder -l app.kubernetes.io/name=postgresql
```

### Context issues

Ensure you're using the docker-desktop context:

```bash
kubectl config current-context
```

If not, switch to it:

```bash
kubectl config use-context docker-desktop
```

## File Structure

```
.
├── README.md                    # This file
├── claude.md                    # Claude Code dev container documentation
├── values.yaml                  # Helm values for Coder configuration
├── deploy.sh                    # Coder deployment script
├── cleanup.sh                   # Coder cleanup/uninstall script
├── deploy-template.sh           # Template deployment script
├── coder-template/              # Coder workspace template (defines what's in workspaces)
│   ├── README.md                # Template documentation
│   ├── main.tf                  # Terraform template definition
│   └── .terraform.lock.hcl      # Provider version lock file
└── workspace-provisioning/      # Workspace creation with Terraform (creates workspaces)
    ├── README.md                # Workspace provisioning guide
    ├── main.tf                  # Workspace resource definition
    ├── variables.tf             # Configurable parameters
    ├── terraform.tfvars.example # Example configuration
    └── .gitignore               # Git ignore rules
```

## Resources

- [Coder Documentation](https://coder.com/docs)
- [Coder Kubernetes Installation Guide](https://coder.com/docs/install/kubernetes)
- [Coder Helm Chart](https://github.com/coder/coder/tree/main/helm)
- [Docker Desktop Kubernetes](https://docs.docker.com/desktop/kubernetes/)

## Notes

- This setup uses an in-cluster PostgreSQL database suitable for local development and testing
- For production deployments, use a managed PostgreSQL service
- The deployment uses a LoadBalancer service type which Docker Desktop exposes on localhost
- All data is stored in Kubernetes persistent volumes managed by Docker Desktop

## License

This repository is provided as-is for deploying Coder. See [Coder's licensing](https://github.com/coder/coder/blob/main/LICENSE) for Coder-specific terms.
