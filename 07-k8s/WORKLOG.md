# Worklog — k8s-java

## Day 1 — cluster + ingress

```bash
kind create cluster --name k8s-java --config kind-config.yaml
kubectl get nodes -o wide

# ingress manifest: add ingress-ready to the controller nodeSelector
curl -sO https://kind.sigs.k8s.io/examples/ingress/deploy-ingress-nginx.yaml
awk '!d && /kubernetes.io\/os: linux/ {print; print "        ingress-ready: \"true\""; d=1; next} 1' \
  deploy-ingress-nginx.yaml > tmp && mv tmp deploy-ingress-nginx.yaml
grep -n -A3 "nodeSelector:" deploy-ingress-nginx.yaml

kubectl apply -f deploy-ingress-nginx.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

kind load docker-image java-app-backend:latest --name k8s-java
kind load docker-image java-app-frontend:latest --name k8s-java
```

Checks:

```bash
kubectl get pod -n ingress-nginx -o wide   # controller 1/1 Running on control-plane
kubectl get ingressclass                   # nginx
curl -I http://localhost/                  # 404 from nginx = it works
```

`EXTERNAL-IP: <pending>` is expected — kind has no LoadBalancer.

## Day 2 — postgres + redis via Helm charts

### 1. Namespace

```bash
kubectl create namespace java-app
kubectl config set-context --current --namespace=java-app
kubectl config get-contexts
```

### 2. Secrets (create before installing the charts, in the same namespace)

The postgresql chart expects fixed key names: `postgres-password`, `password`.

```bash
kubectl create secret generic postgres-secret \
  --from-literal=postgres-password='SuperAdminPass123' \
  --from-literal=password='<db password>'

kubectl get secret postgres-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

No secret for redis — `auth.enabled: false`, same as in docker-compose.

### 3. Values files

Create `kube-files/postgres-values.yaml` and `kube-files/redis-values.yaml`.
No passwords in them — only `existingSecret`.

```bash
helm show values oci://registry-1.docker.io/bitnamicharts/postgresql > /tmp/pg-defaults.yaml
helm show values oci://registry-1.docker.io/bitnamicharts/redis > /tmp/redis-defaults.yaml

curl -s 'https://registry.hub.docker.com/v2/repositories/bitnamilegacy/postgresql/tags?page_size=100' \
  | grep -o '"name":"[^"]*"' | head -40
```

`postgres-values.yaml`:

```yaml
image:
  repository: bitnamilegacy/postgresql
  tag: "17.6.0"
global:
  postgresql:
    auth:
      existingSecret: "postgres-secret"
      username: "java-user"
      database: "java-db"
primary:
  persistence:
    enabled: true
    size: 10Gi
  resources:
    requests: {cpu: 100m, memory: 256Mi}
    limits:   {cpu: 500m, memory: 512Mi}
```

`redis-values.yaml`:

```yaml
image:
  repository: bitnamilegacy/redis
  tag: "8.2"
architecture: standalone
auth:
  enabled: false
master:
  persistence:
    enabled: true
    size: 5Gi
  resources:
    requests: {cpu: 50m, memory: 128Mi}
    limits:   {cpu: 200m, memory: 256Mi}
```

Node capacity before picking limits:

```bash
kubectl describe node k8s-java-control-plane | grep -A8 'Allocated resources'
```

### 4. Install

`charts.bitnami.com` returns 403 — install over OCI.

```bash
helm install postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  -n java-app -f kube-files/postgres-values.yaml

helm install redis oci://registry-1.docker.io/bitnamicharts/redis \
  -n java-app -f kube-files/redis-values.yaml

kubectl get pods,pvc,svc
```

### 5. Redeploy after editing values

```bash
helm upgrade postgres oci://registry-1.docker.io/bitnamicharts/postgresql \
  -n java-app -f kube-files/postgres-values.yaml
kubectl rollout status statefulset/postgres-postgresql

helm upgrade redis oci://registry-1.docker.io/bitnamicharts/redis \
  -n java-app -f kube-files/redis-values.yaml
kubectl rollout status statefulset/redis-master

helm list
helm history postgres
```

### 6. Checks

```bash
# the password from existingSecret is really in effect
kubectl exec -it postgres-postgresql-0 -- \
  env PGPASSWORD='' psql -U java-user -d java-db -c 'select 1'          # FATAL: password authentication failed
