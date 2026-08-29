# NoVM Tool Usage - with https://virtual-xfce-spin--ogsincord.replit.app/

## Dot file -> $NOVM

Per skill.md rule: "Before starting make a dot file containing the base URL and make it correspond to "$NOVM" so in bash commands you can use $NOVM instead of retyping the base URL"

Implementation:

```bash
# .novm file contains base URL
cat .novm
# https://virtual-xfce-spin--ogsincord.replit.app/

# .novmrc exports it as $NOVM
cat .novmrc
# export NOVM="https://virtual-xfce-spin--ogsincord.replit.app/"

# Load it
source .novmrc
echo $NOVM
# https://virtual-xfce-spin--ogsincord.replit.app/

# Use $NOVM in all bash commands
curl "$NOVM/api/sessions"
curl -X POST "$NOVM/api/sessions" -d '{"name":"Desktop","resolution":"1280x720","disableTimeouts":false}'
```

## Quickstart

```bash
# Install (creates .novm dot file -> $NOVM)
./install.sh
source .novmrc

# List workstations
./novm.sh list
# or
bin/novm list
# or
python3 novm_client.py list

# Quickstart: create+start+connect
./novm.sh quickstart "My Desktop"
# Returns: I've successfully spun up your NoVM machine and you can access it at: https://...

# Manual flow
./novm.sh create "Dev Desktop" "1920x1080" false
./novm.sh start SESSION_ID
./novm.sh connect SESSION_ID
# Open returned URL in browser

# Apps
./novm.sh apps
./novm.sh install-app SESSION_ID chromium

# Cleanup
./novm.sh delete SESSION_ID
```

## Python

```python
from novm_client import NoVMClient

client = NoVMClient()  # auto-loads $NOVM from .novm
result = client.quickstart(name="Support Desktop")
print(f"I've successfully spun up your NoVM machine and you can access it at: {result['url']}")
```

## Important Rules

- Check 2 VM limit before creating: `check_vm_limit()` / `./novm.sh check-limit`
- Connection URLs expire in 15 min, auto-refresh while active
- "Terminate" means DELETE not stop
- Empty DELETE response = success
- Handle "Rate exceeded." with retry
- Never say "XFCE desktop" - say "NoVM machine"

## API Base

- Primary: https://virtual-xfce-spin--ogsincord.replit.app/
- Fallback: https://no-vm-desktop-fix--novm4.replit.app/
- All clients auto-try fallback if primary fails (Replit sleeping)
