# Coder Template: Claude Code Dev Container

This Coder template automatically provisions workspaces using the custom Claude Code dev container from [ai-iac-consumer-template](https://github.com/panchal-ravi/ai-iac-consumer-template).

## Features

- **Automated Container Build**: Uses Coder's envbuilder to build the devcontainer from the GitHub repository
- **Persistent Storage**: Workspace data, bash history, and Claude config are preserved across workspace restarts
- **Docker-in-Docker**: Full Docker support within the workspace
- **Pre-configured Tools**:
  - Terraform 1.13.4 with ecosystem tools (tflint, tfsec, etc.)
  - Claude Code CLI
  - AWS, Azure, GCP CLIs
  - VS Code extensions (Terraform, HCL, Claude Code, etc.)
- **Customizable Resources**: Configure CPU, memory, and disk size per workspace

## Prerequisites

1. Coder instance running on Kubernetes
2. Coder CLI installed locally
3. Access to create templates in Coder

## Template Parameters

When creating a workspace from this template, users can configure:

- **Kubernetes Namespace**: Where to deploy the workspace (default: `coder-workspaces`)
- **CPU Cores**: 1-8 cores (default: 2)
- **Memory**: 2-16 GB (default: 4 GB)
- **Disk Size**: 10-100 GB (default: 10 GB)
- **Git Repository URL**: Optional repository to clone into workspace

## Environment Variables

The template supports these environment variables for credentials (set via Coder secrets or workspace parameters):

- `GITHUB_TOKEN`: GitHub personal access token
- `TFE_TOKEN`: Terraform Cloud/Enterprise token
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_SESSION_TOKEN`: AWS session token (optional)
- `AWS_SESSION_EXPIRATION`: AWS session expiration (optional)

## Installing the Template

### Option 1: Using Coder CLI

```bash
# Login to your Coder instance
coder login http://localhost:8080

# Create the template
coder templates create claude-code-devcontainer \
  --directory ./coder-template \
  --var namespace=coder-workspaces
```

### Option 2: Using the Coder Web UI

1. Navigate to Templates in your Coder instance
2. Click "Create Template"
3. Upload or paste the `main.tf` file
4. Configure template variables
5. Save and publish

## Creating a Workspace

Once the template is installed:

1. Go to Workspaces in Coder
2. Click "Create Workspace"
3. Select the "Claude Code Dev Container" template
4. Configure workspace parameters (CPU, memory, disk, etc.)
5. Click "Create"

The workspace will:
1. Clone the devcontainer repository
2. Build the container image using envbuilder
3. Start the workspace with all tools pre-installed
4. Mount persistent volumes for data persistence

## Accessing the Workspace

After the workspace starts, you can access it via:

- **VS Code Web**: Built-in web-based VS Code
- **Terminal**: Direct terminal access via web browser
- **SSH**: Connect via `coder ssh <workspace-name>`
- **VS Code Desktop**: Connect via Coder's VS Code extension

## Persistent Data

Data is preserved in these locations:

- `/workspace`: Main workspace directory (PVC-backed)
- `/commandhistory`: Bash history (PVC-backed)
- `/home/node/.claude`: Claude Code configuration (PVC-backed)

## Customizing the Template

### Changing the Dev Container Source

Edit the `ENVBUILDER_GIT_URL` in `main.tf` to use a different repository:

```hcl
ENVBUILDER_GIT_URL=https://github.com/your-org/your-repo
```

### Adding Environment Variables

Add new `env` blocks in the `container` section:

```hcl
env {
  name  = "YOUR_VAR"
  value = "your_value"
}
```

### Modifying Resource Limits

Adjust the validation ranges in the parameter blocks:

```hcl
validation {
  min = 4
  max = 32
}
```

## Troubleshooting

### Workspace fails to start

Check the pod logs:
```bash
kubectl logs -n coder-workspaces <pod-name>
```

### Container build fails

Verify the devcontainer repository is accessible:
```bash
git clone https://github.com/panchal-ravi/ai-iac-consumer-template
```

### Docker-in-Docker not working

Ensure the Kubernetes cluster allows privileged containers:
```bash
kubectl auth can-i create pods/privileged
```

### Missing credentials

Set environment variables via Coder:
1. Go to Workspace Settings
2. Add environment variables
3. Restart the workspace

## Architecture

```
┌─────────────────────────────────────────┐
│         Coder Control Plane             │
│         (Kubernetes)                    │
└─────────────────┬───────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────┐
│      Workspace Pod (Kubernetes)         │
│  ┌───────────────────────────────────┐  │
│  │  Envbuilder Container             │  │
│  │  - Builds devcontainer            │  │
│  │  - Installs Coder agent           │  │
│  │  - Runs dev environment           │  │
│  └───────────────────────────────────┘  │
│                                          │
│  Volumes:                                │
│  - /workspace (PVC)                      │
│  - /commandhistory (PVC)                 │
│  - /home/node/.claude (PVC)              │
│  - /var/run/docker.sock (host)           │
└─────────────────────────────────────────┘
```

## References

- [Coder Templates Documentation](https://coder.com/docs/templates)
- [Envbuilder](https://github.com/coder/envbuilder)
- [Source Dev Container](https://github.com/panchal-ravi/ai-iac-consumer-template)
