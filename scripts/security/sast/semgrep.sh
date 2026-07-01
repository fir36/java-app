#!/bin/bash
set -e
echo "====================================================="
echo "🛡️  RUNNING SEMGREP SAST SCAN"
echo "====================================================="
SEMGREP_OUTPUT="${SEMGREP_OUTPUT:-semgrep-results.sarif}"
echo "📥 Installing Semgrep..."
pip install --quiet --user semgrep
 
# On self-hosted runners, pip's --user console scripts land in a bin dir
# (e.g. ~/.local/bin) that isn't on this runner's PATH by default. Rather
# than invoking via `python -m semgrep` (deprecated as of semgrep 1.38 and
# now errors out), put that bin dir on PATH for this step and call the
# `semgrep` binary directly, the way upstream expects.
USER_BASE="$(python3 -m site --user-base)"
export PATH="${USER_BASE}/bin:${PATH}"
 
echo "🔍 Scanning source code..."
semgrep scan --config auto --sarif --output "$SEMGREP_OUTPUT"
 
echo "====================================================="
echo "✅ SEMGREP SAST SCAN COMPLETED SUCCESSFULLY"
echo "====================================================="
