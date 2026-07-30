# Terraform code to set up the qha-admin public reverse proxy

A Linode Nanode running nginx + certbot + WireGuard, so external clients can
reach the in-cluster qha-admin-console over a real domain and a real
Let's Encrypt certificate, without opening any inbound port on the home
network. The WireGuard tunnel is always initiated outbound from the home
cluster; this instance only ever receives the connection.

See `08-outputs.tf` for the server's WireGuard public key retrieval step,
needed to configure the in-cluster WireGuard client.