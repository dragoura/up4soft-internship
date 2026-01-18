provision:
	cd terraform && terraform apply -auto-approve

configure:
	cd ansible && ansible-playbook main.yaml

all: provision configure

