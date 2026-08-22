#!/usr/bin/env bash
# Render once, validate, scan every rendered workload image, then apply that same file.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$#" -ne 2 ] || [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo 'Usage: bash scripts/deploy.sh KUBECTL_CONTEXT VALUES_FILE' >&2
  exit 2
fi
context=$1
values=$2
source scripts/tools.sh
mkdir -p build
# Values must live under the repo because the rendering container mounts only this folder.
helm template voting-app charts/voting-app --namespace securecicd -f "$values" > build/deploy.yaml
test -s build/deploy.yaml
conftest test --policy policies build/deploy.yaml
python3 scripts/list_images.py build/deploy.yaml > build/images.txt
while IFS= read -r image; do
  bash scripts/scan.sh "$image"
done < build/images.txt
# Namespace must already exist; see docs/execution.md.
kubectl --context "$context" -n securecicd apply --dry-run=server -f build/deploy.yaml
kubectl --context "$context" -n securecicd apply -f build/deploy.yaml
kubectl --context "$context" -n securecicd rollout status deployment --timeout=180s
