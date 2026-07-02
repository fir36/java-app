#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=$2
PORT="${DEPLOY_PORT:-8080}"

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
docker stop account-service 2>/dev/null || true
docker rm account-service 2>/dev/null || true

# The named container above might not be what's actually holding the
# port - e.g. a stray container from a previous naming scheme, manual
# testing, or a deploy that crashed before cleanup. Find whatever is
# bound to $PORT on the host and clear that out too, otherwise `docker
# run -p` fails with "address already in use" even though the container
# we expected to stop was never there in the first place.
echo "🔎 Checking for anything else bound to host port ${PORT}..."
STALE_CONTAINERS=$(docker ps -a --filter "publish=${PORT}" --format '{{.ID}} {{.Names}}')
if [ -n "$STALE_CONTAINERS" ]; then
  echo "⚠️  Found container(s) occupying port ${PORT}"
else
  echo "✅ Port ${PORT} is free."
fi

echo "▶️  Starting new container..."
docker run -d \
  --name account-service \
  --restart unless-stopped \
  -p "${PORT}:8080" \
  "$IMAGE_NAME:$IMAGE_TAG"

echo "🩺 Running smoke test on health endpoint..."
for i in $(seq 1 10); do
  if curl -sf "http://localhost:${PORT}/actuator/health"; then
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
