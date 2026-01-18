# 01 — Linux Web Server

This folder contains the configs I created while completing the **Linux Web Server** task: running the Java backend as a `systemd` service and serving the frontend via `nginx` with HTTPS + reverse proxying API requests.

## What was done

- **Backend as a service**: run the Java `.jar` via `systemd` and keep it restarted on failure.
- **Web server + HTTPS**: configure `nginx` to:
  - redirect `http` → `https`
  - serve the frontend build as static files (SPA routing)
  - proxy `/api/` requests to the backend on localhost

## Files in this folder

- **`javaapp-backend.service`**: `systemd` unit for the Java backend.
  - Uses env file: `/opt/javaapp/backend/.env`
  - Runs jar: `/opt/javaapp/backend/app.jar`
  - Working dir: `/opt/javaapp/backend`
  - Runs as: `www-data:www-data`

- **`javaapp.conf`**: `nginx` server block.
  - Domain: `up4soft.julia-b.work` (+ `www`)
  - Frontend root: `/var/www/javaapp/build`
  - API proxy: `http://127.0.0.1:8080` (for `/api/`)
  - TLS cert paths are **Certbot-managed** under `/etc/letsencrypt/...`

## How to apply (quick reference)

### 1) Backend (`systemd`)

```bash
sudo cp javaapp-backend.service /etc/systemd/system/javaapp-backend.service
sudo systemctl daemon-reload
sudo systemctl enable --now javaapp-backend
sudo systemctl status javaapp-backend
```

Logs:

```bash
sudo journalctl -u javaapp-backend -f
```

### 2) Nginx vhost

```bash
sudo cp javaapp.conf /etc/nginx/sites-available/javaapp.conf
sudo ln -sf /etc/nginx/sites-available/javaapp.conf /etc/nginx/sites-enabled/javaapp.conf
sudo nginx -t
sudo systemctl reload nginx
```

## Notes / things to customize

- Update `server_name` in `javaapp.conf` to your domain.
- Ensure Let’s Encrypt certificates exist at the paths referenced in `javaapp.conf` (or adjust the paths).
- Make sure the frontend build is present at `/var/www/javaapp/build`.
- Make sure the backend listens on `127.0.0.1:8080` (as expected by the `/api/` proxy).

