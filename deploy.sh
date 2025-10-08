#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="quixx21/devops-test:latest"
CLUSTER="devops-test"
CTX="kind-${CLUSTER}"

log(){ echo "[$(date +%H:%M:%S)] $*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required cmd: $1"; exit 1; }
}

require docker
require kubectl
require kind

log "Build Docker image"
docker build -t "${IMAGE}" .

if ! kind get clusters | grep -qx "${CLUSTER}"; then
  log "Create kind cluster: ${CLUSTER}"
  # if config exists?
  if [[ -f kubernetes/kind-config.yaml ]]; then
    kind create cluster --name "${CLUSTER}" --config kubernetes/kind-config.yaml
  else
    kind create cluster --name "${CLUSTER}"
  fi
else
  log "Kind cluster already exists: ${CLUSTER}"
fi

log "Use kubectl context ${CTX}"
kubectl config use-context "${CTX}" >/dev/null

log "Load image into kind"
kind load docker-image "${IMAGE}" --name "${CLUSTER}"

# ingress controller
log "Install ingress-nginx"
if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
fi

log "Wait for ingress control"
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=180s

# apply manifests
log "Apply app manifests"
# per file no kind-config
while IFS= read -r -d '' f; do
  [[ "$(basename "$f")" == "kind-config.yaml" ]] && continue
  kubectl apply -f "$f"
done < <(find kubernetes -maxdepth 1 -type f -name "*.yaml" -print0)

# for grafana
if [[ -d kubernetes/grafana ]]; then
  log "Apply grafana/prometheus manifests"
  kubectl apply -f kubernetes/grafana/
fi

# app roll out
log "Wait for app deployments"
for d in nestjs-app redis; do
  if kubectl get deploy "$d" >/dev/null 2>&1; then
    kubectl rollout status deploy/"$d" --timeout=180s || true
  fi
done

# if metrics
for d in prometheus grafana; do
  if kubectl get deploy "$d" >/dev/null 2>&1; then
    kubectl rollout status deploy/"$d" --timeout=180s || true
  fi
done

log "Cluster objects"
kubectl get pods -A
kubectl get svc
kubectl get ingress

# check redis
log "Check /redis via ingress"
set +e
RESP=$(curl -fsS http://localhost/redis 2>/dev/null)
RC=$?
set -e

if [[ $RC -eq 0 ]]; then
  echo "$RESP"
  log "Ingress is reachable"
else
  log "WARN: http://localhost/redis is not reachable yet."
  log "Check ingress-nginx and app readiness, or retry in a few seconds."
fi

# verify.sh
if [[ -x ./verify.sh ]]; then
  log "Run verify.sh"
  ./verify.sh || true
fi

log "Done."
