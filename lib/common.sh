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

# Check if running on Docker Desktop Kubernetes
check_docker_desktop_context() {
    local CURRENT_CONTEXT=$(kubectl config current-context)
    if [ "$CURRENT_CONTEXT" != "docker-desktop" ]; then
        print_warning "Current context is '$CURRENT_CONTEXT', not 'docker-desktop'"
        print_warning "Switching to docker-desktop context..."
        kubectl config use-context docker-desktop
    fi
}

# Check Kubernetes connectivity
check_kubernetes() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Error: Cannot connect to Kubernetes cluster"
        print_error "Please ensure Docker Desktop Kubernetes is enabled and running"
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