kubectl exec -it postgres-postgresql-0 -- \
  env PGPASSWORD='<db password>' psql -U java-user -d java-db -c 'select 1'   # 1 row

# what is actually running
kubectl get pod postgres-postgresql-0 -o jsonpath='{.spec.containers[0].image}'; echo
kubectl exec postgres-postgresql-0 -- postgres --version
kubectl exec postgres-postgresql-0 -- cat /bitnami/postgresql/data/PG_VERSION

kubectl exec -it redis-master-0 -- redis-cli ping                       # PONG
```

### Gotchas

- The tag must not go inside `image.repository`: `bitnamilegacy/redis:8.2` plus the default tag
  produces `redis:8.2:latest` — an invalid reference, and the Pod ends up in `InvalidImageName`.
  Always `image.repository` + `image.tag` separately.
- A StatefulSet with an unhealthy Pod never finishes an update (it waits for a Ready that will
  never come). Break it manually — the PVC survives:
  ```bash
  kubectl get statefulset redis-master -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
  kubectl delete pod redis-master-0
  ```
- `helm list` shows APP VERSION from `Chart.yaml` (18.4.0), not the image tag (17.6.0). Chart
  metadata, not a source of truth.
- The "configured without authentication" WARNING in the postgresql NOTES is false when
  `existingSecret` is used.
- The `replica.resources` WARNING for redis is irrelevant with `architecture: standalone` —
  there are no replicas.

### Drop postgres together with its data (the secret survives, it is outside the release)

```bash
helm uninstall postgres -n java-app
kubectl delete pvc -l app.kubernetes.io/name=postgresql
```

---

## Day 3 — own charts for backend and frontend

The Bitnami charts stayed as they were; the application itself went into two minimal charts of
our own, `backend/` and `frontend/`, four files each (Chart, values, deployment, service +
configmap). Everything `helm create` generates on top (serviceAccount, hpa, httpRoute, tests,
`_helpers.tpl`) was deleted — unused, and it hides the parts that matter.

### Images in kind

There is no registry, so images are pushed onto the nodes by hand. The `latest` tag is unusable:
`helm upgrade` sees no diff and rolls out nothing, and `rollout undo` has nothing to roll back to.

```bash
docker tag java-app-backend:latest java-app-backend:0.1.0
docker tag java-app-frontend:latest java-app-frontend:0.1.0
kind load docker-image java-app-backend:0.1.0 java-app-frontend:0.1.0 --name k8s-java
```

`appVersion` in both `Chart.yaml` files is set to `"0.1.0"` (`helm create` leaves `1.16.0` there —
the nginx version from its example). The image tag is derived from it:
`{{ .Values.image.tag | default .Chart.AppVersion }}`.

### backend

- Non-secret env vars live in `values.config`; the ConfigMap renders them with a `range` loop and
  the Deployment pulls them in via `envFrom.configMapRef`. Numbers in values must be quoted — a
  ConfigMap accepts strings only.
- The password is not duplicated: `secretKeyRef` points at the existing `postgres-secret` (created
  by hand; the postgres chart was installed with `existingSecret`, so Bitnami never created one).
- `SERVER_PORT`, `containerPort` and the Service `targetPort` all come from a single
  `values.containerPort`; in the Service, `targetPort: http` refers to the port **name**, not a number.

### Probes (Spring Boot)

Actuator is not on `/actuator`: `application.properties` overrides
`management.endpoints.web.base-path=/manage`. The working paths are `/manage/health/liveness` and
`/manage/health/readiness`. Groups, not the general `/manage/health`: the general one checks the
database, so a database hiccup would restart the whole backend fleet.

The numbers are measured, not copied:

```bash
kubectl logs deploy/backend | grep "Started DemoCiProj"
# Started DemoCiProjApplication in 9.216 seconds
```

9 seconds → startupProbe with `periodSeconds: 5`, `failureThreshold: 12` (60 s of headroom).

### frontend

The image contains neither `default.conf` nor certificates — under compose both arrived as bind
mounts. In the cluster:

- The config lives in `frontend/files/default.conf` and is pulled into a ConfigMap with
  `{{ .Files.Get "files/default.conf" | indent 4 }}`. The `.Files.Get` line starts at column zero;
  all indentation comes from `indent`.
- It is mounted with `subPath`, otherwise the ConfigMap wipes the whole `/etc/nginx/conf.d/`.
  The price: such a file is not updated in place — the restart is triggered by a
  `checksum/config` annotation holding `sha256sum` of the file.
- `listen 443 ssl` and the 80→443 redirect were removed from the config: TLS terminates at the
  Ingress and traffic reaches the Pod over plain http, otherwise you get an endless redirect.

### Gotcha: `localhost` inside a Pod is ::1

```bash
kubectl exec deploy/frontend -- wget -qO- localhost/api/    # Connection refused
kubectl exec deploy/frontend -- wget -qO- 127.0.0.1/api/    # 404 from Spring — the chain works
```

In the Pod's `/etc/hosts`, `localhost` resolves to both `127.0.0.1` and `::1`; busybox wget picks
IPv6 first, while `listen 80` binds IPv4 only. The application is perfectly healthy meanwhile.

### End-to-end check

```bash
kubectl describe pod -l app=frontend         # describe by label, no hash in the name
kubectl port-forward svc/frontend 8081:80    # through the Service — exercises selector and endpoints
kubectl port-forward deploy/frontend 8081:80 # bypassing the Service, straight into the Pod
```

A post created in the UI reached the database:

```bash
kubectl exec postgres-postgresql-0 -- \
  env PGPASSWORD=... psql -U java-user -d java-db -c 'select id, title, author from posts;'
