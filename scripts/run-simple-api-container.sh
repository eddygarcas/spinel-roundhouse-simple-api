#!/usr/bin/env bash
# Build and run the deployable simple API image on the selected local port.

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
IMAGE_NAME=${IMAGE_NAME:-simple-api-binary:local}
PORT=${PORT:-3000}

docker build --tag "$IMAGE_NAME" --file "$ROOT_DIR/docker/simple-api/Dockerfile" "$ROOT_DIR"
exec docker run --rm --publish "$PORT:3000" --volume simple-api-storage:/app/storage "$IMAGE_NAME"
