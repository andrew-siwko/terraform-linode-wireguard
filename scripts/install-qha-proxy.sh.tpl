#!/bin/bash
# Installed via Linode StackScript (terraform-linode-wireguard).
# Sets up nginx + certbot + WireGuard to reverse-proxy public HTTPS traffic
# for ${qha_admin_fqdn} back through a tunnel to the in-cluster
# qha-admin-console, without opening any inbound port on the home network.
set -euo pipefail

exec > >(tee /var/log/qha-proxy-install.log) 2>&1

echo "=== Enabling EPEL (wireguard-tools, certbot) ==="
dnf -y install epel-release
dnf config-manager --set-enabled crb || true

echo "=== Installing nginx, certbot, wireguard-tools ==="
dnf -y install nginx certbot wireguard-tools

echo "=== Waiting for attached data volume ==="
VOLUME_DEV="/dev/disk/by-id/scsi-0Linode_Volume_qha-proxy-data"
mkdir -p /mnt/data
for i in $(seq 1 60); do
  if [ -e "$VOLUME_DEV" ]; then
    break
  fi
  sleep 5
done

if [ -e "$VOLUME_DEV" ]; then
  if ! blkid "$VOLUME_DEV" > /dev/null 2>&1; then
    echo "=== No filesystem found on volume - formatting (first attach) ==="
    mkfs.ext4 "$VOLUME_DEV"
  else
    echo "=== Existing filesystem found on volume - preserving data across rebuild ==="
  fi
  mount "$VOLUME_DEV" /mnt/data
  if ! grep -q "$VOLUME_DEV" /etc/fstab; then
    echo "$VOLUME_DEV /mnt/data ext4 defaults,noatime 0 2" >> /etc/fstab
  fi
else
  echo "WARNING: data volume not found after waiting - falling back to local instance disk (NOT persistent across rebuilds)"
fi

# /etc/wireguard and /etc/letsencrypt live on the persistent volume so
# neither the tunnel keypair nor the Let's Encrypt cert (rate-limited) has
# to be regenerated on every instance rebuild.
mkdir -p /mnt/data/wireguard /mnt/data/letsencrypt
rm -rf /etc/wireguard
ln -sfn /mnt/data/wireguard /etc/wireguard
rm -rf /etc/letsencrypt
ln -sfn /mnt/data/letsencrypt /etc/letsencrypt

echo "=== Disabling firewalld (relying on Linode Cloud Firewall instead) ==="
systemctl disable --now firewalld || true

echo "=== WireGuard server keypair ==="
if [ ! -f /etc/wireguard/server_private.key ]; then
  umask 077
  wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
else
  echo "=== Existing server keypair found on the data volume - reusing ==="
fi
SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private.key)
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)

echo "=== Writing WireGuard config ==="
cat > /etc/wireguard/wg0.conf << WGCONF
[Interface]
Address = ${wireguard_server_tunnel_ip}/24
ListenPort = ${wireguard_listen_port}
PrivateKey = $SERVER_PRIVATE_KEY
WGCONF

%{ if wireguard_client_public_key != "" }
cat >> /etc/wireguard/wg0.conf << WGPEER

[Peer]
PublicKey = ${wireguard_client_public_key}
AllowedIPs = ${wireguard_client_tunnel_ip}/32
WGPEER
%{ else }
echo "=== No client public key provided yet - wg0 will come up with no peers configured."
echo "    Re-apply Terraform with wireguard_client_public_key set once the in-cluster client exists. ==="
%{ endif }

chmod 600 /etc/wireguard/wg0.conf
systemctl enable --now wg-quick@wg0

echo "=== Writing minimal nginx config (HTTP challenge + redirect only, no cert yet) ==="
mkdir -p /var/www/certbot
cat > /etc/nginx/conf.d/qha-admin.conf << NGINXHTTP
server {
    listen 80;
    server_name ${qha_admin_fqdn};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}
NGINXHTTP

systemctl enable --now nginx
nginx -t && systemctl reload nginx

echo "=== Requesting Let's Encrypt certificate (no-op if a valid one already exists) ==="
certbot certonly --webroot -w /var/www/certbot -d ${qha_admin_fqdn} \
  --non-interactive --agree-tos -m ${letsencrypt_email} --keep-until-expiring

echo "=== Writing maintenance page for when the tunnel/cluster is unreachable ==="
cat > /usr/share/nginx/html/proxy-unavailable.html << 'MAINT'
<!DOCTYPE html>
<html><head><title>Temporarily Unavailable</title></head>
<body style="font-family: sans-serif; text-align: center; margin-top: 4em;">
<h1>QHA Admin Console Temporarily Unavailable</h1>
<p>The connection back to the home cluster is down. Please try again shortly.</p>
</body></html>
MAINT

echo "=== Writing full nginx config (HTTPS proxy to the WireGuard tunnel, graceful failure) ==="
cat > /etc/nginx/conf.d/qha-admin.conf << NGINXFULL
server {
    listen 80;
    server_name ${qha_admin_fqdn};

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name ${qha_admin_fqdn};

    ssl_certificate     /etc/letsencrypt/live/${qha_admin_fqdn}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${qha_admin_fqdn}/privkey.pem;

    error_page 502 503 504 /proxy-unavailable.html;
    location = /proxy-unavailable.html {
        root /usr/share/nginx/html;
        internal;
    }

    location / {
        proxy_pass https://${wireguard_client_tunnel_ip}:${qha_admin_backend_port};
        # The backend's own cert is self-signed (see admin-console/liberty/
        # server.xml) -- the WireGuard tunnel itself is already encrypted,
        # so this proxy_pass leg doesn't need its own cert trust chain.
        proxy_ssl_verify off;
        # Short timeouts are what makes "fail gracefully when the cluster is
        # unreachable" actually mean something -- without these, a dead
        # tunnel means visitors just hang instead of seeing the maintenance
        # page quickly.
        proxy_connect_timeout 5s;
        proxy_read_timeout 15s;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINXFULL

nginx -t && systemctl reload nginx

echo "=== Enabling certbot auto-renewal ==="
systemctl enable --now certbot-renew.timer 2>/dev/null || \
  (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'") | crontab -

echo "=== Done ==="
echo "Server WireGuard public key: $SERVER_PUBLIC_KEY"
echo "Configure the in-cluster WireGuard client with:"
echo "  endpoint: <this instance's public IP>:${wireguard_listen_port}"
echo "  peer public key: $SERVER_PUBLIC_KEY"
echo "  this server's tunnel address (client's AllowedIPs): ${wireguard_server_tunnel_ip}/32"
