#!/bin/bash

set -e

echo "[start.sh] ▶ Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[start.sh] ▶ Linking external config files..."
ln -sf /config/pptpd.conf /etc/pptpd.conf
ln -sf /config/chap-secrets /etc/ppp/chap-secrets
ln -sf /config/pptpd-options /etc/ppp/pptpd-options
ln -sf /config/vsftpd.conf /etc/vsftpd.conf

echo "[start.sh] ▶ Setting up FTP user..."
# Create FTP user only if not exists
if ! id -u uploaduser &>/dev/null; then
    useradd -d /var/ftp/upload -s /sbin/nologin uploaduser
    echo "uploaduser:uploadpass" | chpasswd
fi

echo "[start.sh] ▶ Setting up iptables firewall rules..."
# Clear existing rules
iptables -F
iptables -A INPUT -i ppp+ -p tcp --dport 21 -j ACCEPT
iptables -A INPUT -i ppp+ -p tcp --dport 30000:30009 -j ACCEPT
iptables -A INPUT -i ! ppp+ -p tcp --dport 21 -j DROP
iptables -A INPUT -i ! ppp+ -p tcp --dport 30000:30009 -j DROP

echo "[start.sh] ▶ Starting vsftpd..."
service vsftpd start

echo "[start.sh] ▶ Starting pptpd..."
exec /usr/sbin/pptpd --fg
