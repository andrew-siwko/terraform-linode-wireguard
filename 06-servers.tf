resource "linode_instance" "asiwko-qha-proxy-01" {
  image  = "linode/rocky9"
  label  = "asiwko-qha-proxy-01"
  region = var.instance_region
  type   = var.instance_type
  authorized_keys = [
    trimspace(file("/container_shared/ansible/ansible_rsa.pub")),
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFuRdNKH8yZYKOhW3FwMFgyNg8JwMJ3qYIKVjauka1fG asiwk@DESKTOP-DADDY",
  ]
  root_pass        = trimspace(file("/container_shared/ansible/linode-root-pw.txt"))
  stackscript_id   = linode_stackscript.qha_proxy_install.id
  stackscript_data = {}
}
