#!/usr/bin/env bash
# Garder Replit deployment awake - ping toutes les 5 min
# Usage: ./deploy/keep_alive.sh &
# Ou en cron: */5 * * * * /path/to/keep_alive.sh

set -e

# Load $NOVM from dot file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/.novmrc" 2>/dev/null || export NOVM="https://virtual-xfce-spin--ogsincord.replit.app/"

echo "[$(date)] Ping $NOVM/api/sessions..."

# Try primary
response=$(curl -s "$NOVM/api/sessions" --connect-timeout 10 --max-time 15 -H "Content-Type: application/json" || echo "FAIL")

if echo "$response" | grep -q "FAIL\|This app isn't live\|SSL_ERROR\|Could not resolve"; then
  echo "[$(date)] Primary down, trying fallback $NOVM_FALLBACK"
  curl -s "$NOVM_FALLBACK/api/sessions" --connect-timeout 10 --max-time 15 -H "Content-Type: application/json" | head -c 100 || true
else
  echo "[$(date)] OK: $(echo $response | head -c 100)"
fi

# Loop mode if arg is loop
if [ "$1" = "loop" ]; then
  echo "Mode loop - ping toutes les 5 min (Ctrl+C pour arrêter)"
  while true; do
    sleep 300
    "$0"
  done
fi
