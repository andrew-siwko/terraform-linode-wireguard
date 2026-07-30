output "linode_instance_public_ip" {
  value = one(linode_instance.asiwko-qha-proxy-01.ipv4)
}

output "next_step" {
  value = "SSH in and run: cat /etc/wireguard/server_public.key -- then set that as the peer public key in the in-cluster WireGuard client config, with endpoint ${one(linode_instance.asiwko-qha-proxy-01.ipv4)}:${var.wireguard_listen_port}. Once the client exists, re-apply this project with wireguard_client_public_key set to the client's public key."
}
