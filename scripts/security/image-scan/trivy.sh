#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# Grab the image reference passed as the first parameter to the script
SCAN_TARGET_IMAGE=$1
if [ -z "$SCAN_TARGET_IMAGE" ]; then
    echo "❌ Error: No target image path provided to trivy.sh"
    exit 1
fi

TRIVY_SEVERITY="${TRIVY_SEVERITY:-HIGH,CRITICAL}"
TRIVY_IGNORE_UNFIXED="${TRIVY_IGNORE_UNFIXED:-false}"
TRIVY_JSON_OUTPUT="${TRIVY_JSON_OUTPUT:-trivy-report.json}"
TRIVY_SARIF_OUTPUT="${TRIVY_SARIF_OUTPUT:-trivy-results.sarif}"
# Set to 'true' to fail the pipeline when findings are present at
# TRIVY_SEVERITY. Default is 'false' - findings are reported (SARIF is
# always generated/uploaded) but never block the pipeline on their own.
TRIVY_FAIL_ON_FINDINGS="${TRIVY_FAIL_ON_FINDINGS:-false}"
# Trivy's own default is 5m0s for the *entire* run, DB download included.
# That's tight for a cold cache on a loaded runner/slow registry pull, so
# give it more room here. Override via TRIVY_TIMEOUT if needed.
TRIVY_TIMEOUT="${TRIVY_TIMEOUT:-15m}"
# DB downloads (and occasionally the scan itself) can fail transiently on
# a flaky/rate-limited registry pull; retry a couple of times before
# giving up for real.
TRIVY_MAX_ATTEMPTS="${TRIVY_MAX_ATTEMPTS:-3}"
# Persistent across runs on this self-hosted runner - unlike /tmp, which
# gets wiped by reboots/tmpfiles cleanup - so the ~500MB vuln DB isn't
# re-downloaded on every single pipeline run. Trivy already skips the
# download on its own if the cached DB is fresh (checks its own metadata),
# so simply pointing --cache-dir somewhere durable is most of the speedup.
TRIVY_CACHE_DIR="${TRIVY_CACHE_DIR:-$HOME/.cache/trivy}"

echo "====================================================="
echo "🛡️  STARTING TRIVY AUTOMATED SECURITY LAYER"
echo "====================================================="

# 1. Download/install the Trivy binary into ephemeral memory space (skip if
#    a previous run on this self-hosted runner already installed it)
if [ ! -x /tmp/trivy ]; then
  echo "📥 Installing Trivy engine context..."
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /tmp
fi

mkdir -p "$TRIVY_CACHE_DIR"

IGNORE_UNFIXED_FLAG=()
if [ "$TRIVY_IGNORE_UNFIXED" = "true" ]; then
  IGNORE_UNFIXED_FLAG=(--ignore-unfixed)
fi

# 2. Scan ONCE to JSON, with retries around transient DB-download /
#    registry-pull failures. --exit-code is always 0 here: trivy's own
#    exit-code gate would require a second full scan pass to also get a
#    SARIF report, which doubled scan time for no benefit. Every other
#    output format, and the pass/fail decision, is derived below from this
#    single JSON report instead.
echo "🔍 Scanning image: $SCAN_TARGET_IMAGE"

attempt=1
until [ "$attempt" -gt "$TRIVY_MAX_ATTEMPTS" ]; do
  set +e
  /tmp/trivy image \
    --cache-dir "$TRIVY_CACHE_DIR" \
    --db-repository ghcr.io/aquasecurity/trivy-db \
    --no-progress \
    --scanners vuln \
    --timeout "$TRIVY_TIMEOUT" \
    --severity "$TRIVY_SEVERITY" \
    --format json \
    --exit-code 0 \
    --output "$TRIVY_JSON_OUTPUT" \
    "${IGNORE_UNFIXED_FLAG[@]}" \
    "$SCAN_TARGET_IMAGE"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    break
  fi
  if [ "$attempt" -eq "$TRIVY_MAX_ATTEMPTS" ]; then
    echo "❌ Trivy scan failed after $TRIVY_MAX_ATTEMPTS attempts (exit code $status)" >&2
    exit "$status"
  fi
  echo "⚠️  Trivy scan failed (exit code $status), retrying ($attempt/$TRIVY_MAX_ATTEMPTS)..." >&2
  attempt=$((attempt + 1))
  sleep 5
done

# 3. Derive the SARIF report from the JSON already on disk - no re-scan.
echo "📄 Converting report to SARIF..."
/tmp/trivy convert --format sarif --output "$TRIVY_SARIF_OUTPUT" "$TRIVY_JSON_OUTPUT"

# 4. Summarize findings and decide whether to fail, based on
#    TRIVY_FAIL_ON_FINDINGS rather than a second trivy invocation.
FINDING_COUNT=$(grep -o '"VulnerabilityID"' "$TRIVY_JSON_OUTPUT" | wc -l | tr -d ' ')
echo "-----------------------------------------------------"
echo "📊 Findings at severity [$TRIVY_SEVERITY]: $FINDING_COUNT"
echo "-----------------------------------------------------"

if [ "$FINDING_COUNT" -gt 0 ] && [ "$TRIVY_FAIL_ON_FINDINGS" = "true" ]; then
  echo "❌ Failing pipeline: findings present and TRIVY_FAIL_ON_FINDINGS=true"
  echo "====================================================="
  exit 1
fi

echo "====================================================="
echo "✅ TRIVY SECURITY LAYER COMPLETED SUCCESSFULLY"
echo "====================================================="
