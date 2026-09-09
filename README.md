## Up4Soft internship — DevOps tasks

This repository contains my solutions for the Up4Soft internship DevOps assignments around a demo **Java + React** application (https://github.com/Up4Soft-LLC/Java-app). I used **DigitalOcean Droplets** to deploy app and additional features.

### What’s included

- **`01-linux-web-server/`**: systemd service for the backend + Nginx reverse proxy (HTTPS, static frontend, `/api` proxy)
- **`02-bash-ansible/`**: Terraform (DO droplet) + Ansible roles + Bash scripts to bootstrap and deploy the full stack
- **`03-docker/`**: Dockerfiles + Docker Compose to run the app with Postgres + Redis + Nginx
- **`04-ci-cd/`**: GitLab CI/CD pipeline to build/push images and deploy via Docker Compose
- **`05-monitoring/`**: Prometheus + Grafana monitoring with app/exporter metrics (Actuator, node_exporter, cAdvisor, postgres_exporter)
- **`06-elk/`**: EFK/ELK logging pipeline (Fluentd → Elasticsearch → Kibana) + Nginx proxy configs
- **`07-k8s/`**: kind cluster with the app on Kubernetes — Bitnami charts for Postgres/Redis, own charts for backend and frontend, ingress routing by hostname, a `pg_dump` CronJob on a Retain volume, and a read-only ServiceAccount