```

## Day 4 — Ingress

The `ingress-nginx` controller was installed back on day 1 and had been returning 404 ever since — there were no rules. kind maps host ports 80/443 onto the control-plane
(`extraPortMappings` in `kind-config.yaml`) and the controller binds them via `hostPort`, so
`EXTERNAL-IP <pending>` on its LoadBalancer is normal, not a failure.

The host is added by hand:

```bash
echo "127.0.0.1 javaapp.local" | sudo tee -a /etc/hosts
```

One Ingress per chart, both on host `javaapp.local`: `/api` → backend:8080, `/` → frontend:80.
The paths come from the code rather than from guessing — `@RequestMapping("/api/v1/")`, i.e.
`/api/v1/posts`.

Two Ingress objects on one host are not two proxies: ingress-nginx **merges** them into a single
`server {}` block in its config and resolves paths by the longest matching prefix.

```bash
kubectl -n ingress-nginx exec deploy/ingress-nginx-controller -- \
  cat /etc/nginx/nginx.conf | grep -A20 javaapp.local
```

A single shared Ingress for both services would produce a byte-identical config, but it would
belong to neither chart: `helm uninstall frontend` would leave a rule pointing at a missing
service (503).

The ingress controller, unlike everything else in the cluster, **does not use the ClusterIP** — it
reads the Service's EndpointSlice and sends traffic straight to Pod IPs. Full packet walkthrough:
`../kubernetes-md/29-service-traffic-flow.md`.

Check:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://javaapp.local/       # 200
curl -s http://javaapp.local/api/v1/posts                            # [{"id":1,"title":"Success!"...
```

## Day 5 — postgres backup CronJob (task 3.1)

