#!/bin/bash
set -e
echo "====================================================="
echo "🛡️  RUNNING SEMGREP SAST SCAN"
echo "====================================================="
SEMGREP_OUTPUT="${SEMGREP_OUTPUT:-semgrep-results.sarif}"
echo "📥 Installing Semgrep..."
pip install --quiet --user semgrep
 
# On self-hosted runners, pip's --user console scripts land in a bin dir
# (e.g. ~/.local/bin) that may not be on PATH. Invoking semgrep as a
# Python module sidesteps that entirely - it doesn't matter where pip put
# the console script, only that the package is importable.
echo "🔍 Scanning source code..."
python3 -m semgrep scan --config auto --sarif --output "$SEMGREP_OUTPUT"
 
echo "====================================================="
echo "✅ SEMGREP SAST SCAN COMPLETED SUCCESSFULLY"
echo "====================================================="
 
