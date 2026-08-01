locals {
  qha_admin_fqdn     = "${var.qha_admin_hostname}.${var.domain_name}"
  qha_admin_fqdn_alt = "${var.qha_admin_hostname}.${var.domain_name_alt}"
}

resource "linode_stackscript" "qha_proxy_install" {
  label       = "qha-proxy-install"
  description = "Installs nginx, certbot, and WireGuard to reverse-proxy public HTTPS traffic for the QHA admin console back through a tunnel to the home cluster."
  script = templatefile("${path.module}/scripts/install-qha-proxy.sh.tpl", {
    qha_admin_fqdn              = local.qha_admin_fqdn
    qha_admin_fqdn_alt          = local.qha_admin_fqdn_alt
    letsencrypt_email           = var.letsencrypt_email
    wireguard_listen_port       = var.wireguard_listen_port
    wireguard_server_tunnel_ip  = var.wireguard_server_tunnel_ip
    wireguard_client_tunnel_ip  = var.wireguard_client_tunnel_ip
    wireguard_client_public_key = var.wireguard_client_public_key
    qha_admin_backend_port      = var.qha_admin_backend_port
    linode_dns_token            = var.LINODE_DNS_TOKEN
  })
  images = ["linode/rocky9"]
}
