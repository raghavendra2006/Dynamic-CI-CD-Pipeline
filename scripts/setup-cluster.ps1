# =============================================================================
# Dynamic CI/CD Pipeline - Cluster Setup Script (PowerShell)
# =============================================================================
# Windows PowerShell version of the cluster setup script.
#
# Prerequisites:
#   - kubectl configured and connected to a Kubernetes cluster
#   - Helm 3.x installed
#   - Docker Desktop installed (with Kubernetes enabled)
#
# Usage:
#   .\scripts\setup-cluster.ps1
# =============================================================================

$ErrorActionPreference = "Stop"

# Configuration
$ProjectDir = Split-Path -Parent $PSScriptRoot
$JenkinsNamespace = "jenkins"
$DevopsNamespace = "devops-tools"
$StagingNamespace = "staging"
$ProductionNamespace = "production"

# Helper functions
function Write-Header($message) {
    Write-Host ""
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host "  $message" -ForegroundColor Cyan
    Write-Host "=================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info($message)    { Write-Host "[INFO]    $message" -ForegroundColor Blue }
function Write-Success($message) { Write-Host "[SUCCESS] $message" -ForegroundColor Green }
function Write-Warn($message)    { Write-Host "[WARN]    $message" -ForegroundColor Yellow }
function Write-Err($message)     { Write-Host "[ERROR]   $message" -ForegroundColor Red }

# Check prerequisites
function Test-Prerequisites {
    Write-Header "Checking Prerequisites"
    $missing = $false

    try { $null = Get-Command kubectl -ErrorAction Stop; Write-Success "kubectl found" }
    catch { Write-Err "kubectl is not installed"; $missing = $true }

    try { $null = Get-Command helm -ErrorAction Stop; Write-Success "Helm found" }
    catch { Write-Err "Helm is not installed"; $missing = $true }

    try { $null = Get-Command docker -ErrorAction Stop; Write-Success "Docker found" }
    catch { Write-Warn "Docker is not installed (optional)" }

    try { kubectl cluster-info 2>&1 | Out-Null; Write-Success "Connected to Kubernetes cluster" }
    catch { Write-Err "Cannot connect to Kubernetes cluster"; $missing = $true }

    if ($missing) { Write-Err "Missing prerequisites."; exit 1 }
}

# Step 1: Create Namespaces
function New-Namespaces {
    Write-Header "Step 1: Creating Namespaces"
    kubectl apply -f "$ProjectDir\k8s\namespace.yaml"
    Write-Success "Namespaces created"
}

# Step 2: Apply RBAC
function Set-RBAC {
    Write-Header "Step 2: Applying RBAC Configuration"
    kubectl apply -f "$ProjectDir\k8s\rbac\jenkins-sa.yaml"
    kubectl apply -f "$ProjectDir\k8s\rbac\jenkins-role.yaml"
    kubectl apply -f "$ProjectDir\k8s\rbac\jenkins-rolebinding.yaml"
    Write-Success "RBAC configured"
}

# Step 3: Deploy SonarQube
function Install-SonarQube {
    Write-Header "Step 3: Deploying SonarQube"
    kubectl apply -f "$ProjectDir\k8s\sonarqube\sonarqube-pvc.yaml"
    kubectl apply -f "$ProjectDir\k8s\sonarqube\sonarqube-deployment.yaml"
    kubectl apply -f "$ProjectDir\k8s\sonarqube\sonarqube-service.yaml"
    Write-Info "Waiting for SonarQube to be ready..."
    Write-Success "SonarQube deployed (NodePort 30900)"
}

# Step 4: Deploy Nexus
function Install-Nexus {
    Write-Header "Step 4: Deploying Nexus Repository Manager"
    kubectl apply -f "$ProjectDir\k8s\nexus\nexus-pvc.yaml"
    kubectl apply -f "$ProjectDir\k8s\nexus\nexus-deployment.yaml"
    kubectl apply -f "$ProjectDir\k8s\nexus\nexus-service.yaml"
    Write-Info "Waiting for Nexus to be ready..."
    Write-Success "Nexus deployed (Web: NodePort 30081, Docker: NodePort 30082)"
}

# Step 5: Deploy Trivy Config
function Install-TrivyConfig {
    Write-Header "Step 5: Deploying Trivy Configuration"
    kubectl apply -f "$ProjectDir\k8s\trivy\trivy-config.yaml"
    Write-Success "Trivy configuration deployed"
}

# Step 6: Deploy Application Manifests
function Install-AppManifests {
    Write-Header "Step 6: Deploying Application Manifests"
    kubectl apply -f "$ProjectDir\k8s\app\staging\deployment.yaml"
    kubectl apply -f "$ProjectDir\k8s\app\staging\service.yaml"
    kubectl apply -f "$ProjectDir\k8s\app\production\deployment-blue.yaml"
    kubectl apply -f "$ProjectDir\k8s\app\production\deployment-green.yaml"
    kubectl apply -f "$ProjectDir\k8s\app\production\service.yaml"
    Write-Success "Staging and Production manifests deployed"
}

# Step 7: Install Jenkins via Helm
function Install-Jenkins {
    Write-Header "Step 7: Installing Jenkins via Helm"
    helm repo add jenkinsci https://charts.jenkins.io
    helm repo update
    helm upgrade --install jenkins jenkinsci/jenkins `
        --namespace $JenkinsNamespace `
        --values "$ProjectDir\helm\jenkins\values.yaml" `
        --wait --timeout 600s
    Write-Success "Jenkins installed via Helm"
}

# Step 8: Print credential instructions
function Show-CredentialInstructions {
    Write-Header "Step 8: Credential Setup Instructions"
    Write-Host "Please configure the following credentials in Jenkins UI:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Navigate to: http://localhost:8086/credentials/"
    Write-Host ""
    Write-Host "  Credential 1:" -ForegroundColor White
    Write-Host "    ID: git-credentials | Type: Username with password"
    Write-Host ""
    Write-Host "  Credential 2:" -ForegroundColor White
    Write-Host "    ID: nexus-credentials | Type: Username with password"
    Write-Host ""
    Write-Host "  Credential 3:" -ForegroundColor White
    Write-Host "    ID: sonarqube-token | Type: Secret text"
    Write-Host "    (Generate from SonarQube at http://localhost:9000)"
    Write-Host ""
}

# Print summary
function Show-Summary {
    Write-Header "Setup Complete!"
    Write-Host "Service Endpoints:" -ForegroundColor Green
    Write-Host "  Jenkins:        http://localhost:8086  (NodePort 30086)"
    Write-Host "  SonarQube:      http://localhost:9000  (NodePort 30900)"
    Write-Host "  Nexus Web UI:   http://localhost:8081  (NodePort 30081)"
    Write-Host "  Nexus Docker:   localhost:30082"
    Write-Host "  Staging App:    http://localhost:30180/api/hello"
    Write-Host "  Production App: http://localhost:30280/api/hello"
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Access Jenkins at http://localhost:8086"
    Write-Host "  2. Configure credentials (see above)"
    Write-Host "  3. Create a Pipeline job pointing to your Git repository"
    Write-Host "  4. Configure GitHub webhook to trigger builds"
    Write-Host "  5. Push a commit to trigger the pipeline!"
}

# Main execution
function Main {
    Write-Host ""
    Write-Host "=== Dynamic CI/CD Pipeline - Kubernetes Cluster Setup ===" -ForegroundColor Cyan
    Write-Host ""

    Test-Prerequisites
    New-Namespaces
    Set-RBAC
    Install-SonarQube
    Install-Nexus
    Install-TrivyConfig
    Install-AppManifests
    Install-Jenkins
    Show-CredentialInstructions
    Show-Summary
}

Main
