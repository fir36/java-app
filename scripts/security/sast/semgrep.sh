#!/bin/bash
set -e

echo "====================================================="
echo "🛡️  RUNNING SEMGREP SAST SCAN"
echo "====================================================="

SEMGREP_OUTPUT="${SEMGREP_OUTPUT:-semgrep-results.sarif}"

echo "📥 Installing Semgrep..."
pip install --quiet semgrep

echo "🔍 Scanning source code..."
semgrep scan --config auto --sarif --output "$SEMGREP_OUTPUT"

echo "====================================================="
echo "✅ SEMGREP SAST SCAN COMPLETED SUCCESSFULLY"
echo "====================================================="
