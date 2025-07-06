#!/usr/bin/env bash
PATTERN='backhaul-*.service'   # هر سرویسی که این الگو را داشته باشد
TAIL_LINES=100                 # بین ۱۰۰ خط آخر لاگ جست‌وجو می‌کنیم
SLEEP=10                       # دورهٔ چک به ثانیه

ERR_PATTERN='\[ERROR\]'
WAIT_PATTERN='\[INFO\] waiting for ws control channel connection'
OK_PATTERN='\[INFO\] control channel established successfully'

LOG() { echo "$(date '+%F %T') $1" >> /var/log/backhaul_watchdog.log; }

while true; do
  # فهرست سرویس‌هایی که NAMEشان با backhaul- شروع می‌شود (فعال یا غیرفعال)
  mapfile -t SERVICES < <(
      systemctl list-unit-files --type=service "$PATTERN" --no-legend \
      | awk '{print $1}'
  )

  for SERVICE in "${SERVICES[@]}"; do
    # اگر سرویس غیر‌فعال است ولی enable شده، راه‌اندازی‌اش کن
    if ! systemctl is-active --quiet "$SERVICE"; then
      if systemctl is-enabled --quiet "$SERVICE"; then
        LOG "[$SERVICE] inactive → restarting"
        systemctl restart "$SERVICE"
      fi
      # ادامه؛ چون وقتی inactive بود همین‌جا رسیدگی شد
      continue
    fi

    # تازه‌ترین پیام کلیدی در ۱۰۰ خط اخیر لاگ
    recent=$(journalctl -u "$SERVICE" -n "$TAIL_LINES" --no-pager \
             | tac | grep -m1 -E "$ERR_PATTERN|$WAIT_PATTERN|$OK_PATTERN" || true)

    # اگر WAIT یا ERROR دیده شد → ۱۰ ثانیه صبر و بازنگری
    if [[ $recent =~ $WAIT_PATTERN || $recent =~ $ERR_PATTERN ]]; then
      LOG "[$SERVICE] WAIT/ERROR → waiting $SLEEP s"
      sleep "$SLEEP"

      current=$(journalctl -u "$SERVICE" -n "$TAIL_LINES" --no-pager \
               | tac | grep -m1 -E "$ERR_PATTERN|$WAIT_PATTERN|$OK_PATTERN" || true)

      if [[ $current =~ $OK_PATTERN ]]; then
        LOG "[$SERVICE] recovered"
      else
        LOG "[$SERVICE] still down → restarting"
        systemctl restart "$SERVICE"
      fi
    fi
  done

  sleep "$SLEEP"
done
