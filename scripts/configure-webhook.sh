#!/bin/bash
# =============================================================================
# Webhook Configuration Helper
# =============================================================================
# Helps configure GitHub webhook for Jenkins pipeline triggering.
#
# Usage:
#   chmod +x scripts/configure-webhook.sh
#   ./scripts/configure-webhook.sh
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

JENKINS_URL="${JENKINS_URL:-http://localhost:8086}"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   GitHub Webhook Configuration Guide                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Step 1: Get your Jenkins Webhook URL${NC}"
echo ""
echo "  Your Jenkins webhook URL is:"
echo "  ${JENKINS_URL}/github-webhook/"
echo ""
echo "  If Jenkins is behind a firewall, use a tunnel service like ngrok:"
echo "  ngrok http 8086"
echo "  Then use the ngrok URL: https://<your-id>.ngrok.io/github-webhook/"
echo ""

echo -e "${YELLOW}Step 2: Configure GitHub Webhook${NC}"
echo ""
echo "  1. Go to your GitHub repository → Settings → Webhooks"
echo "  2. Click 'Add webhook'"
echo "  3. Payload URL: ${JENKINS_URL}/github-webhook/"
echo "  4. Content type: application/json"
echo "  5. Secret: (optional, for security)"
echo "  6. Events: Select 'Just the push event'"
echo "  7. Click 'Add webhook'"
echo ""

echo -e "${YELLOW}Step 3: Create Jenkins Pipeline Job${NC}"
echo ""
echo "  1. Go to Jenkins → New Item → Pipeline"
echo "  2. Name: 'pipeline-demo-app'"
echo "  3. Under 'Build Triggers':"
echo "     ✅ Check 'GitHub hook trigger for GITScm polling'"
echo "  4. Under 'Pipeline':"
echo "     Definition: Pipeline script from SCM"
echo "     SCM: Git"
echo "     Repository URL: https://github.com/<your-username>/Dynamic-CI-CD-Pipeline.git"
echo "     Credentials: git-credentials"
echo "     Branch: */main"
echo "     Script Path: Jenkinsfile"
echo "  5. Click 'Save'"
echo ""

echo -e "${GREEN}✅ After completing these steps, pushing to the main branch${NC}"
echo -e "${GREEN}   will automatically trigger the CI/CD pipeline!${NC}"
echo ""
