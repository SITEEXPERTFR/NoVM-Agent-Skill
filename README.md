# NoVM Agent Skill — Implementation for https://virtual-xfce-spin--ogsincord.replit.app/

Complete implementation of the NoVM Workstation Manager skill using the deployment at **https://virtual-xfce-spin--ogsincord.replit.app/** as primary.

> Dot file `.novm` contains base URL and corresponds to `$NOVM` env var — use `$NOVM` in all bash commands instead of retyping URL.

## Quick Install

```bash
./install.sh
source .novmrc
echo $NOVM  # https://virtual-xfce-spin--ogsincord.replit.app/
```

## Architecture

```
.novm                # Dot file with base URL (corresponds to $NOVM)
.novmrc              # Sourceable shell config: export NOVM="..."
.env                 # Env file for docker/python
novm.sh              # Full bash CLI (all endpoints, rate-limit handling, fallback)
bin/novm             # Short wrapper that loads .novm -> $NOVM
novm_client.py       # Python SDK (all endpoints, auto fallback, 2 VM limit check)
tools/agent_control.py # Vision agent controller (screenshot -> plan -> bash)
install.sh           # Setup script
skill.md             # Original skill spec
```

## Base URLs

- **Primary (user requested):** `https://virtual-xfce-spin--ogsincord.replit.app/`
- **Fallback:** `https://no-vm-desktop-fix--novm4.replit.app/`
- Both use same API paths under `/api`

All clients automatically try fallback if primary fails (Replit sleeping, SSL error, etc).

## Bash Usage with $NOVM

```bash
# Load $NOVM from dot file
source .novmrc
# or
export NOVM=$(cat .novm)

# Now use $NOVM in all curl commands
curl "$NOVM/api/sessions" -H "Content-Type: application/json"

# Create workstation
curl -X POST "$NOVM/api/sessions" \
  -H "Content-Type: application/json" \
  -d '{"name":"Support Desktop","resolution":"1280x720","disableTimeouts":false}'

# Start it
curl -X POST "$NOVM/api/sessions/SESSION_ID/start"

# Get connection link (15 min expiry, auto-refreshes while active)
curl -X POST "$NOVM/api/sessions/SESSION_ID/connect"

# Using the CLI wrapper (handles $NOVM, retries, fallback)
./novm.sh list
./novm.sh quickstart "My Desktop"
./novm.sh create "Dev Desktop" "1920x1080" false
./novm.sh connect SESSION_ID
./novm.sh install-app SESSION_ID chromium
./novm.sh delete SESSION_ID

# Short wrapper
bin/novm list
bin/novm quickstart
```

## Python Usage

```python
from novm_client import NoVMClient

client = NoVMClient()  # Auto-loads $NOVM from .novm dot file
# Or explicit:
# client = NoVMClient(base_url="https://virtual-xfce-spin--ogsincord.replit.app/")

# List
sessions = client.list_sessions()

# Quickstart: create+start+connect in one
result = client.quickstart(name="Support Desktop")
print(result['url'])  # Browser URL
# -> "I've successfully spun up your NoVM machine and you can access it at: https://..."

# Manual flow
session = client.create_session(name="My Desktop", resolution="1280x720")
client.start_session(session['id'])
conn = client.connect_session(session['id'])
print(conn['url'])

# Apps
client.list_apps()
client.install_app(session['id'], "chromium")

# Files
client.list_files(session['id'])
client.upload_local_file(session['id'], "./myfile.txt")

# Cleanup
client.delete_session(session['id'])
```

## Agent Control (Vision Models)

Per skill.md rules:

> You are able to control a NoVM Virtual Machine over NoVNC Websockets. To properly use the Virtual machine you must take a screenshot of the desktop, look at it, plan next action then use Bash to send a command to the VM. Only vision capable models can interact with NoVM Virtual Machines.

```python
from tools.agent_control import NoVMAgentController

controller = NoVMAgentController()
result = controller.execute_task("Open Firefox and go to example.com")
# Returns session_id, connection_url, instructions for screenshot->plan->bash loop
```

