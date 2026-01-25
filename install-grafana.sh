#!/bin/bash
# Grafana installation script (manual .deb)

set -euo pipefail

echo "This script installs Grafana on a Linux system."

# ===== Root check =====
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# ===== Variables =====
MY_LOCAL_IP=$(hostname -I | awk '{print $1}')
ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH=amd64 ;;
  *) echo "Unsupported architecture"; exit 1 ;;
esac

echo "Enter the Grafana download URL (e.g, https://dl.grafana.com/grafana-enterprise/release/12.3.1/grafana-enterprise_12.3.1_20271043721_linux_amd64.deb):"
read -r GRAFANA_URL

# ===== Dependency check =====
for cmd in curl gpg apt-get systemctl wget dpkg; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "$cmd not installed"
    exit 1
  }
done

dpkg -l grafana >/dev/null 2>&1 && {
  echo "Grafana already installed. Skipping installation."
  exit 0
}

# ===== Install dependencies =====
apt update -y
apt-get install -y adduser libfontconfig1 musl

# ===== Download Grafana =====
wget --spider "$GRAFANA_URL" || {
  echo "Grafana download link invalid"
  exit 1
}

wget -O grafana.deb "$GRAFANA_URL"

# ===== Install Grafana =====
dpkg -i "grafana.deb"

# ===== Enable & start =====
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server

# Cleanup
rm -f grafana.deb

# ===== Completion message =====
echo
echo "Grafana installation completed"
echo "Access Grafana at: http://$MY_LOCAL_IP:3000"
echo "Default credentials - Username: admin | Password: admin"