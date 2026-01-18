# 03 — Docker

Solution for **Docker** task: containerize the **Java + React** app from task №1 (**Linux Web Server**) and run it via Docker Compose.

## What is included

- `Java-app/compose.yml` — Docker Compose with:
  - **nginx (frontend)**: serves the React build at `/` and proxies `/api/` to backend (ports **80/443** exposed)
  - **backend**: Spring Boot app (port **8080** inside the network)
  - **postgres**: PostgreSQL database (persistent volume)
  - **redis**: Redis cache (persistent volume)
  - **ngrok (v3)**: exposes the HTTPS entrypoint to the Internet (requires `NGROK_AUTHTOKEN`)
- `Java-app/nginx/default.conf` — nginx config for `/` + `/api/`
- `Java-app/nginx/certs/` — TLS cert/key used by nginx (for local HTTPS)

## How to run

Prereqs: Docker + Docker Compose.

Add envs and generate certificates for nginx.

```bash
cd Java-app
docker compose up --build
```

Then open:
- `https://localhost` (accept the self-signed certificate), or
- map a local domain (e.g. `javaapp`) to your host/IP and open it via HTTPS.

ngrok URL:

```bash
docker compose logs -f ngrok
```

Stop and remove containers/volumes:

```bash
docker compose down -v
```

## Notes

- On an Ubuntu host, the task also requires the firewall to keep **22/80/443** open.

