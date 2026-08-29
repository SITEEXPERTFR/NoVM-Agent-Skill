# Comment déployer NoVM - Guide complet

L'URL `https://virtual-xfce-spin--ogsincord.replit.app/` est actuellement **down** : 
> "This app isn't live yet - We couldn't find a Replit App at this address. If you're the owner, publish your app"

Voilà comment la redeployer.

---

## Option 1: Replit (la plus simple - pour récupérer ton URL actuelle)

Ton URL `virtual-xfce-spin--ogsincord.replit.app` est une Replit deployment.

### Étapes pour la republier:

1. **Va sur Replit.com** → ton projet `virtual-xfce-spin`
2. **Publish / Deploy**:
   - Dans Replit, bouton `Deploy` en haut à droite
   - Choisis `Autoscale` ou `Reserved VM` (Reserved VM recommandé pour NoVM, sinon ça sleep)
   - Publish
   - Vérifie que le domaine `virtual-xfce-spin--ogsincord.replit.app` est bien assigné

3. **Garder l'app awake** (important):
   - Replit Autoscale sleep après inactivité → ton API retourne SSL_ERROR
   - Solutions:
     - Passe en **Reserved VM** (payant mais toujours allumé)
     - Ou ajoute un uptime checker qui ping `https://virtual-xfce-spin--ogsincord.replit.app/api/sessions` toutes les 5 min
     - Ou utilise le fallback dans notre tool (déjà implémenté)

4. **Tester**:
   ```bash
   source .novmrc
   curl "$NOVM/api/sessions"
   # Devrait retourner [] ou [{"id":...}]
   ```

### Si tu as perdu le code source Replit:

Le backend NoVM est normalement un projet Node.js avec:
- API server (Express/Fastify)
- XFCE + Xvfb + x11vnc + noVNC
- Session manager

Tu peux le re-cloner depuis l'autre deployment `no-vm-desktop-fix--novm4.replit.app` si tu y as accès, ou utiliser Option 2.

---

## Option 2: Self-hosting Lightning AI Studio (recommandé - stable)

D'après `skill.md`, NoVM peut tourner sur Lightning AI avec GPU T4.

### Prérequis:
- Compte Lightning AI
- Studio avec: persistent volume, NVIDIA T4, ports publics exposés

### Installation runtime (Ubuntu):

```bash
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git curl ca-certificates build-essential python3 \
  xvfb xfce4 xfce4-goodies xfce4-terminal thunar \
  x11vnc dbus-x11 pulseaudio pulseaudio-utils \
  chromium-browser firefox-esr

curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
corepack enable
corepack prepare pnpm@10.4.1 --activate

nvidia-smi  # Vérifie T4
```

### Clone & configure:

```bash
git clone https://github.com/YOUR_ORG/novm.git  # ou ton repo NoVM
cd novm
pnpm install
export SESSION_SECRET="$(openssl rand -hex 32)"
export NOVM_MANAGER_URL="https://TON_PUBLIC_MANAGER_HOST/"
```

### Lancer les 2 services:

```bash
# Terminal 1 - API
PORT=8080 pnpm --filter @workspace/api-server run dev

# Terminal 2 - Manager UI
PORT=22164 BASE_PATH=/ pnpm --filter @workspace/vbox-ui run dev
```

### Checklist ports Lightning:

- Expose manager port, route `/api` → API service
- Autorise WebSockets pour `/api/vnc`, `/api/presence`, `/api/audio`
- HTTPS obligatoire (camera/mic besoin secure context)
- `disableTimeouts:true` uniquement pour VMs trusted

Ensuite mets à jour ton `.novm`:

```bash
echo "https://TON_NOUVEAU_HOST/" > .novm
source .novmrc
./novm.sh list
```

---

## Option 3: Docker / VPS (le plus contrôlable)

### Dockerfile exemple:

```dockerfile
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
RUN pnpm install

ENV SESSION_SECRET=change-me-generate-random
ENV PORT=8080
ENV NOVM_MANAGER_URL=https://virtual-xfce-spin--ogsincord.replit.app/

EXPOSE 8080 22164

CMD ["sh", "-c", "PORT=8080 pnpm --filter @workspace/api-server run dev & PORT=22164 BASE_PATH=/ pnpm --filter @workspace/vbox-ui run dev & wait"]
```

### Deploy sur VPS:

```bash
# Sur ton VPS
git clone https://github.com/SITEEXPERTFR/NoVM-Agent-Skill
cd NoVM-Agent-Skill

# Build
docker build -t novm .

# Run avec ports publics
docker run -d -p 8080:8080 -p 22164:22164 \
  -e SESSION_SECRET=$(openssl rand -hex 32) \
  -e NOVM_MANAGER_URL=https://ton-domaine.com/ \
  --name novm novm

# Nginx reverse proxy pour HTTPS + WebSockets
```

### Nginx config (important pour noVNC websockets):

```nginx
server {
  listen 443 ssl;
  server_name virtual-xfce-spin--ogsincord.replit.app; # ou ton domaine

  ssl_certificate /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  location /api/ {
    proxy_pass http://localhost:8080/api/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }

  location / {
    proxy_pass http://localhost:22164/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
  }
}
```

---

## Option 4: Déployer juste le skill (client) - pas besoin de serveur

Notre repo actuel `NoVM-Agent-Skill` est **un client**, pas le serveur NoVM.

Il n'a pas besoin d'être déployé comme serveur. Il s'utilise en local:

```bash
git clone https://github.com/SITEEXPERTFR/NoVM-Agent-Skill
cd NoVM-Agent-Skill
./install.sh
source .novmrc
./novm.sh list
```

Si tu veux l'exposer comme API pour d'autres agents:

```bash
# Simple API wrapper avec FastAPI
pip install fastapi uvicorn
python3 -m tools.api_wrapper --host 0.0.0.0 --port 8000
```

---

## Quelle option choisir ?

| Besoin | Solution |
|--------|----------|
| Récupérer `virtual-xfce-spin--ogsincord.replit.app` rapidement | **Option 1** - Republier sur Replit |
| Stable, pas de sleep, production | **Option 2** - Lightning AI T4 |
| Contrôle total, custom domain | **Option 3** - Docker VPS + Nginx |
| Juste utiliser le tool en local | **Option 4** - `./install.sh` |

---

## Après déploiement, mettre à jour le dot file

```bash
# Si nouveau host
echo "https://ton-nouveau-host.com/" > .novm
cat .novm  # doit correspondre à $NOVM

source .novmrc
echo $NOVM

# Tester
./novm.sh list
./novm.sh quickstart "Test Desktop"
```

Si tu me donnes ton nouveau host, je peux mettre à jour tous les fichiers pour toi.

---

## Garder Replit awake (hack si tu restes sur Replit)

```bash
# Cron toutes les 5 min qui ping l'API
*/5 * * * * curl -s https://virtual-xfce-spin--ogsincord.replit.app/api/sessions > /dev/null

# Ou avec notre tool
while true; do
  source .novmrc
  curl -s "$NOVM/api/sessions" > /dev/null
  sleep 300
done
```

Mais Reserved VM reste le mieux.
