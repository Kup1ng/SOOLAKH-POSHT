#!/usr/bin/env bash
set -euo pipefail

# ---------- تنظیمات ----------
WATCHDOG_URL="https://raw.githubusercontent.com/Kup1ng/SOOLAKH-POSHT-DOCTOR/main/none-stop.sh"
DEST_SCRIPT="/usr/local/bin/backhaul-all-watchdog.sh"
SERVICE_FILE="/etc/systemd/system/backhaul-watchdog.service"

# ---------- چک دسترسی ----------
if [[ $EUID -ne 0 ]]; then
  echo "لطفاً با sudo یا به‌عنوان root اجرا کنید تا نگاه سگ راه بیفته." >&2
  exit 1
fi

echo "⬇️  در حال دانلود اسکریپت نگاه سگ از GitHub …"
curl -fsSL "$WATCHDOG_URL" -o "$DEST_SCRIPT"

echo "🔑 اعمال اجازهٔ اجرا برای نگاه سگ …"
chmod +x "$DEST_SCRIPT"

echo "📝 نوشتن/به‌روزرسانی واحد systemd مربوط به نگاه سگ …"
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

echo "🔄 بارگذاری واحدهای systemd برای نگاه سگ …"
systemctl daemon-reload

echo "🚀 فعال‌سازی و استارت نگاه سگ …"
systemctl enable --now backhaul-watchdog.service

echo "✅ نگاه سگ فعال شد. وضعیت فعلی:"
systemctl status backhaul-watchdog.service --no-pager -n 8
