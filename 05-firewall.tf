resource "linode_firewall" "qha_proxy_firewall" {
  label = "qha_proxy_firewall"

  inbound {
    label    = "allow-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }
  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # certbot HTTP-01 challenge + redirect to HTTPS.
  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # The actual public-facing proxy traffic.
  inbound {
    label    = "allow-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "443"
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  # WireGuard tunnel from the home cluster. Left open to 0.0.0.0/0 rather
  # than restricted to a source IP: WireGuard's own handshake already
  # requires the correct private key regardless of source, and restricting
  # by IP would be fragile against a dynamic residential address anyway.
  inbound {
    label    = "allow-wireguard"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = var.wireguard_listen_port
    ipv4     = ["0.0.0.0/0"]
    ipv6     = ["::/0"]
  }

  inbound_policy = "DROP"

  outbound_policy = "ACCEPT"

  linodes = [linode_instance.asiwko-qha-proxy-01.id]
}
