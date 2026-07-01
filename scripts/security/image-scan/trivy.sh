#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Grab the image reference passed as the first parameter to the script
SCAN_TARGET_IMAGE=$1

if [ -z "$SCAN_TARGET_IMAGE" ]; then
    echo "❌ Error: No target image path provided to trivy.sh"
    exit 1
fi

TRIVY_FORMAT="${TRIVY_FORMAT:-json}"
TRIVY_OUTPUT="${TRIVY_OUTPUT-./trivy-report.json}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-LOW,MEDIUM,HIGH,CRITICAL}"
TRIVY_EXIT_CODE="${TRIVY_EXIT_CODE:-0}"
TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-false}"

echo "====================================================="
echo "🛡️  STARTING TRIVY AUTOMATED SECURITY LAYER"
echo "====================================================="

# 1. Download/install the Trivy binary into ephemeral memory space (skip if
#    a previous run on this self-hosted runner already installed it)
if [ ! -x /tmp/trivy ]; then
  echo "📥 Installing Trivy engine context..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /tmp
fi

OUTPUT_FLAG=()
if [ -n "$TRIVY_OUTPUT" ]; then
  OUTPUT_FLAG=(--output "$TRIVY_OUTPUT")
fi

IGNORE_UNFIXED_FLAG=()
if [ "$TRIVY_IGNORE_UNFIXED" = "true" ]; then
  IGNORE_UNFIXED_FLAG=(--ignore-unfixed)
fi

# 2. Execute the vulnerability assessment
echo "🔍 Scanning image: $SCAN_TARGET_IMAGE"
/tmp/trivy image \
  --cache-dir /tmp/.trivy_cache/ \
  --db-repository ghcr.io/aquasecurity/trivy-db \
  --no-progress \
  --scanners vuln \
  --severity "$TRIVY_SEVERITY" \
  --format "$TRIVY_FORMAT" \
  --exit-code "$TRIVY_EXIT_CODE" \
  "${OUTPUT_FLAG[@]}" \
  "${IGNORE_UNFIXED_FLAG[@]}" \
  "$SCAN_TARGET_IMAGE"

echo "====================================================="
echo "✅ TRIVY SECURITY LAYER COMPLETED SUCCESSFULLY"
echo "====================================================="
