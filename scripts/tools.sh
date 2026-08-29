#!/usr/bin/env bash
# Source this file from the repository root. Tools run only when invoked.
set -euo pipefail
CONFTEST_IMAGE="docker.io/openpolicyagent/conftest:v0.65.0"
HELM_IMAGE="alpine/helm:3.17.3"
TRIVY_IMAGE="ghcr.io/aquasecurity/trivy:0.74.0"

conftest() {
  docker run --rm --network none -v "$PWD:/project:ro" -w /project "$CONFTEST_IMAGE" "$@"
}
helm() {
  docker run --rm --network none -v "$PWD:/project:ro" -w /project "$HELM_IMAGE" "$@"
}
