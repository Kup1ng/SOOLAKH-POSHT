#!/usr/bin/env bash
PATTERN='backhaul-*.service'
TAIL_LINES=100
SLEEP=10

# ───── status message lists ─────
WAIT_PATTERNS=(
  "[INFO] waiting for ws control channel connection"
  "[INFO] attempting to establish a new TCPMUX control channel connection..."
  "[INFO] control channel not found, attempting to establish a new session"

)

OK_PATTERNS=(
  "[INFO] control channel established successfully"
)

ERR_PATTERNS=(
  "[ERROR]"
)

LOG() { echo "$(date '+%F %T') $1" >> /var/log/backhaul_watchdog.log; }

matches_any() {              # $1=text  $2..=patterns
  local txt="$1"; shift
  for p in "$@"; do
    [[ "$txt" == *"$p"* ]] && return 0
  done
  return 1
}

while true; do
  mapfile -t SERVICES < <(systemctl list-unit-files --type=service "$PATTERN" --no-legend | awk '{print $1}')

  for SERVICE in "${SERVICES[@]}"; do
    # restart if service inactive but enabled
    if ! systemctl is-active --quiet "$SERVICE"; then
      if systemctl is-enabled --quiet "$SERVICE"; then
        LOG "[$SERVICE] inactive → restarting"
        systemctl restart "$SERVICE"
      fi
      continue
    fi

    recent=$(journalctl -u "$SERVICE" -n "$TAIL_LINES" --no-pager | tac | head -n 200)  # search window

    if matches_any "$recent" "${WAIT_PATTERNS[@]}" "${ERR_PATTERNS[@]}"; then
      LOG "[$SERVICE] WAIT/ERROR detected → waiting $SLEEP s"
      sleep "$SLEEP"

      current=$(journalctl -u "$SERVICE" -n "$TAIL_LINES" --no-pager | tac | head -n 200)

      if matches_any "$current" "${OK_PATTERNS[@]}"; then
        LOG "[$SERVICE] recovered"
      else
        LOG "[$SERVICE] still down → restarting"
        systemctl restart "$SERVICE"
      fi
    fi
  done

  sleep "$SLEEP"
done
