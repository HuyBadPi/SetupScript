#!/bin/bash
# This script installs Prometheus on a Linux system.

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

echo "Enter link of Prometheus tar.gz file (e.g. https://github.com/prometheus/prometheus/releases/download/v3.8.1/prometheus-3.8.1.linux-amd64.tar.gz) : "
read PROMETHEUS_LINK

PROMETHEUS_USER="prometheus"
PROMETHEUS_GROUP="prometheus"

PROMETHEUS_DIR="/etc/prometheus"
PROMETHEUS_DATA_DIR="/var/lib/prometheus"
PROMETHEUS_BIN_DIR="/usr/local/bin"

MY_LOCAL_IP=$(hostname -I | awk '{print $1}')

# Create Prometheus user and group
if ! id -u $PROMETHEUS_USER >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin $PROMETHEUS_USER
fi

for cmd in wget tar; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "$cmd not installed"
    exit 1
  }
done


# Download and extract Prometheus
ARCH=$(uname -m)
case $ARCH in
  x86_64) ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  *) echo "Unsupported arch"; exit 1 ;;
esac

TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

wget --spider "$PROMETHEUS_LINK" || {
  echo "Invalid Prometheus download link"
  exit 1
}

wget $PROMETHEUS_LINK -O prometheus.tar.gz
tar -xzf prometheus.tar.gz
cd prometheus-*.linux-$ARCH

# Move binaries
mv prometheus promtool $PROMETHEUS_BIN_DIR/

# Create necessary directories
mkdir -p $PROMETHEUS_DIR
chown -R prometheus:prometheus $PROMETHEUS_DIR
chmod -R 750 $PROMETHEUS_DIR
mkdir -p $PROMETHEUS_DATA_DIR
chmod -R 750 $PROMETHEUS_DATA_DIR

# Move configuration files
mv prometheus.yml $PROMETHEUS_DIR/

# Set ownership
chown -R $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_DIR
chown -R $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_DATA_DIR
chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_BIN_DIR/prometheus
chown $PROMETHEUS_USER:$PROMETHEUS_GROUP $PROMETHEUS_BIN_DIR/promtool

# Clean up
cd ~
rm -rf $TEMP_DIR

# Create systemd service file
bash -c 'cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ 
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF'

# Reload systemd and start Prometheus service
systemctl daemon-reload
promtool check config /etc/prometheus/prometheus.yml
systemctl enable prometheus
systemctl start prometheus 
echo "Prometheus installation completed and service started."
echo "You can access Prometheus at http://$MY_LOCAL_IP:9090"
