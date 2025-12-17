#!/bin/bash
# ============================================================================
# ENVIRONMENT SETUP SCRIPT
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

if [ $# -ne 1 ]; then
  log_error "Usage: $0 [test|production]"
  exit 1
fi

ENVIRONMENT=$1

if [ "$ENVIRONMENT" != "test" ] && [ "$ENVIRONMENT" != "production" ]; then
  log_error "Environment must be 'test' or 'production'"
  exit 1
fi

log_info "Setting up environment: $ENVIRONMENT"

# Determine project root (assuming script is in scripts/ subdirectory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

log_info "Project root: $PROJECT_ROOT"
log_info "Ansible directory: $ANSIBLE_DIR"

# Check Ansible
if ! command -v ansible &>/dev/null; then
  log_error "Ansible is not installed"
  log_info "Install with: pip install ansible"
  exit 1
fi
log_success "Ansible is installed: $(ansible --version | head -n1)"

# Check if ansible directory exists
if [ ! -d "$ANSIBLE_DIR" ]; then
  log_error "Ansible directory not found: $ANSIBLE_DIR"
  exit 1
fi

# Install collections
log_info "Installing Ansible collections..."
if [ -f "$ANSIBLE_DIR/requirements.yml" ]; then
  ansible-galaxy collection install -r "$ANSIBLE_DIR/requirements.yml" --force
  log_success "Ansible collections installed"
else
  log_error "Requirements file not found: $ANSIBLE_DIR/requirements.yml"
  exit 1
fi

# Check inventory
INVENTORY_FILE="$ANSIBLE_DIR/inventories/$ENVIRONMENT/hosts"
if [ ! -f "$INVENTORY_FILE" ]; then
  log_error "Inventory file not found: $INVENTORY_FILE"
  exit 1
fi
log_success "Inventory file exists: $INVENTORY_FILE"

# Test SSH connectivity
log_info "Testing SSH connectivity..."
FIRST_HOST=$(ansible swarm_managers[0] -i "$INVENTORY_FILE" --list-hosts 2>/dev/null | tail -n1 | xargs)

if [ -z "$FIRST_HOST" ]; then
  log_warning "No hosts found in inventory"
else
  log_info "Testing connection to: $FIRST_HOST"
  if ansible swarm_managers[0] -i "$INVENTORY_FILE" -m ping &>/dev/null; then
    log_success "SSH connectivity OK"
  else
    log_warning "SSH connectivity test failed"
    log_info "Tip: Check SSH keys and ansible_host in inventory"
  fi
fi

# Check Docker Swarm
if [ -n "$FIRST_HOST" ]; then
  SWARM_STATUS=$(ansible swarm_managers[0] -i "$INVENTORY_FILE" -m shell -a "docker info --format '{{.Swarm.LocalNodeState}}'" 2>/dev/null | grep -v "CHANGED" | tail -n1 || echo "unknown")

  if [ "$SWARM_STATUS" = "active" ]; then
    log_success "Docker Swarm is active"
  else
    log_warning "Docker Swarm status: $SWARM_STATUS"
  fi
fi

# Check secrets
if [ -n "$FIRST_HOST" ]; then
  SECRETS=$(ansible swarm_managers[0] -i "$INVENTORY_FILE" -m shell -a "docker secret ls --format '{{.Name}}'" 2>/dev/null | grep -v "CHANGED" || echo "")

  REQUIRED_SECRETS=(
    "postgres_user"
    "postgres_password_product"
    "redis_product_password"
    "s3_access_key"
    "s3_secret_key"
  )

  MISSING_SECRETS=()

  for secret in "${REQUIRED_SECRETS[@]}"; do
    if ! echo "$SECRETS" | grep -q "^$secret$"; then
      MISSING_SECRETS+=("$secret")
    fi
  done

  if [ ${#MISSING_SECRETS[@]} -gt 0 ]; then
    log_warning "Missing Docker secrets:"
    for secret in "${MISSING_SECRETS[@]}"; do
      log_warning "  - $secret"
    done
  else
    log_success "All required Docker secrets are present"
  fi
fi

echo ""
log_info "================================================"
log_info "SETUP VERIFICATION COMPLETED"
log_info "================================================"
log_info "Environment: $ENVIRONMENT"
log_info ""
log_info "Next steps:"
log_info "  1. Create Docker secrets on Swarm manager (see EXAMPLES.txt)"
log_info "  2. cd $ANSIBLE_DIR"
log_info "  3. Test deployment: ansible-playbook deploy.yml -i inventories/$ENVIRONMENT --check"
log_info "  4. Deploy: ansible-playbook deploy.yml -i inventories/$ENVIRONMENT"
log_info "================================================"