Workflow for vision agent:
1. `ensure_session()` - get or create VM (checks 2 VM limit)
2. `get_connection_url()` - fresh 15-min URL
3. Open URL, take screenshot
4. Analyze screenshot, plan next action
5. Use bash to interact (via VNC or API)
6. Repeat

If not vision capable: politely explain and prompt user to start new chat.

## Important Rules Implemented

- **2 VM limit:** Before creating new VM, check if 2 already running. If so, refuse and prompt user if they want to terminate a session. Implemented in both `novm.sh` (`check_vm_limit`) and `novm_client.py` (`check_vm_limit()` / `VMLimitError`).
- **Dot file -> $NOVM:** `.novm` contains base URL, `.novmrc` exports it as `$NOVM`, all bash commands use `$NOVM` not hardcoded URL.
- **Connection links temporary:** 15-min window, auto-refresh while active, stops if idle 15 min. Hand back fresh URL each time.
- **Terminate = delete:** When user says "terminate the VM" use `DELETE /api/sessions/{id}` not just `/stop`.
- **Rate limiting:** API can return `Rate exceeded.` - clients auto-retry with backoff.
- **Empty DELETE = success:** 200 with empty body means deleted.
- **Never say XFCE:** In chat never refer to VM as "XFCE desktop/workstation". Say "I've successfully spun up your NoVM machine and you can access it at:"

## Endpoint Reference (all under $NOVM/api)

| Method | Path | Purpose |
|--------|------|---------|
| GET | /sessions | List all workstations |
| POST | /sessions | Create workstation |
| GET | /sessions/{id} | Get status |
| POST | /sessions/{id}/start | Start |
| POST | /sessions/{id}/stop | Stop |
| POST | /sessions/{id}/pause | Pause (preserve files) |
| POST | /sessions/{id}/resume | Resume |
| POST | /sessions/{id}/restart | Restart services |
| POST | /sessions/{id}/recover | Recover |
| PATCH | /sessions/{id} | Rename |
| POST | /sessions/{id}/duplicate | Duplicate |
| POST | /sessions/{id}/connect | Issue 15-min URL |
| POST | /sessions/{id}/disconnect | Revoke links |
| POST | /sessions/{id}/disconnect/request | Shared disconnect vote |
| GET | /apps | List installable apps |
| POST | /sessions/{id}/apps | Install app |
| POST | /sessions/{id}/apps/custom | Custom app |
| POST | /sessions/{id}/apps/deb | Install .deb |
| POST | /sessions/{id}/apps/{appId}/update | Update app |
| GET | /sessions/{id}/profiles | List Chromium profiles |
| POST | /sessions/{id}/profiles | Create profile |
| GET | /sessions/{id}/files | List files |
| POST | /sessions/{id}/files | Upload base64 file |
| GET | /sessions/{id}/files/download | Download file |
| POST | /sessions/{id}/backups | Create backup |
| GET | /sessions/{id}/backups | List backups |
| POST | /sessions/{id}/backups/{backupId}/restore | Restore backup |
| POST | /sessions/{id}/permissions/request | Request permission |
| DELETE | /sessions/{id} | Stop and permanently delete |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Link doesn't load | Token expired (15 min). Re-run `POST /connect` via `novm.sh connect ID` |
| `Rate exceeded.` | Auto-retried, but wait few seconds |
| `DELETE` empty body | Success - verify with `list` |
| Session gone after idle | Default auto-stop after 15 min idle. Use `disableTimeouts:true` for trusted |
| SSL_ERROR_SYSCALL / "This app isn't live yet" | Replit deployment sleeping - client auto tries fallback URL |
| Can't find session | Run `list` first |

## Examples

See `examples/` directory:
- `examples/quickstart.sh` - bash quickstart
- `examples/quickstart.py` - python quickstart
- `examples/agent_demo.py` - agent control demo

## Self-hosting

See skill.md Self-hosting section for Lightning AI Studio with T4.

## License

MIT - NoVM Skill Implementation
