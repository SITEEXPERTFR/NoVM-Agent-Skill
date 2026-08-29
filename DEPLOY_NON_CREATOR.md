# Déployer NoVM quand t'es pas le créateur

Tu n'es pas le créateur de `https://virtual-xfce-spin--ogsincord.replit.app/` donc tu ne peux pas republier cette URL exacte. Mais tu peux déployer **ta propre copie** et utiliser notre tool avec.

## Solution 1: Créer ton propre Replit (5 min, gratuit)

### Étapes:

1. **Va sur replit.com** → `Create Repl` → `Import from GitHub`
   - Ou `Node.js` template vide

2. **Clone le backend NoVM** (si tu as le code) ou crée un nouveau:
   ```bash
   # Si tu as accès au repo backend NoVM original
   git clone https://github.com/creator/novm-backend
   # Sinon, utilise notre template minimal (voir ci-dessous)
   ```

3. **Dans Replit, Deploy**:
   - Bouton `Deploy` → `Autoscale` (gratuit) ou `Reserved VM` (stable)
   - Tu obtiendras une nouvelle URL genre:
     `https://virtual-xfce-spin--ton-username.replit.app/`

4. **Met à jour notre tool**:
   ```bash
   echo "https://virtual-xfce-spin--ton-username.replit.app/" > .novm
   source .novmrc
   echo $NOVM
   ./novm.sh list
   ```

### Template backend minimal pour Replit:

Si tu n'as pas le backend original, crée ces fichiers sur Replit:

**`package.json`:**
```json
{
  "name": "novm-backend",
  "version": "1.0.0",
  "scripts": {
    "dev": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5",
    "uuid": "^9.0.0"
  }
}
```

**`server.js`** (mock API pour tester le client):
```javascript
const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(express.json());

let sessions = [];

app.get('/api/sessions', (req, res) => {
  res.json(sessions);
});

app.post('/api/sessions', (req, res) => {
  if (sessions.length >= 2) {
    return res.status(400).json({ error: "Backend can only handle 2 VMs at a time" });
  }
  const session = {
    id: uuidv4(),
    name: req.body.name || "Support Desktop",
    resolution: req.body.resolution || "1280x720",
    disableTimeouts: req.body.disableTimeouts || false,
    status: "running",
    createdAt: new Date().toISOString()
  };
  sessions.push(session);
  res.json(session);
});

app.get('/api/sessions/:id', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (!s) return res.status(404).json({ error: "Not found" });
  res.json(s);
});

app.post('/api/sessions/:id/start', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (s) s.status = "running";
  res.json(s || { error: "Not found" });
});

app.post('/api/sessions/:id/stop', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (s) s.status = "stopped";
  res.json(s || { error: "Not found" });
});

app.post('/api/sessions/:id/connect', (req, res) => {
  const token = uuidv4();
  res.json({
    url: `${req.protocol}://${req.get('host')}/api/novnc/viewer?token=${token}`,
    token: token,
    expiresInSeconds: 900,
    expiresAt: new Date(Date.now() + 900*1000).toISOString()
  });
});

app.post('/api/sessions/:id/disconnect', (req, res) => {
  res.json({ success: true });
});

app.delete('/api/sessions/:id', (req, res) => {
  sessions = sessions.filter(x => x.id !== req.params.id);
  res.status(200).send(""); // Empty = success per skill.md
});

app.get('/api/apps', (req, res) => {
  res.json([{ id: "chromium", name: "Chromium" }, { id: "firefox", name: "Firefox" }]);
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`NoVM mock API running on port ${PORT}`);
});
```

Ce mock te permet de tester le client. Pour le vrai XFCE + VNC, il faut le runtime complet (voir DEPLOY.md Option 2/3).

---

## Solution 2: Déployer sur ton VPS / Railway / Render / Fly.io

Même principe, mais sur ton infra:

```bash
# Sur ton serveur
git clone https://github.com/SITEEXPERTFR/NoVM-Agent-Skill
cd NoVM-Agent-Skill

# Si tu as le vrai backend NoVM
git clone https://github.com/creator/novm-backend ./backend
cd backend
npm install
export SESSION_SECRET=$(openssl rand -hex 32)
PORT=8080 npm run dev
```

Puis Nginx pour HTTPS + WebSockets (config dans DEPLOY.md).

Et update `.novm`:
```bash
echo "https://ton-domaine.com/" > .novm
```

---

## Solution 3: Utiliser notre tool sans backend (mode dev)

Notre tool fonctionne même si le backend est down, il gère le fallback.

Pour dev local sans backend, tu peux utiliser le mock ci-dessus:

```bash
# Terminal 1: lance le mock
node server.js
# API sur http://localhost:8080

# Terminal 2: pointe le tool vers localhost
echo "http://localhost:8080/" > .novm
source .novmrc
./novm.sh list
./novm.sh quickstart "Test Local"
```

---

## Solution 4: Contacter le créateur

Si tu veux récupérer exactement `virtual-xfce-spin--ogsincord.replit.app`:

- Va sur Replit, trouve le Repl `virtual-xfce-spin`
- Check owner: `ogsincord`
- Contacte-le pour qu'il republie (Deploy → Publish)

En attendant, notre tool essaie déjà automatiquement le fallback `no-vm-desktop-fix--novm4.replit.app`.

---

## Résumé pour non-créateur

| Tu veux quoi? | Commande |
|---------------|----------|
| Tester le client sans backend | `echo "http://localhost:8080/" > .novm && node server.js` |
| Déployer ta copie Replit | Crée nouveau Repl → Deploy → update `.novm` avec nouvelle URL |
| Déployer prod stable | VPS + Docker → voir `deploy/docker_deploy.sh` |
| Utiliser avec n'importe quel host | `echo "https://ton-host.com/" > .novm && source .novmrc` |

Le tool est **agnostique du host** - il utilise juste `$NOVM` depuis `.novm`. Tu peux pointer vers n'importe quel déploiement.

---

## Changer l'URL partout en 1 commande

```bash
NEW_URL="https://mon-novm-perso.replit.app/"
echo "$NEW_URL" > .novm
source .novmrc
echo "Nouveau \$NOVM = $NOVM"

# Tester
./novm.sh list
./novm.sh quickstart "Mon Desktop Perso"
```

C'est tout - pas besoin d'être créateur de l'ancienne URL.
