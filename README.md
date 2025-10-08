# devops test

This repository demonstrates a complete CI/CD and container orchestration setup for a production-grade NestJS service with Redis caching, GitHub Actions pipeline, and Kubernetes deployment with integrated observability (Prometheus + Grafana).

---

## Overview

The stack is built around the following components:

- **Application Layer:** NestJS REST API (Node.js 20-alpine)
- **Data Layer:** Redis 7-alpine with password authentication
- **CI/CD:** GitHub Actions pipeline for build, push and deploy
- **Orchestration:** Kubernetes (tested on kind)
- **Monitoring:** Prometheus (metrics scrape) + Grafana dashboards
- **Security:** Non-root containers, readonly FS, Secrets, NetworkPolicy

---

## 1. Docker

### Build & Run

```bash
docker build -t quixx21/devops-test:latest .
docker run -d -p 3000:3000 quixx21/devops-test:latest
```

**Dockerfile highlights**
- Multi-stage build (minimal image size ~150 MB)
- Based on official `node:20-alpine`
- Runs as non-root user (`USER node`)
- `.dockerignore` excludes `node_modules`, `dist`, and `tests`

---

## 2. CI/CD Pipeline (GitHub Actions)

Pipeline: `.github/workflows/ci-cd.yml`

Stages:
1. **Build:** create Docker image from source  
2. **Push:** publish image to Docker Hub  
3. **Deploy:** rollout update to Kubernetes cluster  
4. **Verify:** health & integration checks via `verify.sh`

Required repository secrets:

| Name | Description |
|------|--------------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub access token |
| `KUBE_CONFIG` | Base64-encoded kubeconfig for target cluster (devops-test pass)|

---

## 3. Kubernetes Deployment

All manifests are under `/kubernetes`.

```bash
kubectl apply -f kubernetes/
kubectl get pods
kubectl get svc
kubectl get ingress
```

### Components
- `app-deployment.yaml` — NestJS application Deployment  
- `redis-deployment.yaml` — Redis Deployment  
- `app-service.yaml`, `redis-service.yaml` — internal Services  
- `app-ingress.yaml` — Ingress routing to NestJS  
- `configmap.yaml` — environment variables  
- `redis-secret.yaml` — Redis password (base64-encoded)  
- `networkpolicy.yaml` — restricts Redis traffic  
- `hpa.yaml` — CPU-based Horizontal Pod Autoscaler  

### Quick check
```bash
curl http://localhost/redis
# {"status":true,"message":"Redis connection is healthy"}
```

---

## 4. Application Configuration

| Variable | Description | Default |
|-----------|--------------|----------|
| `NODE_ENV` | Node environment | production |
| `PORT` | NestJS port | 3000 |
| `REDIS_HOST` | Redis service hostname | redis |
| `REDIS_PORT` | Redis port | 6379 |
| `REDIS_PASSWORD` | From Kubernetes Secret | — |

---

## 5. Health & Autoscaling

**Probes** defined in `app-deployment.yaml`:

```yaml
livenessProbe:
  httpGet:
    path: /redis
    port: 3000
readinessProbe:
  httpGet:
    path: /redis
    port: 3000
```

**HPA** configured at 70% CPU utilization:

```bash
kubectl get hpa
```

---

## 6. Security Controls

- Non-root execution (`runAsNonRoot: true`, UID 1001)  
- Read-only root filesystem (`readOnlyRootFilesystem: true`)  
- Privilege escalation disabled  
- Redis credentials stored in Secret  
- Redis isolated via NetworkPolicy (accessible only by NestJS pods)

Validation:

```bash
kubectl exec -it $(kubectl get pod -l app=nestjs-app -o name) -- id
kubectl get networkpolicy
```

---

## 7. Observability

### Prometheus
Prometheus scrapes `/metrics` endpoint from the NestJS service.

```bash
kubectl port-forward svc/prometheus 9090:9090
# Open http://localhost:9090
```

Prometheus job (in ConfigMap):
```yaml
- job_name: "nestjs-app"
  metrics_path: /metrics
  static_configs:
    - targets: ["nestjs-service:3000"]
```

### Grafana
Grafana connects to Prometheus as its data source.

```bash
kubectl port-forward svc/grafana 30300:3000
# Open http://localhost:30300
# Login: admin / admin
```

---

## 8. Verification

Run the provided validation script (file commented):

```bash
chmod +x verify.sh
./verify.sh
```

Checks include:
- Docker build and security compliance  
- CI/CD workflow status  
- Kubernetes object existence  
- Redis connectivity  
- Security contexts  
- Autoscaling and probes  
- Monitoring stack (Prometheus + Grafana)

---

## 9. Local Development

For local testing without Kubernetes:

```bash
docker-compose up --build
curl http://localhost:3000/redis
```

---

## 10. System Requirements

- Docker ≥ 24.x  
- kubectl ≥ 1.29  
- kind cluster  
- Node.js ≥ 20 (for local runs)  
- GitHub Actions runner (for CI/CD pipeline)

