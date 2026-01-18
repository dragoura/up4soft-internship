variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_fingerprint" {
  description = "SSH public key fingerprint registered in DigitalOcean"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to the SSH private key used by Ansible"
  type        = string
}
