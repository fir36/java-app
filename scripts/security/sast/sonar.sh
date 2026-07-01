#!/bin/bash
set -e

echo "====================================================="
echo "🛡️  RUNNING SONARQUBE NATIVE CONTAINER SCAN"
echo "====================================================="

if [ -z "$SONAR_TOKEN" ]; then
    echo "❌ Error: SONAR_TOKEN environment variable is not set."
    exit 1
fi

if [ -z "$SONAR_HOST_URL" ]; then
    echo "❌ Error: SONAR_HOST_URL environment variable is not set."
    exit 1
fi

SONAR_PROJECT_KEY="${SONAR_PROJECT_KEY:-bankapp_account-service}"
WORKSPACE_DIR="${GITHUB_WORKSPACE:-$(pwd)}"

# Run SonarScanner directly on the self-hosted runner's Docker engine.
# Redirects all scanner processing directories to /tmp, out of the git folder.
docker run --rm \
  -v "$WORKSPACE_DIR:/usr/src" \
  sonarsource/sonar-scanner-cli:5.0 \
  -Dsonar.token="$SONAR_TOKEN" \
  -Dsonar.host.url="$SONAR_HOST_URL" \
  -Dsonar.projectKey="$SONAR_PROJECT_KEY" \
  ${SONAR_ORGANIZATION:+-Dsonar.organization="$SONAR_ORGANIZATION"} \
  -Dsonar.working.directory="/tmp/.sonar_workspace"

echo "====================================================="
echo "✅ NATIVE SONARQUBE SCAN COMPLETED SUCCESSFULLY"
echo "====================================================="
