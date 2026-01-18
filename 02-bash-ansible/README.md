# 02 — Bash + Ansible

This folder contains the configs I created while completing the **Ansible + Bash** task: I had to create roles and scripts to set up Linux server to deploy Java + JavaScript + Nginx + PostgreSQL + Redis app there.

Solution:

- **Bash**: scripts to bootstrap a fresh Ubuntu host, install dependencies, and deploy the **Java-app** environment from task №1 (**Linux Web Server**) in **HTTP mode** (SSL is optional).
- **Ansible**: same setup via playbooks + separate roles (SSH, firewall, PostgreSQL, Redis, backend, frontend, nginx).
- **Terraform**: provisions a DigitalOcean droplet and generates `ansible/inventory.ini`.

## Folder structure

- `makefile` — convenience targets for Terraform + Ansible
- `terraform/` — DigitalOcean droplet + generates Ansible inventory
- `ansible/` — playbooks (`main.yaml`) and roles
- `bash/` — step-by-step scripts + `run_all.sh`

## Quick start (Terraform + Ansible)

Prereqs: `terraform`, `ansible`, a DigitalOcean account/token, and a DO SSH key.

1) Provision droplet and generate inventory:

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

2) Configure the host with Ansible:

```bash
cd ../ansible
ansible-playbook main.yaml
# If vault vars are required:
# ansible-playbook main.yaml --vault-password-file vaultpass
```

Or run both from this folder:

```bash
make all
```

## Bash approach

1) Update configuration:
- `bash/config.env`
- (optional SSL) `bash/config_ssl.env`

2) On the target server, run the full flow:

```bash
cd bash
sudo bash run_all.sh
```

Optional SSL setup (Let’s Encrypt):

```bash
cd bash
sudo bash 05_nginx_ssl.sh
```

Helper scripts exist for uploading + running remotely:
- `bash/remote_deploy.sh` (HTTP)
- `bash/remote_deploy_ssl.sh` (HTTPS)

> Note: remote deploy scripts contain machine-specific absolute `LOCAL_*` paths — adjust them before use.
