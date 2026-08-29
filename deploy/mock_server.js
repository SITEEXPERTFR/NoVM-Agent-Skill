/**
 * NoVM Mock Backend - pour tester quand t'es pas le créateur
 * Permet de déployer ta propre copie sur Replit / VPS sans avoir le vrai backend XFCE
 * 
 * Usage:
 *   npm install express cors uuid
 *   node deploy/mock_server.js
 *   # Puis: echo "http://localhost:8080/" > .novm && ./novm.sh list
 * 
 * Pour vrai XFCE + VNC, voir DEPLOY.md Option 2/3
 */

const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
app.use(cors());
app.use(express.json());

let sessions = [];
let apps = [
  { id: "chromium", name: "Chromium Browser", installed: false },
  { id: "firefox", name: "Firefox", installed: false },
  { id: "vscode", name: "VS Code", installed: false },
  { id: "terminal", name: "Terminal", installed: true }
];

console.log("NoVM Mock Backend - https://virtual-xfce-spin--ogsincord.replit.app/ compatible");
console.log("Dot file .novm -> $NOVM should point to this server");

// List sessions
app.get('/api/sessions', (req, res) => {
  console.log(`[GET] /api/sessions - ${sessions.length} sessions`);
  res.json(sessions);
});

// Create session - checks 2 VM limit per skill.md
app.post('/api/sessions', (req, res) => {
  console.log(`[POST] /api/sessions`, req.body);
  if (sessions.length >= 2) {
    console.log("  -> Refusing, 2 VM limit reached");
    return res.status(400).json({ 
      error: "Backend can only handle two VMs at a time for now",
      message: "Terminate a session first?"
    });
  }
  const session = {
    id: uuidv4(),
    name: req.body.name || "Support Desktop",
    resolution: req.body.resolution || "1280x720",
    disableTimeouts: req.body.disableTimeouts || false,
    status: "running",
    createdAt: new Date().toISOString(),
    url: null
  };
  sessions.push(session);
  console.log(`  -> Created ${session.id}`);
  res.json(session);
});

// Get session
app.get('/api/sessions/:id', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (!s) return res.status(404).json({ error: "Not found" });
  res.json(s);
});

// Start
app.post('/api/sessions/:id/start', (req, res) => {
  console.log(`[POST] /api/sessions/${req.params.id}/start`);
  const s = sessions.find(x => x.id === req.params.id);
  if (s) {
    s.status = "running";
    // Simulate startup delay
    setTimeout(() => {}, 100);
  }
  res.json(s || { error: "Not found" });
});

// Stop
app.post('/api/sessions/:id/stop', (req, res) => {
  console.log(`[POST] /api/sessions/${req.params.id}/stop`);
  const s = sessions.find(x => x.id === req.params.id);
  if (s) s.status = "stopped";
  res.json(s || { error: "Not found" });
});

// Pause / Resume / Restart / Recover
app.post('/api/sessions/:id/pause', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (s) s.status = "paused";
  res.json(s || { success: true });
});
app.post('/api/sessions/:id/resume', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (s) s.status = "running";
  res.json(s || { success: true });
});
app.post('/api/sessions/:id/restart', (req, res) => {
  console.log(`[POST] /api/sessions/${req.params.id}/restart`);
  res.json({ success: true, message: "Restarting" });
});
app.post('/api/sessions/:id/recover', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (s) s.status = "running";
  res.json(s || { success: true });
});

// Rename
app.patch('/api/sessions/:id', (req, res) => {
  const s = sessions.find(x => x.id === req.params.id);
  if (s && req.body.name) s.name = req.body.name;
  res.json(s || { error: "Not found" });
});

// Duplicate
app.post('/api/sessions/:id/duplicate', (req, res) => {
  const orig = sessions.find(x => x.id === req.params.id);
  if (!orig) return res.status(404).json({ error: "Not found" });
  if (sessions.length >= 2) {
    return res.status(400).json({ error: "2 VM limit" });
  }
  const dup = { ...orig, id: uuidv4(), name: orig.name + " (copy)", createdAt: new Date().toISOString() };
  sessions.push(dup);
  res.json(dup);
});

// Connect - returns 15 min URL
app.post('/api/sessions/:id/connect', (req, res) => {
  console.log(`[POST] /api/sessions/${req.params.id}/connect`);
  const token = uuidv4();
  const host = req.get('host');
  const protocol = req.protocol;
  const url = `${protocol}://${host}/api/novnc/viewer?token=${token}`;
  res.json({
    url: url,
    token: token,
    expiresInSeconds: 900,
    expiresAt: new Date(Date.now() + 900*1000).toISOString()
  });
});

