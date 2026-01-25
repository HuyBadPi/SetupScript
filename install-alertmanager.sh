#!/bin/bash
set -e

# =========================
# REQUIRE ROOT
# =========================
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# =========================
# INSTALL ALERTMANAGER
# =========================
echo "=== Check Alertmanager installation ==="
if dpkg -s prometheus-alertmanager >/dev/null 2>&1; then
  echo "Alertmanager already installed"
else
  echo "Installing Alertmanager..."
  apt update
  apt install -y prometheus-alertmanager
fi

prometheus-alertmanager --version

# =========================
# PROMETHEUS ALERT RULES
# =========================
echo "=== Create Prometheus alert rules ==="
mkdir -p /etc/prometheus/rules

cat <<'EOF' > /etc/prometheus/rules/vm-alerts.yml
groups:
- name: vm-alerts
  rules:
  - alert: HighCPUUsage
    expr: 100 - (avg by(instance)(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "CPU > 90% trên {{ $labels.instance }}"
      description: "CPU đang vượt 90% trong hơn 2 phút"

  - alert: VMDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "VM {{ $labels.instance }} bị DOWN"
      description: "Exporter không phản hồi, VM có thể đã tắt"
EOF

# =========================
# PROMETHEUS CONFIG
# =========================
echo "=== Ensure Prometheus loads rules & Alertmanager ==="
PROM_FILE="/etc/prometheus/prometheus.yml"

if ! grep -q "alertmanagers:" "$PROM_FILE"; then
cat <<EOF >> "$PROM_FILE"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"
EOF
fi

echo "=== Validate Prometheus config ==="
promtool check config "$PROM_FILE"
promtool check rules /etc/prometheus/rules/*.yml

echo "=== Restart Prometheus ==="
systemctl restart prometheus

# =========================
# ALERTMANAGER CONFIG
# =========================
echo "=== Configure Alertmanager ==="

# DATA PATH
mkdir -p /var/lib/prometheus/alertmanager

cat <<'EOF' > /etc/prometheus/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'tranhuylqd@gmail.com'
  smtp_auth_username: 'tranhuylqd@gmail.com'
  smtp_auth_password: 'APP_PASSWORD_16_CHARS'

route:
  receiver: 'email-alert'

receivers:
- name: 'email-alert'
  email_configs:
  - to: 'tranhuylqd@gmail.com'
EOF

# PERMISSIONS (CRITICAL)
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

# =========================
# ALERTMANAGER ARGS (CRITICAL)
# =========================
echo "=== Configure Alertmanager runtime args ==="

cat <<'EOF' > /etc/default/prometheus-alertmanager
ARGS="--config.file=/etc/prometheus/alertmanager.yml --storage.path=/var/lib/prometheus/alertmanager"
EOF

# =========================
# RESTART ALERTMANAGER
# =========================
echo "=== Restart Alertmanager ==="
systemctl restart prometheus-alertmanager

systemctl status prometheus-alertmanager --no-pager

echo "=== DONE: Alertmanager + Prometheus alerts configured successfully ==="
