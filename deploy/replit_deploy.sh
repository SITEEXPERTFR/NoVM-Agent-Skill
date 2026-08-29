#!/usr/bin/env bash
# Deploy NoVM to Replit - republier virtual-xfce-spin--ogsincord.replit.app
set -e

echo "=== Deploy Replit NoVM ==="
echo "URL cible: https://virtual-xfce-spin--ogsincord.replit.app/"
echo ""

# Vérifier si on est sur Replit
if [ -n "$REPL_ID" ]; then
  echo "✓ Détecté Replit env: $REPL_ID"
else
  echo "⚠ Pas sur Replit - ce script doit tourner sur Replit"
  echo "  Va sur https://replit.com -> ton projet virtual-xfce-spin"
  echo "  Puis clique Deploy -> Autoscale ou Reserved VM -> Publish"
  exit 1
fi

echo "Installation deps..."
# Installer XFCE deps si pas déjà fait
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  xvfb xfce4 xfce4-goodies xfce4-terminal thunar \
  x11vnc dbus-x11 pulseaudio pulseaudio-utils \
  chromium-browser firefox-esr || true

echo "Lancement API..."
export PORT=${PORT:-8080}
export SESSION_SECRET=${SESSION_SECRET:-$(openssl rand -hex 32)}
export NOVM_MANAGER_URL="https://virtual-xfce-spin--ogsincord.replit.app/"

# Si pnpm project
if [ -f "package.json" ]; then
  pnpm install
  PORT=8080 pnpm --filter @workspace/api-server run dev &
  PORT=22164 BASE_PATH=/ pnpm --filter @workspace/vbox-ui run dev &
  wait
else
  echo "Pas de package.json trouvé - clone le backend NoVM d'abord"
  echo "git clone https://github.com/ton-org/novm-backend"
fi
