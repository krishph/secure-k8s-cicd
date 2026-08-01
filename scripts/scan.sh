#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/tools.sh
if [ "$#" -eq 0 ]; then
  echo 'Usage: bash scripts/scan.sh IMAGE [IMAGE ...]' >&2
  exit 2
fi
mkdir -p build
# Scan exported archives: the scanner never receives the Docker socket or credentials.
archive=$(mktemp "$PWD/build/scan.XXXXXX")
trap 'rm -f "$archive"' EXIT
for image in "$@"; do
  docker image inspect "$image" >/dev/null 2>&1 || docker pull "$image"
  image_id=$(docker image inspect --format '{{.Id}}' "$image")
  docker save "$image_id" -o "$archive"
  docker run --rm -v "$archive:/image.tar:ro" "$TRIVY_IMAGE" image \
    --input /image.tar --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --no-progress
done
