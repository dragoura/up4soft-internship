# ELK Stack Setup Guide

This guide explains how to set up Elasticsearch, Fluentd, and Kibana with Java application.

## Overview

The setup includes:
- **Elasticsearch 8.11.0**: Stores logs with persistent volumes
- **Kibana 8.11.0**: Web UI for log visualization
- **Fluentd**: Collects and parses logs from containers
- **Nginx on server**: Routes traffic to containers and proxies Kibana

## Architecture

```
Internet → Server Nginx (80/443) → App Nginx Container (8080/8443) → Backend
                                  → Kibana Container (5601)
```

Logs flow:
```
Containers → Fluentd → Elasticsearch → Kibana
```

## Step 1: Update Docker Compose

The `compose.yml` has been updated with:
- Elasticsearch with persistent volume (`esdata`)
- Kibana connected to Elasticsearch
- Fluentd configured to collect logs
- Nginx container moved to ports 8080/8443
- Logging drivers configured for backend and frontend containers

## Step 2: Build and Start Services

```bash
cd app
docker-compose build
docker-compose up -d
```

## Step 3: Verify Services

Check that all services are running:
```bash
docker-compose ps
```

Verify Elasticsearch is healthy:
```bash
curl http://localhost:9200/_cluster/health
```

Verify Kibana is accessible:
```bash
curl http://localhost:5601
```

## Step 4: Install Nginx on Ubuntu Server

```bash
sudo apt update
sudo apt install nginx -y
```

## Step 5: Configure Server Nginx

1. Copy the server nginx configuration:
```bash
sudo cp nginx-server.conf /etc/nginx/sites-available/your-app-name
```

2. Edit the configuration file and replace:
   - `your-app-domain.com` → your actual app domain
   - `kibana.your-domain.com` → your actual Kibana domain

3. Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/your-app-name /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default  
```

4. Test and reload:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

## Step 6: SSL Certificates

Follow the instructions in `SSL_SETUP.md` to obtain Let's Encrypt certificates.

Quick setup:
```bash
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d your-app-domain.com -d www.your-app-domain.com
sudo certbot --nginx -d kibana.your-domain.com
```

## Step 7: Verify Log Collection

### Check Fluentd logs:
```bash
docker-compose logs fluentd
```

### Check Elasticsearch indices:
```bash
curl http://localhost:9200/_cat/indices?v
```

You should see indices:
- `java-backend-logs-*` (Java application logs)
- `nginx-logs-*` (Nginx access/error logs)
- `docker-containers-logs-*` (Postgres, Redis, etc.)

## Step 8: Access Kibana

1. Open browser: `https://kibana.your-domain.com`
2. Go to **Stack Management** → **Index Patterns**
3. Create index patterns:
   - `java-backend-*` (Java logs)
   - `nginx-*` (Nginx logs)
   - `docker-containers-*` (Other containers)

## Log Parsing Details

### Java Backend Logs
- **Source**: Fluentd forward protocol (directly from Java app via FluentLogger)
- **Format**: Structured JSON logs with fields: `level`, `layer`, `destination`, `message`, `obj`
- **Index**: `java-backend-logs-YYYY.MM.DD`
- **Fields parsed**: level, layer, destination, message, obj, timestamp
- **Note**: Backend sends logs directly to Fluentd on port 24224, NOT via Docker logging driver

### Nginx Logs
- **Source**: Docker logging driver
- **Format**: Nginx access logs (combined format)
- **Index**: `nginx-logs-YYYY.MM.DD`
- **Fields parsed**: remote_addr, method, request, status, body_bytes_sent, http_referer, http_user_agent, time

### Other Container Logs
- **Source**: Docker logging driver
- **Containers**: postgres, redis, elasticsearch, kibana, fluentd
- **Index**: `docker-containers-logs-YYYY.MM.DD`
- **Format**: Raw container logs

## Troubleshooting

### Fluentd not receiving logs
- Check Fluentd container logs: `docker-compose logs fluentd`
- Verify port 24224 is exposed: `netstat -tuln | grep 24224`
- For backend logs: Verify `FLUENTD_HOST=fluentd` in backend environment variables
- For other containers: Check Docker logging driver configuration in `compose.yml`
- Test backend connection: `docker-compose exec backend ping fluentd`

### Elasticsearch connection issues
- Verify Elasticsearch is healthy: `curl http://localhost:9200`
- Check network connectivity: `docker-compose exec fluentd ping elasticsearch`
- Review Elasticsearch logs: `docker-compose logs elasticsearch`

### Kibana not showing data
- Verify index patterns are created correctly
- Check time range in Kibana (default is last 15 minutes)
- Verify logs are being sent: `curl http://localhost:9200/_cat/indices?v`

### Nginx routing issues
- Test nginx config: `sudo nginx -t`
- Check server nginx logs: `sudo tail -f /var/log/nginx/error.log`
- Verify container ports: `docker-compose ps`

## Important Notes

1. **Port Changes**: The nginx container now uses ports 8080/8443 instead of 80/443
2. **Persistent Data**: Elasticsearch data is stored in the `esdata` volume and persists across reboots
3. **Log Buffers**: Fluentd buffers are stored in the `fluentd_buffers` volume
4. **Backend Port**: Verify the backend port in `nginx/default.conf` matches your backend service port (currently shows 8088, but compose.yml exposes 8081)

## Environment Variables

Make sure your `.env` file includes (for backend to connect to Fluentd):
```
FLUENTD_HOST=fluentd
FLUENTD_PORT=24224
FLUENTD_ENABLED=true
```

**Important**: The backend uses FluentLogger to send logs directly to Fluentd via the forward protocol. The `FLUENTD_HOST` should be `fluentd` (the service name) so the backend container can reach Fluentd via Docker network.

## Next Steps

1. Configure Kibana dashboards for log visualization
2. Set up alerts based on log patterns
3. Configure log retention policies in Elasticsearch
4. Set up log rotation if needed

