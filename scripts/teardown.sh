#!/bin/bash
# =============================================================================
# Dynamic CI/CD Pipeline - Teardown Script
# =============================================================================
# Removes all deployed resources from the Kubernetes cluster.
#
# Usage:
#   chmod +x scripts/teardown.sh
#   ./scripts/teardown.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo -e "${CYAN}=== Dynamic CI/CD Pipeline - Teardown ===${NC}"
echo ""

echo -e "${YELLOW}WARNING: This will remove ALL pipeline infrastructure!${NC}"
read -p "Are you sure? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""

# Step 1: Uninstall Jenkins Helm release
echo -e "${CYAN}Step 1: Uninstalling Jenkins...${NC}"
helm uninstall jenkins -n jenkins 2>/dev/null || echo "  Jenkins not found (skipped)"

# Step 2: Delete application deployments
echo -e "${CYAN}Step 2: Removing application deployments...${NC}"
kubectl delete -f "${PROJECT_DIR}/k8s/app/production/" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "${PROJECT_DIR}/k8s/app/staging/" --ignore-not-found=true 2>/dev/null || true

# Step 3: Delete DevOps tools
echo -e "${CYAN}Step 3: Removing SonarQube and Nexus...${NC}"
kubectl delete -f "${PROJECT_DIR}/k8s/sonarqube/" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "${PROJECT_DIR}/k8s/nexus/" --ignore-not-found=true 2>/dev/null || true
kubectl delete -f "${PROJECT_DIR}/k8s/trivy/" --ignore-not-found=true 2>/dev/null || true

# Step 4: Delete RBAC
echo -e "${CYAN}Step 4: Removing RBAC configuration...${NC}"
kubectl delete -f "${PROJECT_DIR}/k8s/rbac/" --ignore-not-found=true 2>/dev/null || true

# Step 5: Delete PVCs
echo -e "${CYAN}Step 5: Removing Persistent Volume Claims...${NC}"
kubectl delete pvc --all -n jenkins 2>/dev/null || true
kubectl delete pvc --all -n devops-tools 2>/dev/null || true

# Step 6: Delete namespaces
echo -e "${CYAN}Step 6: Removing namespaces...${NC}"
kubectl delete namespace production --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace staging --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace devops-tools --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace jenkins --ignore-not-found=true 2>/dev/null || true

echo ""
echo -e "${GREEN}Teardown complete! All resources removed.${NC}"
echo ""