// Disconnect
app.post('/api/sessions/:id/disconnect', (req, res) => {
  console.log(`[POST] /api/sessions/${req.params.id}/disconnect`);
  res.json({ success: true, message: "Disconnected, links revoked" });
});

app.post('/api/sessions/:id/disconnect/request', (req, res) => {
  res.json({ success: true, message: "Disconnect vote started" });
});

// Apps
app.get('/api/apps', (req, res) => {
  res.json(apps);
});

app.post('/api/sessions/:id/apps', (req, res) => {
  console.log(`[POST] /api/sessions/${req.params.id}/apps`, req.body);
  res.json({ success: true, appId: req.body.appId, message: `Installed ${req.body.appId}` });
});

app.post('/api/sessions/:id/apps/custom', (req, res) => {
  res.json({ success: true, message: "Custom app installed" });
});

app.post('/api/sessions/:id/apps/deb', (req, res) => {
  res.json({ success: true, message: `Installed ${req.body.fileName}` });
});

app.post('/api/sessions/:id/apps/:appId/update', (req, res) => {
  res.json({ success: true, message: `Updated ${req.params.appId}` });
});

// Profiles
app.get('/api/sessions/:id/profiles', (req, res) => {
  res.json([{ id: "default", name: "Default" }]);
});
app.post('/api/sessions/:id/profiles', (req, res) => {
  res.json({ id: uuidv4(), ...req.body });
});

// Files
app.get('/api/sessions/:id/files', (req, res) => {
  res.json({ files: [], shared: [] });
});
app.post('/api/sessions/:id/files', (req, res) => {
  res.json({ success: true, fileName: req.body.fileName });
});
app.get('/api/sessions/:id/files/download', (req, res) => {
  res.json({ error: "Mock - no real files" });
});

// Backups
app.get('/api/sessions/:id/backups', (req, res) => {
  res.json([]);
});
app.post('/api/sessions/:id/backups', (req, res) => {
  res.json({ id: uuidv4(), createdAt: new Date().toISOString() });
});
app.post('/api/sessions/:id/backups/:backupId/restore', (req, res) => {
  res.json({ success: true });
});

// Permissions
app.post('/api/sessions/:id/permissions/request', (req, res) => {
  res.json({ success: true, approved: true });
});

// Delete - empty body = success per skill.md
app.delete('/api/sessions/:id', (req, res) => {
  console.log(`[DELETE] /api/sessions/${req.params.id}`);
  sessions = sessions.filter(x => x.id !== req.params.id);
  res.status(200).send("");
});

// Mock noVNC viewer page
app.get('/api/novnc/viewer', (req, res) => {
  res.send(`
    <html><body style="background:#1e1e1e;color:white;font-family:monospace;padding:40px">
    <h1>NoVM Mock Viewer</h1>
    <p>Token: ${req.query.token || 'none'}</p>
    <p>This is a MOCK backend for testing the client.</p>
    <p>Real XFCE desktop would be here via noVNC websockets.</p>
    <p>Session would show XFCE desktop, but this is just a placeholder.</p>
    <p>Use <code>./novm.sh list</code> to test the API works.</p>
    <p>For real desktop, deploy full NoVM backend with Xvfb + x11vnc (see DEPLOY.md)</p>
    </body></html>
  `);
});

app.get('/', (req, res) => {
  res.json({
    message: "NoVM Mock API - compatible with https://virtual-xfce-spin--ogsincord.replit.app/",
    endpoints: "/api/sessions, /api/apps, etc.",
    usage: "Set .novm to this URL and use ./novm.sh list",
    sessions: sessions.length,
    dotFile: ".novm should contain: " + req.protocol + "://" + req.get('host') + "/"
  });
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`\n✓ NoVM Mock API running on http://0.0.0.0:${PORT}/`);
  console.log(`  Primary URL from .novm: https://virtual-xfce-spin--ogsincord.replit.app/`);
  console.log(`  This mock is at: http://localhost:${PORT}/`);
  console.log(`\n  Pour l'utiliser:`);
  console.log(`    echo "http://localhost:${PORT}/" > .novm`);
  console.log(`    source .novmrc`);
  console.log(`    ./novm.sh list`);
  console.log(`    ./novm.sh quickstart "Test Desktop"`);
  console.log(`\n  Ou déploie ce fichier sur Replit:`);
  console.log(`    - Crée nouveau Repl Node.js`);
  console.log(`    - Copie ce fichier en server.js`);
  console.log(`    - npm install express cors uuid`);
  console.log(`    - Deploy -> tu auras nouvelle URL`);
  console.log(`    - echo "https://ta-nouvelle-url.replit.app/" > .novm\n`);
});
