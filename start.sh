#!/bin/bash

set -e

echo "[start.sh] ▶ Checking required config files..."
CONFIG_FILES=(
  "/config/pptpd.conf"
  "/config/chap-secrets"
  "/config/pptpd-options"
  "/config/vsftpd.conf"
)
for file in "${CONFIG_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "[ERROR] Required config file '$file' not found"
    exit 1
  fi
done

echo "[start.sh] ▶ Checking /dev/ppp..."
if [ ! -e /dev/ppp ]; then
  echo "[start.sh] ▶ /dev/ppp not found, creating it..."
  mknod /dev/ppp c 108 0 || {
    echo "[ERROR] Failed to create /dev/ppp"
    exit 1
  }
  chmod 600 /dev/ppp
else
  echo "[start.sh] ▶ /dev/ppp already exists."
fi

echo "[start.sh] ▶ Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[start.sh] ▶ Linking external config files..."
ln -sf /config/pptpd.conf /etc/pptpd.conf
ln -sf /config/chap-secrets /etc/ppp/chap-secrets
ln -sf /config/pptpd-options /etc/ppp/pptpd-options
cp /config/vsftpd.conf /etc/vsftpd.conf

echo "[start.sh] ▶ Setting proper access rights on vsftpd.conf..."
chmod 600 /etc/vsftpd.conf
chown root:root /etc/vsftpd.conf

echo "[start.sh] ▶ Setting up FTP user..."
# Create FTP user only if not exists
if ! id -u uploaduser &>/dev/null; then
    useradd -d /var/ftp/upload -s /sbin/nologin uploaduser
    echo "uploaduser:uploadpass" | chpasswd
fi

echo "[start.sh] ▶ Switching iptables to legacy mode..."
update-alternatives --set iptables /usr/sbin/iptables-legacy || {
  echo "[ERROR] Failed to switch to iptables-legacy"
  exit 1
}

echo "[start.sh] ▶ Setting iptables default policies..."
iptables -F
iptables -P INPUT ACCEPT
iptables -P OUTPUT ACCEPT
iptables -P FORWARD DROP

echo "[start.sh] ▶ Allow VPN client to access container FTP only..."
iptables -A INPUT -s 192.168.100.0/24 -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -s 192.168.100.0/24 -p tcp --dport 20 -j ACCEPT
iptables -A INPUT -s 192.168.100.0/24 -p tcp --dport 30000:30009 -j ACCEPT

# echo "[start.sh] ▶ Starting vsftpd..."
service vsftpd start

echo "[start.sh] ▶ Starting pptpd..."
exec /usr/sbin/pptpd --fg