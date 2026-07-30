variable "LINODE_API_KEY" {
  description = "The key to the Linode API"
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

variable "qha_admin_backend_port" {
  description = "Port on the WireGuard client tunnel IP that nginx proxies HTTPS traffic to (the admin console's own HTTPS listener)."
  type        = number
  default     = 9443
}
