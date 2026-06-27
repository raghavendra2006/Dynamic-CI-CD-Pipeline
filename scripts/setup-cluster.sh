#!/bin/bash
# =============================================================================
# Dynamic CI/CD Pipeline - Cluster Setup Script
# =============================================================================
# This script automates the complete setup of the CI/CD pipeline infrastructure
# on a Kubernetes cluster. It creates namespaces, applies RBAC, deploys
# supporting services (SonarQube, Nexus), and installs Jenkins via Helm.
#
# Prerequisites:
#   - kubectl configured and connected to a Kubernetes cluster
#   - Helm 3.x installed
#   - Docker installed (for local image building)
#
# Usage:
#   chmod +x scripts/setup-cluster.sh
#   ./scripts/setup-cluster.sh
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JENKINS_NAMESPACE="jenkins"
DEVOPS_NAMESPACE="devops-tools"
STAGING_NAMESPACE="staging"
PRODUCTION_NAMESPACE="production"

# Helper functions
log_info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $1"; }
log_header()  { echo -e "\n${CYAN}═══════════════════════════════════════════════${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}═══════════════════════════════════════════════${NC}\n"; }

# Check prerequisites
check_prerequisites() {
    log_header "Checking Prerequisites"

    local missing=0

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        missing=1
    else
        log_success "kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client -o yaml | grep gitVersion | head -1)"
    fi

    if ! command -v helm &> /dev/null; then
        log_error "Helm is not installed"
        missing=1
    else
        log_success "Helm found: $(helm version --short)"
    fi

    if ! command -v docker &> /dev/null; then
        log_warn "Docker is not installed (optional for local builds)"
    else
        log_success "Docker found: $(docker --version)"
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        missing=1
    else
        log_success "Connected to Kubernetes cluster"
    fi

    if [ $missing -eq 1 ]; then
        log_error "Missing prerequisites. Please install the required tools and try again."
        exit 1
    fi
}

# Step 1: Create Namespaces
create_namespaces() {
    log_header "Step 1: Creating Namespaces"

    kubectl apply -f "${PROJECT_DIR}/k8s/namespace.yaml"

    log_success "Namespaces created: ${JENKINS_NAMESPACE}, ${DEVOPS_NAMESPACE}, ${STAGING_NAMESPACE}, ${PRODUCTION_NAMESPACE}"
}

# Step 2: Apply RBAC
apply_rbac() {
    log_header "Step 2: Applying RBAC Configuration"

    kubectl apply -f "${PROJECT_DIR}/k8s/rbac/jenkins-sa.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/rbac/jenkins-role.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/rbac/jenkins-rolebinding.yaml"

    log_success "RBAC configured: ServiceAccount, Roles, and namespaced RoleBindings"
}

# Step 3: Deploy SonarQube
deploy_sonarqube() {
    log_header "Step 3: Deploying SonarQube"

    kubectl apply -f "${PROJECT_DIR}/k8s/sonarqube/sonarqube-pvc.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/sonarqube/sonarqube-deployment.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/sonarqube/sonarqube-service.yaml"

    log_info "Waiting for SonarQube to be ready (this may take 2-3 minutes)..."
    kubectl rollout status deployment/sonarqube -n ${DEVOPS_NAMESPACE} --timeout=300s || \
        log_warn "SonarQube rollout did not complete in time. Check: kubectl get pods -n ${DEVOPS_NAMESPACE}"

    log_success "SonarQube deployed (accessible at NodePort 30900)"
}

# Step 4: Deploy Nexus
deploy_nexus() {
    log_header "Step 4: Deploying Nexus Repository Manager"

    kubectl apply -f "${PROJECT_DIR}/k8s/nexus/nexus-pvc.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/nexus/nexus-deployment.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/nexus/nexus-service.yaml"

    log_info "Waiting for Nexus to be ready (this may take 3-5 minutes)..."
    kubectl rollout status deployment/nexus -n ${DEVOPS_NAMESPACE} --timeout=600s || \
        log_warn "Nexus rollout did not complete in time. Check: kubectl get pods -n ${DEVOPS_NAMESPACE}"

    log_success "Nexus deployed (Web UI: NodePort 30081, Docker Registry: NodePort 30082)"
    log_info "Default Nexus admin password: kubectl exec -n ${DEVOPS_NAMESPACE} \$(kubectl get pod -l app=nexus -n ${DEVOPS_NAMESPACE} -o jsonpath='{.items[0].metadata.name}') -- cat /nexus-data/admin.password"
}

