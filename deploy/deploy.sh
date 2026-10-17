#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${1:-}"
UPSTREAM_FILE="/etc/nginx/conf.d/novapay-upstream.conf"
HEALTH_PATH="/healthz"
MAX_RETRIES=5

if [[ -z "$IMAGE" ]]; then
    echo "Usage: $0 <docker-image:tag>"
    exit 1
fi

BLUE_PORT=8081
GREEN_PORT=8082
BLUE_NAME="novapay-blue"
GREEN_NAME="novapay-green"

if [[ ! -f "$UPSTREAM_FILE" ]]; then
    echo "ERROR: Nginx upstream file not found: $UPSTREAM_FILE"
    exit 1
fi

# Identify the currently active Nginx backend.
if grep -q '127\.0\.0\.1:8081' "$UPSTREAM_FILE"; then
    ACTIVE="blue"
    IDLE="green"
    IDLE_PORT="$GREEN_PORT"
    IDLE_NAME="$GREEN_NAME"
elif grep -q '127\.0\.0\.1:8082' "$UPSTREAM_FILE"; then
    ACTIVE="green"
    IDLE="blue"
    IDLE_PORT="$BLUE_PORT"
    IDLE_NAME="$BLUE_NAME"
else
    echo "ERROR: Could not identify active Nginx backend."
    exit 1
fi

echo "Currently active: $ACTIVE"
echo "Deploying image: $IMAGE"
echo "Target: $IDLE on port $IDLE_PORT"

# Pull the requested image before touching the running deployment.
docker pull "$IMAGE"

# Remove any stale inactive container.
docker rm -f "$IDLE_NAME" >/dev/null 2>&1 || true

# Start the new version on the inactive localhost-only port.
docker run -d \
    --name "$IDLE_NAME" \
    --restart unless-stopped \
    -p "127.0.0.1:${IDLE_PORT}:8000" \
    "$IMAGE"

# Verify the new version before switching any traffic.
HEALTHY=false

for attempt in $(seq 1 "$MAX_RETRIES"); do
    echo "Health check $attempt/$MAX_RETRIES..."

    if curl --fail --silent --show-error \
        "http://127.0.0.1:${IDLE_PORT}${HEALTH_PATH}"; then
        echo
        HEALTHY=true
        break
    fi

    sleep 3
done

if [[ "$HEALTHY" != true ]]; then
    echo "ERROR: New container failed health checks."
    docker logs --tail 100 "$IDLE_NAME" || true
    docker rm -f "$IDLE_NAME" || true
    echo "Existing active backend remains unchanged."
    exit 1
fi

# Prepare the new Nginx configuration.
TMP_FILE="$(mktemp)"
BACKUP_FILE="$(mktemp)"

cp "$UPSTREAM_FILE" "$BACKUP_FILE"

cat > "$TMP_FILE" <<EOF
upstream novapay_backend {
    server 127.0.0.1:${IDLE_PORT};
    keepalive 32;
}
EOF

sudo install -m 0644 "$TMP_FILE" "$UPSTREAM_FILE"
rm -f "$TMP_FILE"

# Validate the configuration before applying it.
if ! sudo nginx -t; then
    echo "ERROR: Nginx validation failed; restoring previous configuration."
    sudo install -m 0644 "$BACKUP_FILE" "$UPSTREAM_FILE"
    rm -f "$BACKUP_FILE"
    docker rm -f "$IDLE_NAME" || true
    exit 1
fi

# Reload Nginx only after the new version is healthy.
if ! sudo systemctl reload nginx; then
    echo "ERROR: Nginx reload failed; restoring previous configuration."
    sudo install -m 0644 "$BACKUP_FILE" "$UPSTREAM_FILE"
    sudo nginx -t && sudo systemctl reload nginx || true
    rm -f "$BACKUP_FILE"
    docker rm -f "$IDLE_NAME" || true
    exit 1
fi

rm -f "$BACKUP_FILE"

echo "Traffic switched to $IDLE on port $IDLE_PORT."

# Verify traffic through Nginx before removing the old container.
if ! curl --fail --silent --show-error \
    "http://127.0.0.1${HEALTH_PATH}"; then
    echo "ERROR: Post-switch health check failed."
    echo "Investigate before removing the old container."
    exit 1
fi

# Stop the previous container after successful verification.
if [[ "$ACTIVE" == "blue" ]]; then
    OLD_NAME="$BLUE_NAME"
else
    OLD_NAME="$GREEN_NAME"
fi

docker rm -f "$OLD_NAME" || true

echo "Deployment completed successfully."
docker ps