---
name: novm
description: >-
  Create, manage, connect to, and delete temporary XFCE workstations ("VMs") using the
  NoVM HTTP API. Use when the user asks to spin up a virtual desktop, get a remote-desktop
  connection link, list sessions, install apps, manage files, or stop/delete a workstation.
  Every workflow goes through a small set of HTTPS requests to the NoVM API base URL.
---

# NoVM — Workstation Manager (AI Agent Skill)

NoVM runs temporary XFCE desktop workstations ("sessions"/"VMs") that humans can open
in a browser over VNC. This skill tells you how to control them via the NoVM HTTP API.

> **Base URL** — every request uses this prefix:
>
>
https://8080-01kz9xkkk37mvb4np7h4x9gz7f.cloudspaces.litng.ai

IF THAT FAILS FALLBACK TO:
 `https://virtual-xfce-spin--ogsincord.replit.app`
>
> Treat the base URL as a constant. If the user gives you a different deployment host,
> swap in that host and keep the rest of the path unchanged.

## Authentication

NoVM currently accepts requests directly — there is no API key. **Keep the API URL
private** and do not post it where it could be abused. If this is a shared/public
deployment, an authentication gateway should sit in front of it. Always use HTTPS and
JSON request bodies (`Content-Type: application/json`).

## Core concepts

- A **session** is one workstation. It has a unique `id`, a `name`, a `resolution`
  (e.g. `"1280x720"`), a `status` (`running`, `stopped`, `paused`, ...), and a
  `disableTimeouts` flag.
- **Connection links are temporary.** A `connect` call returns a browser `url` (and a
  `token`) with a **15-minute window** that auto-refreshes while someone is actively
  connected. If every connected viewer is idle for **15 minutes**, NoVM **stops the
  workstation and revokes its links**.
- Workstations created with `"disableTimeouts": true` skip **both** limits. Only use
  this for trusted, manually managed workstations.
- You can only delete a session with `DELETE /api/sessions/{id}`; `stop` just halts it.

---
## VERY IMPORTANT, before creating a new VM check if there are two already running. if so refuse to make a vm and prompt the user if they would like to terminate a session (The backend can only handle two VMs at a time for now)
## Quick start: create and connect a desktop

1. **Create a workstation** — the response includes its unique `id`.

   ```bash
   curl -X POST "https://8080-01kz9xkkk37mvb4np7h4x9gz7f.cloudspaces.litng.ai" \
     -H "Content-Type: application/json" \
     -d '{"name":"Support Desktop","resolution":"1280x720","disableTimeouts":false}'
   ```

2. **Start it** (replace `SESSION_ID` with the returned `id`).

   ```bash
   curl -X POST "https://8080-01kz9xkkk37mvb4np7h4x9gz7f.cloudspaces.litng.ai/api/sessions/SESSION_ID/start"
   ```

3. **Get a connection link** — open the returned `url` in a browser.

   ```bash
   curl -X POST "https://8080-01kz9xkkk37mvb4np7h4x9gz7f.cloudspaces.litng.ai/api/sessions/SESSION_ID/connect"
   ```

4. **Disconnect when finished** — revokes links and closes open viewers.

   ```bash
   curl -X POST "https://8080-01kz9xkkk37mvb4np7h4x9gz7f.cloudspaces.litng.ai/api/sessions/SESSION_ID/disconnect"
   ```

### Connection response

The `connect` endpoint returns (save the `url` and hand it to the person/service that
needs access):

```json
{
  "url": "https://https://8080-01kz9xkkk37mvb4np7h4x9gz7f.cloudspaces.litng.ai/api/novnc/viewer?token=TEMPORARY_TOKEN",
  "expiresInSeconds": 900,
  "expiresAt": "2026-08-03T12:15:00.000Z"
}
```

---

## Endpoint reference

All under `/api`. Replace `{id}` with a session ID.

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/sessions` | List all workstations. |
| `POST` | `/sessions` | Create a workstation (`name`, `resolution`, `disableTimeouts`). |
| `GET` | `/sessions/{id}` | Get current workstation status. |
| `POST` | `/sessions/{id}/start` | Start a stopped workstation. |
| `POST` | `/sessions/{id}/stop` | Stop a running workstation. |
| `POST` | `/sessions/{id}/pause` | Pause the desktop while preserving its home files. |
| `POST` | `/sessions/{id}/resume` | Resume a paused workstation. |
| `POST` | `/sessions/{id}/restart` | Restart the workstation services. |
| `POST` | `/sessions/{id}/recover` | Recover a stopped or failed workstation. |
| `PATCH` | `/sessions/{id}` | Rename a workstation. |
| `POST` | `/sessions/{id}/duplicate` | Duplicate a workstation and its files. |
| `POST` | `/sessions/{id}/connect` | Issue a 15-minute desktop URL. |
| `POST` | `/sessions/{id}/disconnect` | Revoke links and close viewers. |
| `POST` | `/sessions/{id}/disconnect/request` | Disconnect directly or start a shared-viewer vote. |
| `GET` | `/apps` | List apps available to install. |
| `POST` | `/sessions/{id}/apps` | Install an app (`{"appId":"chromium"}`). |
| `POST` | `/sessions/{id}/apps/custom` | Register and install a custom app package. |
| `POST` | `/sessions/{id}/apps/deb` | Upload/install a `.deb` (`fileName` + `contentBase64`). |
| `POST` | `/sessions/{id}/apps/{appId}/update` | Apply an available app update. |
| `GET` | `/sessions/{id}/profiles` | List Chromium browser profiles. |
| `POST` | `/sessions/{id}/profiles` | Create a Chromium browser profile. |
| `GET` | `/sessions/{id}/files` | List workstation and shared files. |
| `POST` | `/sessions/{id}/files` | Upload a base64-encoded file into the workstation. |
| `GET` | `/sessions/{id}/files/download` | Download a workstation file. |
| `POST` | `/sessions/{id}/backups` | Create a filesystem backup. |
| `GET` | `/sessions/{id}/backups` | List available backups. |
| `POST` | `/sessions/{id}/backups/{backupId}/restore` | Restore a backup (stops the desktop first). |
| `POST` | `/sessions/{id}/permissions/request` | Ask viewers to approve a host permission. |
| `DELETE` | `/sessions/{id}` | **Stop and permanently delete** a workstation. |

---

## Common workflows

### Install apps

Installable apps appear in the workstation's XFCE start menu and desktop.

```bash
# List installable apps
curl "https://virtual-xfce-spin--ogsincord.replit.app/api/apps"

