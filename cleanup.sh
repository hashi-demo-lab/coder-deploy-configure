#!/bin/bash

# Coder Cleanup Script for Docker Desktop or Rancher Desktop Kubernetes
# This script removes all Coder components from the cluster

set -e  # Exit on error

# Source common functions
source "$(dirname "$0")/lib/common.sh"

print_header "Coder Cleanup"

print_warning "This will remove:"
echo "  - Coder deployment"
echo "  - PostgreSQL database (including all data)"
echo "  - All secrets"
echo "  - The 'coder' namespace"
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Cleanup cancelled"
    exit 0
fi

echo ""

check_desktop_kubernetes_context

# Check if namespace exists
if ! kubectl get namespace coder &> /dev/null; then
    print_warning "Namespace 'coder' does not exist. Nothing to clean up."
    exit 0
fi

# Uninstall Coder
print_step "Step 1: Uninstalling Coder..."
if helm list -n coder | grep -q "^coder"; then
    helm uninstall coder -n coder
    print_success "Coder uninstalled"
else
    print_warning "Coder is not installed"
fi
echo ""

# Uninstall PostgreSQL
print_step "Step 2: Uninstalling PostgreSQL..."
if helm list -n coder | grep -q postgresql; then
    helm uninstall postgresql -n coder
    print_success "PostgreSQL uninstalled"
else
    print_warning "PostgreSQL is not installed"
fi
echo ""

# Delete PVCs (persistent data)
print_step "Step 3: Deleting persistent volume claims..."
if kubectl get pvc -n coder 2>/dev/null | grep -q .; then
    kubectl delete pvc --all -n coder
    print_success "PVCs deleted"
else
    print_warning "No PVCs found"
fi
echo ""

# Delete namespace
print_step "Step 4: Deleting namespace 'coder'..."
kubectl delete namespace coder
print_success "Namespace deleted"
echo ""

print_header "Cleanup Complete!"

print_success "All Coder components have been removed from your cluster\n"

print_warning "To redeploy Coder, run:"
echo "  ./deploy.sh"
echo ""
