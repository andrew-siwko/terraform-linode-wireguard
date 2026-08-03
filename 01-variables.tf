variable "LINODE_API_KEY" {
  description = "The key to the Linode API"
  type        = string
  sensitive   = true
}

variable "LINODE_DNS_TOKEN" {
  description = "Narrowly-scoped Linode Personal Access Token (Domains: Read/Write only, everything else None) used by certbot's DNS-01 challenge on the instance. Deliberately separate from LINODE_API_KEY, which has full account access -- this one ends up embedded in the rendered StackScript, so it shouldn't be the broad key."
  type        = string
  sensitive   = true
}

variable "instance_region" {
  description = "The region to create the instance"
  type        = string
  default     = "us-southeast"
}

variable "instance_type" {
  description = "Which instance type to create"
  type        = string
  default     = "g6-nanode-1"
}

variable "domain_name" {
  description = "The domain to create instance records in."
  type        = string
  default     = "siwko.org"
}

variable "domain_name_alt" {
  description = "Second domain the qha-admin proxy also answers for (same qha_admin_hostname label). Already Linode-hosted DNS, unrelated to domain_name's zone -- see 07-domain.tf for the record and DNS-01 cert-request loop in the install script for how it's proven."
  type        = string
  default     = "siwko.net"
}

variable "domain_name_com" {
  description = "Third domain the proxy's wildcard cert/nginx config covers, for future apps -- see 07-domain.tf. No app hostname lives here yet; unlike domain_name/domain_name_alt this doesn't have its own explicit qha-admin A record, just the zone data source so a future app can add one the same way."
  type        = string
  default     = "siwko.com"
}

variable "domain_soa_email" {
  description = "The domain manager e-mail address."
  type        = string
  default     = "asiwko@siwko.org"
}

variable "letsencrypt_email" {
  description = "E-mail address certbot registers the Let's Encrypt account under."
  type        = string
  default     = "asiwko@siwko.org"
}

variable "qha_admin_hostname" {
  description = "DNS label (under domain_name) that the public proxy answers for. Also used as the single hostname for internal LAN access, per the design decision to route all clients through the same URL."
  type        = string
  default     = "qha-admin"
}

variable "qha_webhooks_hostname" {
  description = "DNS label (under domain_name) for the in-cluster webhook receiver -- see qha_webhooks_a_record in 07-domain.tf. Only needed on domain_name (siwko.org, where Populi webhooks already land on lts.siwko.org); unlike qha_admin_hostname, this has no reason to also exist on domain_name_alt/domain_name_com."
  type        = string
  default     = "qha-webhooks"
}

variable "wireguard_listen_port" {
  description = "UDP port the WireGuard server listens on."
  type        = number
  default     = 51820
}

variable "wireguard_server_tunnel_ip" {
  description = "This Linode's address inside the WireGuard tunnel subnet."
  type        = string
  default     = "10.100.0.1"
}

variable "wireguard_client_tunnel_ip" {
  description = "The in-cluster WireGuard client's address inside the tunnel subnet. nginx proxies here."
  type        = string
  default     = "10.100.0.2"
}

variable "wireguard_client_public_key" {
  description = "Public key of the in-cluster WireGuard client peer. Leave blank for the first apply (before the client pod exists) -- wg0 comes up with no peers configured. Re-apply with the real value once the client is built. The server's own keypair is generated on first boot by the install script and never leaves the instance or touches Terraform state."
  type        = string
  default     = ""
}

variable "tunnel_backend_port" {
  description = "Port on the WireGuard client tunnel IP that nginx proxies plain-HTTP traffic to. Generic, not app-specific -- the in-cluster tunnel-client pod forwards this port straight through to ingress-nginx, which does its own Host-header-based routing to whichever app's Ingress resource matches the request. Must match LOCAL_PORT in qha-tunnel-client-deployment.yaml (same port, opposite ends of the WireGuard tunnel)."
  type        = number
  default     = 8080
}
