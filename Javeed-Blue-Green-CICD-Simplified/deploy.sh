#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="blue-green-app"
IMAGE_TAG="${BUILD_NUMBER:-local}"
NGINX_CONF="/etc/nginx/conf.d/blue-green.conf"

# Find which environment is live and deploy to the other one.
if sudo test -f "$NGINX_CONF" && sudo grep -q "127.0.0.1:5001" "$NGINX_CONF"; then
  NEW_COLOR="green"
  NEW_PORT="5002"
elif sudo test -f "$NGINX_CONF" && sudo grep -q "127.0.0.1:5002" "$NGINX_CONF"; then
  NEW_COLOR="blue"
  NEW_PORT="5001"
else
  NEW_COLOR="blue"
  NEW_PORT="5001"
fi

CONTAINER_NAME="${NEW_COLOR}-app"

echo "Building ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo "Deploying ${NEW_COLOR} on port ${NEW_PORT}"
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "${NEW_PORT}:3000" \
  -e DEPLOYMENT_COLOR="$NEW_COLOR" \
  -e APP_VERSION="$IMAGE_TAG" \
  "${IMAGE_NAME}:${IMAGE_TAG}"

# Wait for the new container to become healthy.
for i in {1..15}; do
  if curl -fsS "http://127.0.0.1:${NEW_PORT}/health" >/dev/null; then
    echo "Health check passed."
    break
  fi
  if [ "$i" -eq 15 ]; then
    echo "Health check failed. Keeping current production environment unchanged."
    docker logs "$CONTAINER_NAME" || true
    docker rm -f "$CONTAINER_NAME" || true
    exit 1
  fi
  sleep 2
done

cat > /tmp/blue-green.conf <<EOF_NGINX
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${NEW_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF_NGINX

sudo mv /tmp/blue-green.conf "$NGINX_CONF"
sudo nginx -t
sudo systemctl reload nginx

echo "SUCCESS: ${NEW_COLOR} is now live through Nginx on port 80."
echo "The previous environment is kept running so rollback stays simple."
