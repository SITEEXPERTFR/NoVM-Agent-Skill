#!/usr/bin/env bash
# Deploy NoVM sur Lightning AI Studio avec T4
set -e

echo "=== Deploy Lightning AI Studio ==="
echo "Prérequis: Studio avec volume persistant + T4 + ports publics"

echo "1. Install runtime..."
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git curl ca-certificates build-essential python3 \
  xvfb xfce4 xfce4-goodies xfce4-terminal thunar \
  x11vnc dbus-x11 pulseaudio pulseaudio-utils \
  chromium-browser firefox-esr

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
corepack enable
corepack prepare pnpm@10.4.1 --activate

echo "2. Vérif T4..."
nvidia-smi || echo "⚠ T4 non détecté - pas grave pour XFCE mais mieux avec"

echo "3. Clone NoVM backend..."
if [ ! -d "novm" ]; then
  echo "Clone ton backend NoVM:"
  echo "  git clone https://github.com/YOUR_ORG/novm.git"
  echo "  cd novm && pnpm install"
else
  cd novm
  pnpm install
  export SESSION_SECRET="$(openssl rand -hex 32)"
  export NOVM_MANAGER_URL="https://YOUR_PUBLIC_MANAGER_HOST/"
  echo "SESSION_SECRET=$SESSION_SECRET"
  echo "NOVM_MANAGER_URL=$NOVM_MANAGER_URL"
  echo ""
  echo "Lancement:"
  echo "  PORT=8080 pnpm --filter @workspace/api-server run dev"
  echo "  PORT=22164 BASE_PATH=/ pnpm --filter @workspace/vbox-ui run dev"
fi