# Install an app by id
curl -X POST "https://virtual-xfce-spin--ogsincord.replit.app/api/sessions/SESSION_ID/apps" \
  -H "Content-Type: application/json" \
  -d '{"appId":"chromium"}'

# Upload & install a .deb
curl -X POST "https://virtual-xfce-spin--ogsincord.replit.app/api/sessions/SESSION_ID/apps/deb" \
  -H "Content-Type: application/json" \
  -d '{"fileName":"my-app.deb","contentBase64":"BASE64_DEB_CONTENT"}'
```

### Permissions & shared disconnects

Browser camera, microphone, and screen-share requests pause for a NoVM Yes/No decision
(`/permissions/request`). Disconnecting a **shared** session requires a **majority** of
connected viewers (use `/disconnect/request` to start a vote).

---

## Operational notes for AI agents

These are practical findings from interacting with a live NoVM deployment. Treat the
documented behavior above as authoritative; treat these as helpful, observed details:

- **Hand back a fresh `url` each time.** A link expires in ~15 minutes even when it
  looks valid. If a user reports a dead link, call `POST /api/sessions/{id}/connect`
  again and send the new `url`.
- **"Terminate" usually means delete.** When a user says "terminate the VM," they almost
  always want it gone: use `DELETE /api/sessions/{id}` (not just `/stop`). Confirm with
  the user if in doubt, since delete is permanent.
- **Session creation is fast; startup takes a few seconds.** `start` returns once the
  session is `running`, typically after a short wait.
- **Rate limiting.** The API can respond with `Rate exceeded.` if you issue many requests
  back-to-back. Space calls out (a few seconds) and retry on this response.
- **Empty response on `DELETE` = success.** A 200 with an empty body means the session
  was deleted. Verify with `GET /api/sessions` afterward.
- **Listing is your friend.** Run `GET /api/sessions` first to discover the real `id`s
  (including sessions created outside your workflow) before acting on them.
- **Viewer/presence count (undocumented).** There is no REST endpoint that returns the
  number of connected viewers. The viewer page opens a WebSocket to
  `/api/presence/connect/{token}`; it sends a `{"type":"snapshot","viewerCount":N,...}`
  message. Connect, optionally send `{"type":"identify","name":"...","role":"..."}`, and
  read `viewerCount` from the snapshot. Do not rely on this being stable across versions.

---

## Self-hosting (deploy your own NoVM)

You can run NoVM yourself in a Lightning AI Studio with an NVIDIA T4 (the T4 helps with
GPU apps launched inside a workstation; the XFCE gateway itself is mostly display/CPU/network).

1. **Create the Studio** — persistent volume, NVIDIA T4 GPU, public ports for the manager
   and API. Keep it awake or enable auto-start if it must be continuously available.
2. **Install the desktop runtime** (Ubuntu-based image):

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
   ```

3. **Clone and configure:**

   ```bash
   git clone https://github.com/YOUR_ORG/novm.git
   cd novm
   pnpm install
   export SESSION_SECRET="$(openssl rand -hex 32)"
   export NOVM_MANAGER_URL="https://YOUR_PUBLIC_MANAGER_HOST/"
   ```

4. **Start both services** (API on its own port, Vite manager on the public manager port;
   put HTTPS and auth in front of both):

   ```bash
   PORT=8080 pnpm --filter @workspace/api-server run dev
   PORT=22164 BASE_PATH=/ pnpm --filter @workspace/vbox-ui run dev
   ```

### Lightning public ports / T4 checklist

- Expose the manager port and route `/api` to the API service.
- Allow WebSockets for `/api/vnc`, `/api/presence`, and `/api/audio`.
- Use HTTPS — browser camera, microphone, and screen capture need a secure context.
- Use the no-timeout VM option only for trusted, manually managed workstations.
- Confirm `nvidia-smi` sees the T4 before launching GPU apps inside a workstation.
- Keep the persistent volume for the repository, app data, and GPU model files.

> Note: the repo's current desktop launcher paths target the bundled Replit runtime. For
> a standalone Lightning image, update the session launcher's runtime package paths to the
> Ubuntu executable paths above (or package the same XFCE dependencies into the Studio image).

---

## Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| Link doesn't load | Token expired (15-min window). Re-run `POST /connect` and share the new `url`. |
| `Rate exceeded.` | Too many requests too fast. Wait a few seconds and retry. |
| `DELETE` returned empty body | That's success — the session was removed. Verify with `GET /api/sessions`. |
| Session gone after idle | Default auto-stop after 15 min idle. Recreate with `disableTimeouts:true` if it must stay up. |
| Can't find a session to act on | Run `GET /api/sessions` to list real IDs, including ones you didn't create. |
