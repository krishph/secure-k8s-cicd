# Execution instructions

All commands below are supplied for future execution. No successful run is implied.
Use a terminal in this repository's root. macOS, Linux, or WSL2 with Docker are
the intended environments. Docker Desktop must be running if you use it.

## 1. Prerequisites

- Docker Engine or Docker Desktop, with Compose v2 supporting `up --wait`.
- Bash, Make, and Python 3.11+.
- Internet access for base images, Python dependencies, and Trivy databases.
- For Kubernetes: a disposable local cluster or existing EKS cluster, `kubectl`,
  and permission to manage the `securecicd` namespace.
- For the Kind walkthrough: install the `kind` CLI separately.

Policy tools are centralized in `scripts/tools.sh`: Conftest v0.65.0 (Rego v1),
Helm 3.17.3, Trivy 0.74.0. These are selected versions, not claims of latest releases.
On an architecture without a published tool image, use an amd64 Docker environment
or a matching supported image. Tool execution has not been tested on either platform.

## 2. Inspect and exercise the policy gate

```bash
make check
```

This runs Rego unit tests, checks the eleven fixture expectations, lints the Helm
chart, renders it into `build/rendered.yaml`, and validates that file plus `k8s/`.
The ten bad fixtures are **expected to be denied**, so successful detection makes
the fixture runner pass. An unavailable tool or Rego compilation error is a test
failure, not a detected security violation.

To see one intentional denial directly:

```bash
bash -c 'source scripts/tools.sh; conftest test --policy policies tests/fixtures/bad/privileged.yaml'
```

Expected behavior: nonzero exit status and a message containing `SC004`. Do not
apply anything under `tests/fixtures/bad/` to a cluster.

## 3. Test the Python API

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r app/backend/requirements.txt
make test
```

Tests inject a mocked Redis client and do not require a running database. They
exercise atomic writes, invalid payloads, storage failures, and request size limits.
They are unit tests, not a replacement for the manual end-to-end smoke test below.

## 4. Run locally with Compose

```bash
make up
docker compose ps
curl http://localhost:8080/api/results
curl -X POST http://localhost:8080/api/vote \
  -H 'Content-Type: application/json' -d '{"choice":"cats"}'
curl http://localhost:8080/api/results
```

Open <http://localhost:8080>. A valid POST should return HTTP 201 and increment
the selected total. An invalid choice should return 400. The frontend is bound
to `127.0.0.1`; the database and API have no published host ports.

```bash
docker compose logs backend frontend redis
make down
```

Stopping/recreating Redis discards votes. There is no PVC or backup in this demo.

## 5. Scan all images

```bash
make scan
```

The script builds the application images, exports each image to a temporary
archive, and scans the archive. The scanner needs network access for vulnerability
databases but receives neither the Docker socket nor registry credentials.
The first vulnerability or scanner error fails the command. Update affected
dependencies/base images and rerun; no vulnerability exceptions are preconfigured.

## 6. Local Kubernetes using Kind

Use a new namespace and one installation per namespace: the prototype deliberately
uses fixed Service names `frontend`, `backend`, and `redis`. Do not install both
the raw YAML and Helm-managed release into the same namespace.

```bash
kind create cluster --name securecicd
make build
docker pull docker.io/library/redis:7.4-alpine
kind load docker-image --name securecicd \
  docker.io/securecicd/frontend:dev \
  docker.io/securecicd/backend:dev \
  docker.io/library/redis:7.4-alpine
kubectl --context kind-securecicd apply -f k8s/namespace.yaml
python3 -m pip install PyYAML==6.0.2
make deploy CONTEXT=kind-securecicd VALUES=charts/voting-app/values.yaml
kubectl --context kind-securecicd -n securecicd port-forward svc/frontend 8080:8080
```

`make deploy` renders once, validates the rendered manifests, enumerates and scans
their images, performs a Kubernetes server dry-run, then applies the same file.
It does **not** create a Helm release or run application unit tests; run `make test`
and `make check` first. A rollout failure exits nonzero but does not auto-rollback.
The default Kind CNI may not enforce NetworkPolicies; use a policy-capable CNI
when demonstrating network isolation. The policies assume CoreDNS pods labeled
`k8s-app=kube-dns` in `kube-system`. Adapt DNS egress for NodeLocal DNS/custom CNIs.

For the alternative raw YAML demonstration, use a fresh cluster/namespace and run:

```bash
make check
make scan
kubectl --context kind-securecicd apply -f k8s/namespace.yaml
kubectl --context kind-securecicd -n securecicd apply --dry-run=server -f k8s/
kubectl --context kind-securecicd -n securecicd apply -f k8s/
kubectl --context kind-securecicd -n securecicd rollout status deployment --timeout=180s
```

To use Helm's release tracking instead, install a local Helm CLI, render and validate
the exact values first, scan those image references, then use `helm upgrade --install`
with the same release, chart, namespace, and values. That is an operator-managed path.

Cleanup removes the entire disposable Kind cluster:

```bash
kind delete cluster --name securecicd
```

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Docker connection error | Start Docker Engine/Desktop |
| SC002 with your registry | Update exact repositories in `policies/kubernetes.rego`; preserve fixture repositories while running demo tests |
| ImagePullBackOff | Build/load local images or publish to your own registry; `securecicd/*` images are placeholders |
| Frontend 502 | Backend readiness, Service endpoints, and NetworkPolicy routing |
| Backend 503 | Redis readiness, `REDIS_URL`, and DNS/network policy |
| Permission denied writing files | Writable `/tmp` or `/data` mount and matching UID/fsGroup |
| Trivy blocks the build | Review findings and refresh dependencies; database/network failures also block |
| Pods rejected by API | These Rego policies are not a complete Kubernetes schema validator; read server dry-run errors |
