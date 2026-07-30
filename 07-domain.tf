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
