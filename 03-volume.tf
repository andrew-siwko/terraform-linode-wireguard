resource "linode_volume" "qha_proxy_data" {
  label     = "qha-proxy-data"
  region    = var.instance_region
  size      = 10
  linode_id = linode_instance.asiwko-qha-proxy-01.id
}