The assignment asks for "pvc, pv" and for being able to show the files on the node. Instead of a
static `hostPath` PV we wrote **our own StorageClass with `reclaimPolicy: Retain`**: the reclaim
policy cannot be set on a PVC — it is a PV field — while a StorageClass stamps it onto every
volume it provisions.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path-retain
provisioner: rancher.io/local-path
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
```

A PVC on this class stays `Pending` until the first Pod appears — that is `WaitForFirstConsumer`,
not a failure. It went `Bound` exactly when the first Job started.

### Gotchas

- `pg_dump` refuses to talk to a server with a higher major version. Server 17.6 → we need
  `postgres:17-alpine`, and it has to be `kind load`ed; there is no registry in the cluster.
- The password is read **only** from `PGPASSWORD` (a libpq convention), while the application
  reads `POSTGRES_PASSWORD` (a name chosen in `application.properties`). One secret, two variable
  names — that is exactly what `secretKeyRef` is for.
- `pg_dump ... > file` loses the exit code: the file is created even on failure and the Job reports
  success. Use `pg_dump -f "$FILE"` so `set -e` fails the Job honestly.
- A Job's `restartPolicy` may only be `OnFailure` or `Never`; `Always` is rejected by the API.
- `concurrencyPolicy: Forbid` — if a dump runs longer than five minutes the next run is skipped
  instead of piling up.

### Don't wait for the schedule

```bash
kubectl create job --from=cronjob/pg-backup backup-manual-1
kubectl logs job/backup-manual-1
```

### Where it lands on the node

```bash
kubectl get pv -o custom-columns=NAME:.metadata.name,PATH:.spec.hostPath.path,POLICY:.spec.persistentVolumeReclaimPolicy,CLAIM:.spec.claimRef.name
kubectl get pod -l job-name=backup-manual-1 -o jsonpath='{.items[0].spec.nodeName}'
docker exec k8s-java-worker2 ls -lh /var/local-path-provisioner/pvc-<uuid>_java-app_pg-backup-pvc
# -rw-r--r-- 1 root root 1.9K java-db-<timestamp>.sql
```

The provisioner names the directory `pvc-<uuid>_<namespace>_<pvc name>`. Such a PV carries
nodeAffinity for one specific node: every later run is scheduled there, and losing that node loses
the backups with it. In a real cluster backups go to networked storage.

## Day 6 — ServiceAccount → ClusterRole → ClusterRoleBinding + kubeconfig (task 3.1)

`kube-files/readonly-sa.yaml`: ServiceAccount `viewer` in `java-app`, ClusterRole `cluster-viewer`,
and a ClusterRoleBinding of the same name.

- **RBAC has no deny.** "Everything except secrets" cannot be expressed in one rule: there is
  nowhere to write an exception next to `resources: ["*"]`, so resources are listed explicitly and
  `secrets` is simply absent from the list.
- **`pods/log` is a subresource.** Rights on `pods` do not grant logs; it needs its own entry.
- In `subjects`, a ServiceAccount must carry a `namespace`: the SA lives in one, even though the
  role and the binding are cluster-scoped.

The cluster-scoped pair was not chosen to grab more: `nodes`, `persistentvolumes`,
`storageclasses` and `namespaces` do not belong to any namespace and are unreachable otherwise.

| | RoleBinding | ClusterRoleBinding |
|---|---|---|
| Role | rights in one namespace | impossible, rejected by the API |
| ClusterRole | the role's rights **narrowed to one namespace** | cluster-wide |

### Verify the rights before logging in — impersonation

```bash
kubectl auth can-i list pods          --as=system:serviceaccount:java-app:viewer -A   # yes
kubectl auth can-i get  pods/log      --as=system:serviceaccount:java-app:viewer      # yes
kubectl auth can-i list secrets       --as=system:serviceaccount:java-app:viewer -A   # no
kubectl auth can-i delete deployments --as=system:serviceaccount:java-app:viewer      # no
```

The negative checks matter more than the positive ones: they prove nothing extra was granted.

### Building the kubeconfig

The CA comes from the `kube-root-ca.crt` ConfigMap — Kubernetes places it in every namespace.

```bash
SERVER=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')
kubectl get cm kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > ca.crt
TOKEN=$(kubectl create token viewer --duration=24h)

export KUBECONFIG=./viewer.kubeconfig
kubectl config set-cluster kind-k8s-java --server="$SERVER" \
  --certificate-authority=ca.crt --embed-certs=true
