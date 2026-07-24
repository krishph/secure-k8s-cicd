#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/tools.sh
mkdir -p build
conftest verify --policy policies
python3 scripts/test_fixtures.py
helm lint charts/voting-app --strict
# Write rendered YAML to a file: passing YAML via command substitution is incorrect.
helm template voting-app charts/voting-app --namespace securecicd > build/rendered.yaml
test -s build/rendered.yaml
conftest test --policy policies k8s/ build/rendered.yaml
