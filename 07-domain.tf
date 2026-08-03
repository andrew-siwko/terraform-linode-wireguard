# ONLY for the siwko.org domain on Linode
# use this once to get the zone into the state file
# terraform import linode_domain.domain_name 3417841

# This will update the dns records in my siwko.org domain for the new instance.
resource "linode_domain" "dns_zone" {
  type        = "master"
  domain      = var.domain_name
  soa_email   = var.domain_soa_email
  refresh_sec = 30
  retry_sec   = 30
  ttl_sec     = 30
  lifecycle {
    prevent_destroy = true
  }
}

# IMPORTANT: qha-admin.siwko.org is currently managed by external-dns
# running in the home k8s cluster, pointing at the LAN LoadBalancer IP
# (192.168.50.202). Applying this record will start fighting with that one
# for the same name. Don't apply this until the WireGuard tunnel + nginx
# proxy chain is verified working end to end, and remove the
# external-dns.alpha.kubernetes.io/hostname annotation from the
# qha-admin-console Service at the same time as (or just before) applying
# this, so only one system is ever asserting the record.
resource "linode_domain_record" "qha_admin_a_record" {
  domain_id   = linode_domain.dns_zone.id
  name        = var.qha_admin_hostname
  record_type = "A"
  ttl_sec     = 30
  target      = one(linode_instance.asiwko-qha-proxy-01.ipv4)
}

# Same proxy chain as qha_admin_a_record (edge nginx's server_name is
# already a wildcard -- see install-qha-proxy.sh.tpl -- so this is the only
# change needed here; routing to the actual receiver Service happens via
# qha-webhook-receiver-ingress.yaml's Host-header rule once traffic reaches
# ingress-nginx). Deliberately its own explicit record, not a wildcard --
# see the comment at the bottom of this file for why a wildcard record was
# tried and reverted.
resource "linode_domain_record" "qha_webhooks_a_record" {
  domain_id   = linode_domain.dns_zone.id
  name        = var.qha_webhooks_hostname
  record_type = "A"
  ttl_sec     = 30
  target      = one(linode_instance.asiwko-qha-proxy-01.ipv4)
}

# siwko.net is a second, unrelated domain already hosted on the same Linode
# account/nameservers (confirmed via NS lookup) -- data source, not a
# managed resource like dns_zone above, so Terraform only reads its zone id
# and never tries to own/recreate the zone itself.
data "linode_domain" "dns_zone_net" {
  domain = var.domain_name_alt
}

# qha-admin.siwko.net answers the same proxy as qha-admin.siwko.org (see
# qha_admin_fqdn_alt in 04-stackscript.tf and the matching -d/server_name
# entries in the install script). Created directly via the Linode API
# during initial setup, before this resource existed in state -- run
# `terraform import linode_domain_record.qha_admin_net_a_record 1228111,45364910`
# once before the first apply that includes this resource, or Terraform
# will try to create a duplicate record and the API will reject it.
resource "linode_domain_record" "qha_admin_net_a_record" {
  domain_id   = data.linode_domain.dns_zone_net.id
  name        = var.qha_admin_hostname
  record_type = "A"
  ttl_sec     = 30
  target      = one(linode_instance.asiwko-qha-proxy-01.ipv4)
}

# siwko.com is a third, unrelated domain already hosted on the same Linode
# account/nameservers -- same data-source-not-managed-resource treatment as
# dns_zone_net above. No app hostname is added here yet: the proxy's
# wildcard cert and nginx server_name already cover *.siwko.com (see
# install-qha-proxy.sh.tpl) so a future app just needs its own explicit
# linode_domain_record here, same pattern as qha_admin_a_record/
# qha_admin_net_a_record.
data "linode_domain" "dns_zone_com" {
  domain = var.domain_name_com
}

# A wildcard A record (name = "*") was tried here and reverted -- DO NOT
# re-add one. This cluster's nodes carry "siwko.org" as a DNS search domain
# (pre-existing, unrelated to this project), and with ndots:5 in every
# pod's resolv.conf, in-cluster lookups that don't resolve within
# cluster.local fall through to the search-suffixed "...siwko.org" form
# before ever trying the bare name. A live "*.siwko.org" record matched
# that fallback query, so qha-tunnel-client's own socat (resolving
# ingress-nginx-controller.ingress-nginx.svc.cluster.local) silently
# started connecting to the *public* proxy IP instead of the real
# ClusterIP -- looping traffic back out to the internet and into the edge
# nginx's own port-80 redirect, which is what caused the ERR_TOO_MANY_
# REDIRECTS outage. Confirmed live, then rolled back (records 3417841/
# 45365040 and 1228111/45365041 deleted). The wildcard TLS cert
# ("wildcard-siwko" in install-qha-proxy.sh.tpl) and nginx's wildcard
# server_name are NOT affected by this and are safe to keep -- only an
# actual public DNS wildcard collides with the cluster's search domain.
# New app subdomains need one explicit linode_domain_record each, same
# pattern as qha_admin_a_record/qha_admin_net_a_record above.
