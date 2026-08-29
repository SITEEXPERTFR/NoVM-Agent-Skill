#!/usr/bin/env bash
# Example: Quickstart using $NOVM dot file
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/.novmrc"

echo "Using NOVM=$NOVM"
echo "Checking existing sessions..."
curl -s "$NOVM/api/sessions" -H "Content-Type: application/json" | python3 -m json.tool || echo "API not reachable (Replit sleeping?) - will try fallback"

echo ""
echo "Using novm.sh CLI (with auto fallback and 2 VM limit check):"
"$SCRIPT_DIR/novm.sh" list || true

echo ""
echo "To create:"
echo "  $SCRIPT_DIR/novm.sh quickstart \"My Desktop\""
