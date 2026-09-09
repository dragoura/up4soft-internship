# 07 — Kubernetes

Solution for the **Kubernetes** task: the same Java + React application, running in a local
**kind** cluster (one control-plane, two workers) with Postgres and Redis from Bitnami charts,
backend and frontend from charts written here, ingress routing by hostname, a scheduled database
backup and a read-only ServiceAccount.

`WORKLOG.md` is the step-by-step record: every command that was actually run, why each choice was
made, and the gotchas that cost time. This README is the map.

## Architecture

```
                       host :80 / :443
                             │  (kind extraPortMappings → control-plane)
                    ┌────────▼─────────┐
                    │ ingress-nginx    │  host javaapp.local
                    └───┬──────────┬───┘
                 /      │          │  /api
            ┌───────────▼──┐   ┌───▼──────────┐
            │ frontend     │   │ backend      │
            │ nginx+static │   │ Spring Boot  │
            └──────────────┘   └───┬──────┬───┘
                                   │      │
                       ┌───────────▼─┐  ┌─▼───────────┐
                       │ postgresql  │  │ redis       │
                       │ StatefulSet │  │ StatefulSet │
                       └──────┬──────┘  └─────────────┘
                              │
                       ┌──────▼─────────────┐
                       │ CronJob pg-backup  │ → PVC (StorageClass with Retain)
                       └────────────────────┘
```

## What's in this folder

- **`kube-files/`**: cluster-level manifests — `kind-config.yaml` (3 nodes, `ingress-ready` label,
  host port mappings), `deploy-ingress-nginx.yaml`, Bitnami values for `postgres` and `redis`,
  and `readonly-sa.yaml` (ServiceAccount → ClusterRole → ClusterRoleBinding).
- **`backend/`**: chart for the Spring Boot service — Deployment, Service, ConfigMap for
  non-secret env vars; the password comes from an existing Secret via `secretKeyRef`; liveness,
  readiness and startup probes pointed at the Actuator health groups; CPU/memory requests and a
  HorizontalPodAutoscaler (1–5 replicas at 70% CPU) behind `autoscaling.enabled`.
- **`frontend/`**: chart for nginx + the built React bundle. The nginx config is delivered as a
  ConfigMap and mounted with `subPath`; a `checksum/config` annotation restarts the Pod when the
  config changes.
- **`pg-backup/`**: chart for the backup CronJob — StorageClass with `reclaimPolicy: Retain`, PVC,
  and a `pg_dump` job every five minutes that keeps only the newest N dumps.
- **`WORKLOG.md`**: the full walkthrough, day by day.

## Run it

```bash
kind create cluster --name k8s-java --config kube-files/kind-config.yaml
kubectl apply -f kube-files/deploy-ingress-nginx.yaml

kubectl create namespace java-app
kubectl config set-context --current --namespace=java-app
kubectl create secret generic postgres-secret \
  --from-literal=postgres-password='<admin password>' \
  --from-literal=password='<app password>'

helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  -f kube-files/postgres-values.yaml
helm install redis oci://registry-1.docker.io/bitnamicharts/redis \
  -f kube-files/redis-values.yaml

# no registry in kind — images are loaded onto the nodes directly
kind load docker-image java-app-backend:0.1.0 java-app-frontend:0.1.0 --name k8s-java

helm install backend ./backend
helm install frontend ./frontend
helm install pg-backup ./pg-backup
kubectl apply -f kube-files/readonly-sa.yaml

echo "127.0.0.1 javaapp.local" | sudo tee -a /etc/hosts
curl http://javaapp.local/api/v1/posts
```