kubectl config set-credentials viewer --token="$TOKEN"
kubectl config set-context viewer --cluster=kind-k8s-java --user=viewer --namespace=java-app
kubectl config use-context viewer
unset KUBECONFIG
```

- `--embed-certs=true` inlines the CA into the file; otherwise only a path is stored and the
  config breaks when moved to another machine.
- Since 1.24 ServiceAccount secrets are not created automatically. `kubectl create token` issues a
  token through the TokenRequest API, with an expiry. A non-expiring token is still possible via a
  `kubernetes.io/service-account-token` Secret, but nobody does that any more — precisely because
  it never expires.
- Under this config, `kubectl auth whoami` returns `system:serviceaccount:java-app:viewer` with
  groups `system:serviceaccounts` and `system:authenticated`.

**The file is the credential** — there is no password in it, only a bearer token. `.gitignore` got
`*.kubeconfig` and `ca.crt`, without a leading path: a pattern containing a slash is anchored to
the directory holding `.gitignore`, so `kube-files/ca.crt` would never have matched from the
repository root.

## Day 7 — the backup as a chart, retention, and orphaned volumes

Task 3.2 asks for a chart per base task, so the CronJob moved into `pg-backup/`
(StorageClass, PVC, CronJob). Everything worth changing between environments is in values:
`schedule`, `timeZone`, `suspend`; `concurrencyPolicy`, both history limits, `backoffLimit`,
`restartPolicy`, `startingDeadlineSeconds`; the database host/port/name/user and
`existingSecret` + `passwordKey`; dump `prefix`, `format` and `keepLast`; PVC size, access mode,
mount path and class; the StorageClass itself; container `resources`.

Two changes of substance, not of form:

- **The chart no longer depends on `backend-config`.** Host, user and database used to arrive via
  `envFrom` from another release's ConfigMap, so `helm uninstall backend` would have silently
  broken the backups. Now only the password comes from a Secret. The database name is written in
  two charts — coupling between releases costs more than one duplicated line.
- Variables were renamed to `PGHOST`/`PGPORT`/`PGUSER`/`PGDATABASE` — the same libpq convention as
  `PGPASSWORD`, which removes every flag from the `pg_dump` call.

### Retention

An overnight run left **221 dumps**. `backup.keepLast` (default 24) deletes everything but the
newest N after each dump:

```sh
ls -1t "$PREFIX"-* | tail -n +$((KEEP+1)) | xargs -r rm -f
```

Deleting by age (`find -mtime +7 -delete`) is the other option, but with a five-minute schedule
"older than a day" only starts working tomorrow.

### A missing values key renders as an empty string

The template referenced `{{ .Values.image.pullPolicy }}` while values had no such key. Helm does
not treat a missing key as an error — it renders an empty string and the field goes to the API
empty. This is why `helm template` before installing is not optional.

### `Retain` means the data outlives the object

After deleting the CronJob, the PVC **and** the PV:

```bash
docker exec k8s-java-worker2 ls -la /var/local-path-provisioner/
# drwxrwxrwx 2 root root 16384 pvc-<uuid>_java-app_pg-backup-pvc
```

The directory with all 221 dumps survived. A PV is not storage, it is a *record about* storage;
deleting the record only removes an entry in etcd, and `reclaimPolicy` decides whether anyone ever
calls the provider's delete.

Put a `Released` volume back into circulation by clearing the claim reference:

```bash
kubectl patch pv <name> -p '{"spec":{"claimRef": null}}'   # back to Available
```

Find the orphans:

```bash
kubectl get pv --sort-by=.status.phase \
  -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,POLICY:.spec.persistentVolumeReclaimPolicy,CLAIM:.spec.claimRef.name,SIZE:.spec.capacity.storage
```

Anything `Released` is a candidate. Our case was worse: with both the PVC and the PV deleted,
*nothing* points at that directory any more — it can only be found by walking the node's disk.
Hence the rule: under `Retain`, delete the PV only after deciding what happens to the data.

## Day 8 — Autoscaling

### metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl top pods
```

The patch is mandatory on kind: metrics-server verifies the kubelet's serving certificate and kind
issues self-signed ones. Without it the Pod runs but never becomes Ready and `kubectl top` answers
`Metrics API not available`.

### Resources, and why there is no CPU limit

```yaml
resources:
  requests: {cpu: 200m, memory: 512Mi}
  limits:   {memory: 1Gi}
```

### HPA

`backend/templates/hpa.yaml` (rendered only when `autoscaling.enabled`), plus a guard in the
Deployment:

```yaml
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
```

Without that guard every `helm upgrade` resets the replica count the autoscaler chose, and the two
fight forever — the same shape as Argo CD `selfHeal` fighting an HPA, with Helm as the other party.

Load test:

```bash
kubectl run load --rm -it --image=busybox:1.36 --restart=Never -- \
  /bin/sh -c 'while true; do wget -q -O- http://backend:8080/api/v1/posts >/dev/null; done'
kubectl get hpa backend -w
```
