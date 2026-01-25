#!/bin/bash
# Node Exporter installation script

set -euo pipefail

echo "This script installs Prometheus Node Exporter."

# ===== Root check =====
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# ===== Variables =====
NODE_EXPORTER_USER="node_exporter"
NODE_EXPORTER_BIN="/usr/local/bin/node_exporter"
NODE_EXPORTER_VERSION="1.8.2"

# ===== Dependency check =====
for cmd in curl tar systemctl uname; do
  command -v $cmd >/dev/null 2>&1 || {
    echo "$cmd not installed"
    exit 1
  }
done

# ===== Idempotency check =====
if command -v node_exporter >/dev/null 2>&1; then
  echo "Node Exporter already installed. Skipping installation."
  exit 0
fi

# ===== Detect architecture =====
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

NODE_EXPORTER_TAR="node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TAR}"

# ===== Create user =====
if ! id -u "$NODE_EXPORTER_USER" >/dev/null 2>&1; then
  useradd --no-create-home --shell /usr/sbin/nologin "$NODE_EXPORTER_USER"
fi

# ===== Download & install =====
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"

curl -fLO "$NODE_EXPORTER_URL"
tar -xzf "$NODE_EXPORTER_TAR"

install -m 0755 "node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter" \
  "$NODE_EXPORTER_BIN"

chown "$NODE_EXPORTER_USER:$NODE_EXPORTER_USER" "$NODE_EXPORTER_BIN"

# ===== Cleanup =====
cd /
rm -rf "$TMP_DIR"

# ===== systemd service =====
cat >/etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$NODE_EXPORTER_USER
Group=$NODE_EXPORTER_USER
Type=simple
ExecStart=$NODE_EXPORTER_BIN
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ===== Enable & start =====
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# ===== Health check =====
sleep 2
systemctl is-active --quiet node_exporter || {
  echo "Node Exporter failed to start"
  exit 1
}

echo
echo "Node Exporter installation completed"
echo "Metrics available at: http://localhost:9100/metrics"
