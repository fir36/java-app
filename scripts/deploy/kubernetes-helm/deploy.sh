#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=$2

if [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_TAG" ]; then
  echo "❌ Error: Usage: deploy.sh <image_name> <image_tag>"
  exit 1
fi

echo "====================================================="
echo "🚀 DEPLOYING TO KUBERNETES (HELM)"
echo "====================================================="

helm upgrade --install account-service ./charts/account-service \
  --namespace banking --create-namespace \
  --set image.repository="$IMAGE_NAME" \
  --set image.tag="$IMAGE_TAG" \
  --wait --timeout 180s

echo "====================================================="
echo "✅ HELM DEPLOYMENT COMPLETED SUCCESSFULLY"
echo "====================================================="
