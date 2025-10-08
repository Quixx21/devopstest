#!/bin/bash
set -e

echo "devops test started"

check() {
  if eval "$1" &>/dev/null; then
    echo "[ OK ]  $2"
  else
    echo "[FAIL]  $2"
  fi
}

echo "DOCKER CHECKS"

# no root!
check "docker run --rm -it quixx21/devops-test:latest id | grep -v 'uid=0'" "Container runs as non-root user"

# image size < 300
check "(( \$(docker image ls --format '{{.Size}}' quixx21/devops-test:latest | sed 's/MB//' | awk '{print int(\$1)}') < 300 ))" "Docker image size < 300MB"


# check for .dockerignore
check "grep -q node_modules .dockerignore" ".dockerignore contains node_modules and other ignores"

echo "CI/CD checks"
# workflow last success?
check "gh run list | grep -q 'success'" "Latest GitHub Actions workflow succeeded"

# check for secrets
check "gh secret list | grep -q DOCKER_USERNAME" "GitHub secret DOCKER_USERNAME exists"
check "gh secret list | grep -q DOCKER_PASSWORD" "GitHub secret DOCKER_PASSWORD exists"
check "gh secret list | grep -q KUBE_CONFIG" "GitHub secret KUBE_CONFIG exists"

echo "manifests check"

check "kubectl get deployment nestjs-app" "NestJS Deployment exists"
check "kubectl get deployment redis" "Redis Deployment exists"
check "kubectl get svc nestjs-service" "NestJS Service exists"
check "kubectl get svc redis" "Redis Service exists"
check "kubectl get ingress nestjs-ingress" "Ingress exists"

# configmap check
check "kubectl get configmap app-config" "ConfigMap exists"
check "kubectl get secret redis-secret" "Redis Secret exists"
check "kubectl get secret app-secrets" "App Secret exists"

# network policy check
check "kubectl get networkpolicy redis-access" "NetworkPolicy exists"

echo "redis integration"

# redis logs
check "kubectl logs -l app=redis | grep -q 'Ready to accept connections'" "Redis container is running"

# nest js + redis works?
check "kubectl logs -l app=nestjs-app | grep -q 'Redis health check passed'"

# check for health
check "curl -s http://localhost/redis | grep -q 'true'" "/redis endpoint returns healthy status"

echo "security"

# non-root in containers
check "kubectl exec -it \$(kubectl get pod -l app=nestjs-app -o name) -- id | grep -v 'uid=0'" "NestJS container runs as non-root"
check "kubectl exec -it \$(kubectl get pod -l app=redis -o name) -- id | grep -v 'uid=0'" "Redis container runs as non-root"

# READ-ONLY check
check "kubectl exec -it \$(kubectl get pod -l app=redis -o name) -- touch /tmp/testfile 2>&1 | grep -q 'Read-only'" "Redis filesystem is read-only"

# flags for security
check "kubectl get deployment nestjs-app -o yaml | grep -q 'allowPrivilegeEscalation: false'" "Privilege escalation disabled (NestJS)"
check "kubectl get deployment redis -o yaml | grep -q 'allowPrivilegeEscalation: false'" "Privilege escalation disabled (Redis)"

echo "autoscaler + health check"
# liveness/probes check
check "kubectl get deployment nestjs-app -o yaml | grep -q livenessProbe" "Liveness probe configured"
check "kubectl get deployment nestjs-app -o yaml | grep -q readinessProbe" "Readiness probe configured"

echo "monitoring checks"

# check for pods
check "kubectl get pods -l app=prometheus -o jsonpath='{.items[0].status.phase}' | grep -q Running" "Prometheus pod is running"
check "kubectl get pods -l app=grafana -o jsonpath='{.items[0].status.phase}' | grep -q Running" "Grafana pod is running"

# Prometheus API check
check "kubectl exec -it $(kubectl get pod -l app=prometheus -o name) -- wget -qO- localhost:9090/api/v1/status/buildinfo | grep -q 'version'" "Prometheus API reachable"
check "kubectl exec -it $(kubectl get pod -l app=prometheus -o name) -- wget -qO- localhost:9090/api/v1/targets | grep -q 'nestjs-service:3000'" "Prometheus is scraping NestJS metrics"

echo "test ended"
