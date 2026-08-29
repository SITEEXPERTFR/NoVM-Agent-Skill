#!/usr/bin/env bash
# NoVM Tool Installer
# Sets up $NOVM env var from .novm dot file

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOVM_URL="https://virtual-xfce-spin--ogsincord.replit.app/"
FALLBACK_URL="https://no-vm-desktop-fix--novm4.replit.app/"

echo "[NoVM] Installing NoVM tool with URL: $NOVM_URL"
echo "[NoVM] Fallback URL: $FALLBACK_URL"

# 1. Create .novm dot file (contains base URL, corresponds to $NOVM)
echo "[NoVM] Creating .novm dot file..."
echo "$NOVM_URL" > "$SCRIPT_DIR/.novm"
echo "  Created $SCRIPT_DIR/.novm with content: $(cat $SCRIPT_DIR/.novm)"

# 2. Create .novmrc for sourcing
echo "[NoVM] Creating .novmrc..."
cat > "$SCRIPT_DIR/.novmrc" <<EOF
# NoVM configuration - source this file to get \$NOVM
export NOVM="$NOVM_URL"
export NOVM_PRIMARY="$NOVM_URL"
export NOVM_FALLBACK="$FALLBACK_URL"
export NOVM_API="\$NOVM"
EOF
echo "  Created .novmrc"

# 3. Create .env
echo "[NoVM] Creating .env..."
cat > "$SCRIPT_DIR/.env" <<EOF
NOVM=$NOVM_URL
NOVM_PRIMARY=$NOVM_URL
NOVM_FALLBACK=$FALLBACK_URL
NOVM_API=$NOVM_URL
EOF
echo "  Created .env"

# 4. Make binaries executable
echo "[NoVM] Making binaries executable..."
chmod +x "$SCRIPT_DIR/novm.sh"
chmod +x "$SCRIPT_DIR/bin/novm" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/novm_client.py" 2>/dev/null || true
chmod +x "$SCRIPT_DIR/tools/agent_control.py" 2>/dev/null || true

# 5. Try to add to shell rc
SHELL_RC=""
if [ -f "$HOME/.bashrc" ]; then SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then SHELL_RC="$HOME/.zshrc"
fi

if [ -n "$SHELL_RC" ]; then
  if ! grep -q "NOVM=" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# NoVM - Workstation Manager" >> "$SHELL_RC"
    echo "export NOVM=\"$NOVM_URL\"" >> "$SHELL_RC"
    echo "export NOVM_FALLBACK=\"$FALLBACK_URL\"" >> "$SHELL_RC"
    echo "[NoVM] Added NOVM exports to $SHELL_RC"
  else
    echo "[NoVM] NOVM already in $SHELL_RC, updating..."
    # Update existing
    sed -i.bak "/NOVM=/d" "$SHELL_RC" 2>/dev/null || true
    echo "export NOVM=\"$NOVM_URL\"" >> "$SHELL_RC"
    echo "export NOVM_FALLBACK=\"$FALLBACK_URL\"" >> "$SHELL_RC"
  fi
fi

# 6. Export for current session
export NOVM="$NOVM_URL"
export NOVM_FALLBACK="$FALLBACK_URL"

echo ""
echo "[NoVM] Installation complete!"
echo ""
echo "Dot file: $SCRIPT_DIR/.novm -> corresponds to \$NOVM env var"
echo "Base URL: \$NOVM = $NOVM"
echo ""
echo "Usage:"
echo "  source .novmrc                    # Load \$NOVM in shell"
echo "  ./novm.sh list                    # List workstations"
echo "  ./novm.sh quickstart \"My Desktop\"  # Create+start+connect"
echo "  ./novm.sh connect SESSION_ID      # Get browser URL"
echo "  python3 novm_client.py list       # Python client"
echo "  bin/novm list                     # Short wrapper"
echo ""
echo "Test:"
echo "  echo \$NOVM"
echo "  curl \"\$NOVM/api/sessions\" -H \"Content-Type: application/json\""
echo ""
echo "Note: If API returns 'This app isn't live yet' or SSL errors,"
echo "      the Replit deployment may be sleeping. Fallback URL will be tried automatically."
