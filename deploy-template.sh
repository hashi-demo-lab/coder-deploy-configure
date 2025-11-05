#!/bin/bash

# Coder Template Deployment Script
# Deploys the Claude Code dev container template to Coder

set -e

# Source common functions
source "$(dirname "$0")/lib/common.sh"

print_header "Coder Template Deployment"

# Configuration
CODER_URL="${CODER_URL:-http://localhost:8080}"
TEMPLATE_NAME="${TEMPLATE_NAME:-claude-devcontainer}"
TEMPLATE_DIR="./coder-template"
NAMESPACE="${NAMESPACE:-coder-workspaces}"

print_warning "Configuration:"
echo "  Coder URL: ${CODER_URL}"
echo "  Template Name: ${TEMPLATE_NAME}"
echo "  Template Directory: ${TEMPLATE_DIR}"
echo "  Workspace Namespace: ${NAMESPACE}"
echo ""

# Check if Coder CLI is installed
if ! command -v coder &> /dev/null; then
    print_warning "Coder CLI not found. Installing..."
    curl -fsSL https://coder.com/install.sh | sh

    # Add to PATH if needed
    if ! command -v coder &> /dev/null; then
        print_warning "Adding Coder CLI to PATH..."
        export PATH="$HOME/.coder/bin:$PATH"
    fi

    if command -v coder &> /dev/null; then
        print_success "Coder CLI installed successfully"
    else
        print_error "Failed to install Coder CLI"
        exit 1
    fi
fi

print_success "Coder CLI version: $(coder version)\n"

# Check if template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    print_error "Error: Template directory '$TEMPLATE_DIR' not found"
    exit 1
fi

if [ ! -f "$TEMPLATE_DIR/main.tf" ]; then
    print_error "Error: main.tf not found in '$TEMPLATE_DIR'"
    exit 1
fi

print_success "Template directory found\n"

# Login to Coder
print_step "Step 1: Logging into Coder..."
print_warning "Please authenticate when prompted\n"

if ! coder login "$CODER_URL" --first-user-trial; then
    print_warning "Login failed. If Coder is already set up, trying regular login..."
    coder login "$CODER_URL"
fi

print_success "Successfully logged in to Coder\n"

# Create workspace namespace in Kubernetes
print_step "Step 2: Creating workspace namespace in Kubernetes..."
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_warning "Namespace '$NAMESPACE' already exists"
else
    kubectl create namespace "$NAMESPACE"
    print_success "Namespace '$NAMESPACE' created"
fi
echo ""

# Grant Coder RBAC permissions in workspace namespace
print_step "Step 3: Configuring RBAC permissions..."
if kubectl get rolebinding coder-workspace-admin -n "$NAMESPACE" &> /dev/null; then
    print_warning "RoleBinding 'coder-workspace-admin' already exists"
else
    print_warning "Granting Coder service account admin permissions in $NAMESPACE..."
    kubectl create rolebinding coder-workspace-admin \
      --clusterrole=admin \
      --serviceaccount=coder:coder \
      --namespace="$NAMESPACE" 2>/dev/null || print_warning "RoleBinding may already exist"
    print_success "RBAC permissions configured"
fi
echo ""

# Check if template already exists
print_step "Step 4: Checking for existing template..."
if coder templates list | grep -q "$TEMPLATE_NAME"; then
    print_warning "Template '$TEMPLATE_NAME' already exists"
    read -p "Do you want to update it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Updating template..."
        coder templates push "$TEMPLATE_NAME" \
          --directory "$TEMPLATE_DIR" \
          --variable namespace="$NAMESPACE" \
          --yes
        print_success "Template updated successfully"
    else
        print_warning "Skipping template update"
    fi
else
    print_warning "Creating new template..."
    coder templates create "$TEMPLATE_NAME" \
      --directory "$TEMPLATE_DIR" \
      --variable namespace="$NAMESPACE" \
      --yes
    print_success "Template created successfully"
fi
echo ""

# List templates
print_step "Step 5: Verifying template..."
coder templates list
echo ""

print_header "Deployment Complete!"

print_success "The '$TEMPLATE_NAME' template has been deployed to Coder\n"

print_warning "Next Steps:"
echo "1. Create a workspace:"
echo "   ${BLUE}coder create my-workspace --template $TEMPLATE_NAME${NC}"
echo ""
echo "2. Or use the Web UI:"
echo "   ${BLUE}${CODER_URL}${NC}"
echo ""
echo "3. Access your workspace:"
echo "   ${BLUE}coder ssh my-workspace${NC}"
echo "   ${BLUE}coder open my-workspace${NC}"
echo ""

print_warning "Documentation:"
echo "  - Template README: ./coder-template/README.md"
echo "  - Dev Container Docs: ./CLAUDE.md"
echo ""
