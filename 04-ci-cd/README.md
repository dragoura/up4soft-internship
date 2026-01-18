# 04 — CI/CD

Solution for **CI/CD** task: create pipeline for the **Java + React** app from task №1 (**Linux Web Server**) which will automate creation and updating images to Gitlab registry.

### Requirements 

- **GitLab**: deploy 1 local VM and run GitLab via `docker-compose` (with a private Docker Registry).
- **Source code**: take the app from Java-app folder and push it into your GitLab repo via SSH.
- **Runtime**: set up `docker`/`docker-compose` for the app on the VM (frontend + backend + PostgreSQL + Redis).
- **Runners**: configure GitLab runners (docker and shell one) that listen to the GitLab repo.
- **CI**: compile sources, build Docker images (frontend + backend), push them to the GitLab Registry.
- **CD**: update the running architecture by changing Docker image tags according to the CI output.

### CI/CD implementation (GitLab)

The pipeline is defined in `app/.gitlab-ci.yml` and uses these stages:

- **compile**: `gradle bootJar` (backend) and `npm ci && npm run build` (frontend)
- **build**: Docker build + push to the GitLab Registry (`${CI_REGISTRY_IMAGE}`) tagged by commit SHA (`${CI_COMMIT_SHA}`)
- **test**: smoke test with `docker compose ... up -d` (Docker-in-Docker)
- **deploy**: `docker compose pull && docker compose up -d` on a shell runner (manual on `main`)

Runner tags used by jobs:

- **`docker`**: compile + build jobs
- **`dind`**: compose smoke test (`docker:dind`)
- **`shell`**: deploy job on the VM


### GitLab CI variables you’ll need

- **TLS**: `NGINX_CRT` and `NGINX_KEY` (used in CI to create `nginx/certs/server.crt` and `nginx/certs/server.key`)
- **Compose env**: variables referenced by `compose.production.yml` (for example `POSTGRES_*`, `REDIS_*`, `SERVER_PORT`, `FLUENTD_*`, `DEBUG`, plus `BACKEND_TAG` and `FRONTEND_TAG`)
