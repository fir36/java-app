#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=$2

if [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_TAG" ]; then
  echo "❌ Error: Usage: deploy.sh <image_name> <image_tag>"
  exit 1
fi

echo "====================================================="
echo "🚀 DEPLOYING TO EC2 (DOCKER)"
echo "====================================================="

echo "📥 Pulling verified image: $IMAGE_NAME:$IMAGE_TAG"
docker pull "$IMAGE_NAME:$IMAGE_TAG"

echo "🛑 Stopping previous container (if any)..."
docker stop account-service || true
docker rm account-service || true

echo "▶️  Starting new container..."
docker run -d \
  --name account-service \
  --restart unless-stopped \
  -p 8080:8080 \
  "$IMAGE_NAME:$IMAGE_TAG"

echo "🩺 Running smoke test on health endpoint..."
for i in $(seq 1 10); do
  if curl -sf http://localhost:8080/actuator/health; then
    echo "====================================================="
    echo "✅ Service is healthy"
    echo "====================================================="
    exit 0
  fi
  sleep 3
done

echo "❌ Service failed health check after deploy" >&2
docker logs account-service
exit 1
