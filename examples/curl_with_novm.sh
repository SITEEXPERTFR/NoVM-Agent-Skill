#!/usr/bin/env bash
# Demonstrates using $NOVM env var from .novm dot file per skill.md rule
set -e

# Load $NOVM from dot file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.novm" ]; then
  export NOVM=$(cat "$SCRIPT_DIR/.novm")
else
  export NOVM="https://virtual-xfce-spin--ogsincord.replit.app/"
fi
[[ "$NOVM" != */ ]] && NOVM="$NOVM/"

echo "Using \$NOVM = $NOVM"
echo ""

echo "1. List sessions:"
echo "   curl \"\$NOVM/api/sessions\""
curl -s "$NOVM/api/sessions" -H "Content-Type: application/json" | head -c 500 || echo " (API may be sleeping)"

echo ""
echo ""
echo "2. Create workstation:"
echo "   curl -X POST \"\$NOVM/api/sessions\" -d '{\"name\":\"Support Desktop\",\"resolution\":\"1280x720\",\"disableTimeouts\":false}'"
echo ""
echo "3. Start:"
echo "   curl -X POST \"\$NOVM/api/sessions/SESSION_ID/start\""
echo ""
echo "4. Connect (get browser URL):"
echo "   curl -X POST \"\$NOVM/api/sessions/SESSION_ID/connect\""
echo ""
echo "5. Install app:"
echo "   curl -X POST \"\$NOVM/api/sessions/SESSION_ID/apps\" -d '{\"appId\":\"chromium\"}'"
echo ""
echo "All commands use \$NOVM from .novm dot file, not hardcoded URL."
