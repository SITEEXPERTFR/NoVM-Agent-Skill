#!/usr/bin/env bash
# Deploy NoVM avec Docker sur VPS
set -e

DOMAIN=${1:-"virtual-xfce-spin--ogsincord.replit.app"}
echo "=== Deploy Docker NoVM pour $DOMAIN ==="

cat > Dockerfile.novm <<'DOCKER'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
  xvfb xfce4 xfce4-goodies xfce4-terminal thunar \
  x11vnc dbus-x11 pulseaudio pulseaudio-utils \
  chromium-browser firefox-esr \
  curl git python3 nodejs npm \
  && rm -rf /var/lib/apt/lists/*
RUN npm install -g pnpm
WORKDIR /app
COPY . .
RUN pnpm install || npm install || true
ENV PORT=8080
EXPOSE 8080 22164
CMD ["sh", "-c", "PORT=8080 pnpm --filter @workspace/api-server run dev & PORT=22164 BASE_PATH=/ pnpm --filter @workspace/vbox-ui run dev & wait"]
DOCKER

echo "Dockerfile créé. Build..."
# docker build -f Dockerfile.novm -t novm:latest .

cat > docker-compose.yml <<COMPOSE
version: '3.8'
services:
  novm-api:
    build:
      context: .
      dockerfile: Dockerfile.novm
    ports:
      - "8080:8080"
      - "22164:22164"
    environment:
      - SESSION_SECRET=\${SESSION_SECRET:-change-me-random}
      - NOVM_MANAGER_URL=https://$DOMAIN/
      - PORT=8080
    restart: unless-stopped
    volumes:
      - novm_data:/app/data

volumes:
  novm_data:
COMPOSE

echo "docker-compose.yml créé"
echo ""
echo "Pour lancer:"
echo "  export SESSION_SECRET=\$(openssl rand -hex 32)"
echo "  docker-compose up -d"
echo "  docker-compose logs -f"
echo ""
echo "Puis configure Nginx pour proxy vers 8080 et 22164 avec WebSockets"
echo "Voir DEPLOY.md section Nginx"
