#!/usr/bin/env bash
set -euo pipefail

NGINX_CONF="/etc/nginx/conf.d/blue-green.conf"

if ! sudo test -f "$NGINX_CONF"; then
  echo "No active Nginx blue-green configuration found."
  exit 1
fi

if sudo grep -q "127.0.0.1:5001" "$NGINX_CONF"; then
  TARGET_COLOR="green"
  TARGET_PORT="5002"
else
  TARGET_COLOR="blue"
  TARGET_PORT="5001"
fi

if ! curl -fsS "http://127.0.0.1:${TARGET_PORT}/health" >/dev/null; then
  echo "Rollback target ${TARGET_COLOR} is not healthy on port ${TARGET_PORT}."
  exit 1
fi

cat > /tmp/blue-green.conf <<EOF_NGINX
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${TARGET_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF_NGINX

sudo mv /tmp/blue-green.conf "$NGINX_CONF"
sudo nginx -t
sudo systemctl reload nginx

echo "ROLLBACK COMPLETE: ${TARGET_COLOR} is live again."
