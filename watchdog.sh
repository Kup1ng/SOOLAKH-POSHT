#!/usr/bin/env bash
set -euo pipefail

# ---------- Config ----------
WATCHDOG_URL="https://raw.githubusercontent.com/Kup1ng/SOOLAKH-POSHT-DOCTOR/main/none-stop.sh"
DEST_SCRIPT="/usr/local/bin/backhaul-all-watchdog.sh"
SERVICE_FILE="/etc/systemd/system/backhaul-watchdog.service"

# ---------- Root check ----------
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (e.g. with sudo)."
  exit 1
fi

echo "🔽 Downloading backhaul watchdog script from GitHub..."
curl -fsSL "$WATCHDOG_URL" -o "$DEST_SCRIPT"

echo "🔐 Making script executable..."
chmod +x "$DEST_SCRIPT"

echo "📝 Writing systemd unit file for backhaul-watchdog.service..."
cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Universal Watchdog for all backhaul-* services
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/backhaul-all-watchdog.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "🔄 Reloading systemd units..."
systemctl daemon-reload

echo "🚀 Enabling and starting backhaul-watchdog.service..."
systemctl enable --now backhaul-watchdog.service

echo "✅ Watchdog is now active. Status:"
systemctl status backhaul-watchdog.service --no-pager -n 8