# Step 5: Deploy Trivy Configuration
deploy_trivy_config() {
    log_header "Step 5: Deploying Trivy Configuration"

    kubectl apply -f "${PROJECT_DIR}/k8s/trivy/trivy-config.yaml"

    log_success "Trivy configuration deployed"
}

# Step 6: Deploy Application Manifests
deploy_app_manifests() {
    log_header "Step 6: Deploying Application Manifests (Staging & Production)"

    # Staging
    kubectl apply -f "${PROJECT_DIR}/k8s/app/staging/deployment.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/app/staging/service.yaml"

    # Production (Blue-Green)
    kubectl apply -f "${PROJECT_DIR}/k8s/app/production/deployment-blue.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/app/production/deployment-green.yaml"
    kubectl apply -f "${PROJECT_DIR}/k8s/app/production/service.yaml"

    log_success "Staging and Production manifests deployed"
    log_info "Staging:    NodePort 30180"
    log_info "Production: NodePort 30280"
}

# Step 7: Install Jenkins via Helm
install_jenkins() {
    log_header "Step 7: Installing Jenkins via Helm"

    # Add Jenkins Helm repository
    helm repo add jenkinsci https://charts.jenkins.io
    helm repo update

    # Install Jenkins with custom values
    helm upgrade --install jenkins jenkinsci/jenkins \
        --namespace ${JENKINS_NAMESPACE} \
        --values "${PROJECT_DIR}/helm/jenkins/values.yaml" \
        --wait \
        --timeout 600s

    log_success "Jenkins installed via Helm"

    # Get admin password
    log_info "Jenkins admin password:"
    kubectl exec -n ${JENKINS_NAMESPACE} \
        $(kubectl get pod -l app.kubernetes.io/name=jenkins -n ${JENKINS_NAMESPACE} -o jsonpath='{.items[0].metadata.name}') \
        -- cat /run/secrets/additional/chart-admin-password 2>/dev/null || \
        echo "  Run: kubectl exec -n jenkins \$(kubectl get pod -l app.kubernetes.io/name=jenkins -n jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /run/secrets/additional/chart-admin-password"
}

# Step 8: Configure Jenkins Credentials
configure_credentials() {
    log_header "Step 8: Credential Setup Instructions"

    echo -e "${YELLOW}Please configure the following credentials in Jenkins UI:${NC}"
    echo ""
    echo "  1. Navigate to: http://localhost:8086/credentials/"
    echo ""
    echo "  2. Add the following credentials:"
    echo ""
    echo "     📌 ID: git-credentials"
    echo "        Type: Username with password"
    echo "        Description: Git repository credentials"
    echo ""
    echo "     📌 ID: nexus-credentials"
    echo "        Type: Username with password"
    echo "        Description: Nexus registry credentials"
    echo "        Username: admin"
    echo "        Password: (your Nexus admin password)"
    echo ""
    echo "     📌 ID: sonarqube-token"
    echo "        Type: Secret text"
    echo "        Description: SonarQube authentication token"
    echo "        Secret: (generate from SonarQube UI → My Account → Security)"
    echo ""
}

# Print summary
print_summary() {
    log_header "Setup Complete! 🎉"

    echo -e "${GREEN}Service Endpoints:${NC}"
    echo "  ├── Jenkins:        http://localhost:8086 (NodePort 30086)"
    echo "  ├── SonarQube:      http://localhost:9000 (NodePort 30900)"
    echo "  ├── Nexus Web UI:   http://localhost:8081 (NodePort 30081)"
    echo "  ├── Nexus Docker:   localhost:30082"
    echo "  ├── Staging App:    http://localhost:30180/api/hello"
    echo "  └── Production App: http://localhost:30280/api/hello"
    echo ""
    echo -e "${GREEN}Namespaces:${NC}"
    kubectl get namespaces | grep -E "(jenkins|devops-tools|staging|production)"
    echo ""
    echo -e "${GREEN}Pods:${NC}"
    kubectl get pods --all-namespaces | grep -E "(jenkins|sonarqube|nexus)" || true
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Access Jenkins at http://localhost:8086"
    echo "  2. Configure credentials (see above)"
    echo "  3. Create a Pipeline job pointing to your Git repository"
    echo "  4. Configure GitHub webhook to trigger builds"
    echo "  5. Push a commit to trigger the pipeline!"
}

# Main execution
main() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Dynamic CI/CD Pipeline - Kubernetes Cluster Setup      ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    create_namespaces
    apply_rbac
    deploy_sonarqube
    deploy_nexus
    deploy_trivy_config
    deploy_app_manifests
    install_jenkins
    configure_credentials
    print_summary
}

main "$@"
