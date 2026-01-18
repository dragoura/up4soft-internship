# 05 — CI/CD

Solution for **Monitoring** task: compose file for app and monitoring containers, Prometheus configuration. Monitoring was implemented on local Alpine VM and on the DigitalOcean Droplet.

## Architecture (how it’s deployed)

- **Separate monitoring droplet/VM**: runs **Prometheus** + **Grafana** (so monitoring doesn’t compete with the app for resources).
- **Application droplet/VM**: runs the app + exporters so Prometheus can scrape metrics:
  - **Spring Boot / Micrometer** endpoint: `http://<app-host>:8081/manage/prometheus`
  - **cAdvisor**: `http://<app-host>:8080`
  - **postgres_exporter**: `http://<app-host>:9187/metrics`
  - **node_exporter**: `http://<app-host>:9100/metrics` (installed on the host)

## What’s in this folder

- `prometheus.yml`: Prometheus scrape config (replace `server_ip` with your target host/IP).
- `compose.yml`: example Compose stack that includes **cAdvisor** + **postgres_exporter** alongside the app.
- `grafana_dashboards.yml`: list of dashboards used (IDs/names).

## Run locally (Docker Compose)

You can also run the stack locally via Docker Compose (use `compose.yml`, and make sure its relative paths match your local project layout — it expects `./back-end` and `./nginx` next to the compose project directory):

```bash
docker compose up -d
```

Example (from this repo, using `03-docker/Java-app` as the project directory):

```bash
cd ../03-docker/Java-app
docker compose -f ../../05-monitoring/compose.yml --project-directory . up -d
```

## Dashboards used

From `grafana_dashboards.yml`:

- Node Exporter (`1860`)
- JVM (Micrometer) (`4701`)
- Micrometer Spring Throughput (`5373`)
- PostgreSQL Database (`9628`)
- cAdvisor exporter (`14282`)

