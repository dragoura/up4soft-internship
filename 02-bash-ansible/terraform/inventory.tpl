[workers]
${droplet_name} ansible_host=${droplet_ip}

[all:children]
workers

[all:vars]
ansible_ssh_private_key_file=${ssh_private_key_path}                                                        