#!/bin/bash

# Coder Deployment Script for Docker Desktop or Rancher Desktop Kubernetes
# This script automates the deployment of Coder on local Kubernetes

set -e  # Exit on error

# Source common functions
source "$(dirname "$0")/lib/common.sh"

print_header "Coder Deployment for Local Kubernetes"

check_prerequisites
check_desktop_kubernetes_context
check_kubernetes

CODER_URL="${CODER_URL:-http://localhost:8080}"
CODER_ACCESS_URL="${CODER_ACCESS_URL:-$CODER_URL}"
CODER_WILDCARD_ACCESS_URL="${CODER_WILDCARD_ACCESS_URL:-*.localhost:8080}"

if [[ "$CODER_ACCESS_URL" == *"localhost"* ]] || [[ "$CODER_ACCESS_URL" == *"127.0.0.1"* ]]; then
    print_warning "CODER_ACCESS_URL is local-only; set it to an address reachable from workspace pods before creating workspaces"
fi

# Step 1: Create namespace
print_step "Step 1: Creating namespace 'coder'..."
if kubectl get namespace coder &> /dev/null; then
    print_warning "Namespace 'coder' already exists"
else
    kubectl create namespace coder
    print_success "Namespace 'coder' created"
fi
echo ""

# Step 2: Deploy PostgreSQL
print_step "Step 2: Deploying PostgreSQL database..."
if helm list -n coder | grep -q postgresql; then
    print_warning "PostgreSQL is already deployed"
else
    print_warning "Adding Bitnami Helm repository..."
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update

    print_warning "Installing PostgreSQL..."
    helm install postgresql bitnami/postgresql \
      --namespace coder \
      --set auth.username=coder \
      --set auth.password=coder \
      --set auth.database=coder \
      --set primary.persistence.size=10Gi

    print_success "PostgreSQL deployed"
    print_warning "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql -n coder --timeout=180s
fi
echo ""

# Step 3: Create database URL secret
print_step "Step 3: Creating database connection secret..."
if kubectl get secret coder-db-url -n coder &> /dev/null; then
    print_warning "Secret 'coder-db-url' already exists"
else
    kubectl create secret generic coder-db-url -n coder \
      --from-literal=url="postgres://coder:coder@postgresql:5432/coder?sslmode=disable"
    print_success "Database secret created"
fi
echo ""

# Step 4: Deploy Coder using Helm
print_step "Step 4: Deploying Coder..."
if helm list -n coder | grep -q "^coder"; then
    print_warning "Coder is already deployed. Upgrading..."
    helm repo add coder-v2 https://helm.coder.com/v2
    helm repo update
    helm upgrade coder coder-v2/coder \
      --namespace coder \
      -f values.yaml \
      --set-string "coder.env[1].value=$CODER_ACCESS_URL" \
      --set-string "coder.env[2].value=$CODER_WILDCARD_ACCESS_URL"
    print_success "Coder upgraded"
else
    print_warning "Adding Coder Helm repository..."
    helm repo add coder-v2 https://helm.coder.com/v2
    helm repo update

    print_warning "Installing Coder..."
    helm install coder coder-v2/coder \
      --namespace coder \
      -f values.yaml \
      --set-string "coder.env[1].value=$CODER_ACCESS_URL" \
      --set-string "coder.env[2].value=$CODER_WILDCARD_ACCESS_URL"

    print_success "Coder deployed"
fi
echo ""

# Step 5: Wait for Coder to be ready
print_step "Step 5: Waiting for Coder to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=coder -n coder --timeout=300s
print_success "Coder is ready!\n"

# Step 6: Display access information
print_header "Deployment Complete!"

print_success "Coder is now running on your local Kubernetes cluster\n"

print_warning "Service Information:"
kubectl get svc -n coder

echo ""
print_warning "Pod Status:"
kubectl get pods -n coder

echo ""
print_warning "To access Coder locally, run this in another terminal:"
echo "  kubectl port-forward --namespace coder service/coder 8080:80"
print_success "Then open: ${BLUE}${CODER_URL}${NC}\n"

print_warning "To view logs:"
echo "  kubectl logs -n coder -l app.kubernetes.io/name=coder -f"
echo ""

print_warning "To uninstall:"
echo "  ./cleanup.sh"
echo ""
