#!/bin/bash

# Common functions and variables for Coder deployment scripts

# Colors for output
export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export NC='\033[0m' # No Color

# Print functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

# Check that the configured context is a supported local Kubernetes runtime.
check_desktop_kubernetes_context() {
    local current_context
    local target_context="${KUBERNETES_CONTEXT:-}"

    current_context=$(kubectl config current-context)
    if [ -n "$target_context" ] && [ "$current_context" != "$target_context" ]; then
        print_warning "Switching from '$current_context' to '$target_context' context..."
        kubectl config use-context "$target_context"
        current_context="$target_context"
    fi

    case "$current_context" in
        docker-desktop|rancher-desktop)
            print_success "Using Kubernetes context '$current_context'"
            ;;
        *)
            print_error "Unsupported Kubernetes context '$current_context'"
            print_error "Use Docker Desktop or Rancher Desktop, or set KUBERNETES_CONTEXT accordingly"
            exit 1
            ;;
    esac
}

# Check Kubernetes connectivity
check_kubernetes() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Error: Cannot connect to Kubernetes cluster"
        print_error "Please ensure your local Kubernetes runtime is enabled and running"
        exit 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check prerequisites
check_prerequisites() {
    print_warning "Checking prerequisites..."

    if ! command_exists kubectl; then
        print_error "Error: kubectl is not installed"
        exit 1
    fi

    if ! command_exists helm; then
        print_error "Error: helm is not installed"
        exit 1
    fi

    print_success "Prerequisites check passed!\n"
}
