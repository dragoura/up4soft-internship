# 06 — ELK / EFK (Fluentd + Elasticsearch + Kibana)

This folder contains my ELK/EFK logging setup for the demo Java app.
It was implemented and tested on a **DigitalOcean droplet** (Ubuntu).

## What’s inside

- `app/compose.yml` — runs Postgres, Redis, backend, Nginx (frontend), Fluentd, Elasticsearch, Kibana
- `app/fluentd/conf/` — Fluentd pipeline (parsing + shipping to Elasticsearch)
- `app/nginx-server/` — host Nginx reverse proxy configs (app + Kibana)

## Run

1) Prepare env files : `app/.env` and `app/back-end/.env`
2) Start services:

```bash
cd app
docker compose up -d --build
```

## URLs / Ports

- App (Nginx container): `http://<server>:8080`
- Kibana: `http://<server>:5601`
- Elasticsearch: `http://<server>:9200`
- Fluentd forward input: `24224/tcp` + `24224/udp`

## Log flow / Indices

Containers → Fluentd → Elasticsearch → Kibana

Default indices:
- `demo-logs-*` (backend logs)
- `nginx-logs-*` (Nginx access logs)
- `docker-logs-*` (other container logs)

For details (host Nginx + SSL + Kibana setup), see `app/SETUP_GUIDE.md`.

