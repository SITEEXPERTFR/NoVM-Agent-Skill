#!/usr/bin/env bash
# NoVM - Workstation Manager CLI
# Base URL configured for https://virtual-xfce-spin--ogsincord.replit.app/
# Usage: source this file or run ./novm.sh <command>

set -e

# Load base URL from .novm dot file if exists, else use env or default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/.novm" ]; then
  NOVM_URL=$(cat "$SCRIPT_DIR/.novm" | tr -d '\n' | xargs)
  export NOVM="${NOVM_URL:-https://virtual-xfce-spin--ogsincord.replit.app/}"
else
  export NOVM="${NOVM:-https://virtual-xfce-spin--ogsincord.replit.app/}"
fi

# Fallback URL
NOVM_FALLBACK="${NOVM_FALLBACK:-https://no-vm-desktop-fix--novm4.replit.app/}"

# Ensure trailing slash
[[ "$NOVM" != */ ]] && NOVM="$NOVM/"
[[ "$NOVM_FALLBACK" != */ ]] && NOVM_FALLBACK="$NOVM_FALLBACK/"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[NoVM]${NC} $1"; }
log_success() { echo -e "${GREEN}[NoVM]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[NoVM]${NC} $1"; }
log_error() { echo -e "${RED}[NoVM]${NC} $1" >&2; }

# Helper to make API requests with retry and fallback
novm_api_call() {
  local method="$1"
  local endpoint="$2"
  local data="$3"
  local max_retries=3
  local retry_delay=2

  local url="${NOVM}api${endpoint}"
  local fallback_url="${NOVM_FALLBACK}api${endpoint}"

  for attempt in $(seq 1 $max_retries); do
    local response
    local http_code
    local body

    if [ -n "$data" ]; then
      response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
        -H "Content-Type: application/json" \
        -d "$data" --connect-timeout 10 --max-time 30 2>&1 || true)
    else
      response=$(curl -s -w "\n%{http_code}" -X "$method" "$url" \
        -H "Content-Type: application/json" \
        --connect-timeout 10 --max-time 30 2>&1 || true)
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    # Check for rate limiting
    if echo "$body" | grep -qi "Rate exceeded"; then
      log_warn "Rate limited, waiting ${retry_delay}s (attempt $attempt/$max_retries)..."
      sleep $retry_delay
      retry_delay=$((retry_delay * 2))
      continue
    fi

    # If we get a valid response (2xx or JSON), return it
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]] || echo "$body" | grep -q "^{"; then
      echo "$body"
      return 0
    fi

    # If primary fails, try fallback on last attempt
    if [ $attempt -eq $max_retries ]; then
      log_warn "Primary URL failed, trying fallback: $NOVM_FALLBACK"
      if [ -n "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$fallback_url" \
          -H "Content-Type: application/json" \
          -d "$data" --connect-timeout 10 --max-time 30 2>&1 || true)
      else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$fallback_url" \
          -H "Content-Type: application/json" \
          --connect-timeout 10 --max-time 30 2>&1 || true)
      fi
      http_code=$(echo "$response" | tail -n1)
      body=$(echo "$response" | sed '$d')
      if [[ "$http_code" =~ ^2[0-9][0-9]$ ]] || [ -z "$body" ] || echo "$body" | grep -q "^{"; then
        echo "$body"
        return 0
      fi
    fi

    if [ $attempt -lt $max_retries ]; then
      log_warn "Request failed (attempt $attempt/$max_retries), retrying in ${retry_delay}s..."
      sleep $retry_delay
      retry_delay=$((retry_delay + 1))
    fi
  done

  # Final failure
  echo "$body"
  return 1
}

# Check if 2 VMs already running - IMPORTANT per skill.md
check_vm_limit() {
  log_info "Checking existing sessions..."
  local sessions=$(novm_api_call GET "/sessions" "")
  local count=$(echo "$sessions" | grep -o '"id"' | wc -l || echo "0")
  log_info "Found $count existing session(s)"
  if [ "$count" -ge 2 ]; then
    log_error "Backend can only handle 2 VMs at a time! Found $count running."
    echo "$sessions" | python3 -m json.tool 2>/dev/null || echo "$sessions"
    log_warn "Do you want to terminate a session? Use: $0 delete <SESSION_ID> or $0 list"
    return 1
  fi
  return 0
}

# Commands
cmd_list() {
  log_info "Listing all workstations (GET $NOVM/api/sessions)..."
  local result=$(novm_api_call GET "/sessions" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_create() {
  local name="${1:-Support Desktop}"
  local resolution="${2:-1280x720}"
  local disableTimeouts="${3:-false}"

  # VERY IMPORTANT: Check limit before creating
  if ! check_vm_limit; then
    log_error "Refusing to create new VM - limit reached. Terminate a session first."
    return 1
  fi

  log_info "Creating workstation: name=$name, resolution=$resolution, disableTimeouts=$disableTimeouts"
  local data=$(cat <<EOF
{"name":"$name","resolution":"$resolution","disableTimeouts":$disableTimeouts}
EOF
)
  local result=$(novm_api_call POST "/sessions" "$data")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  
  # Extract ID if possible
  local id=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id',''))" 2>/dev/null || echo "")
  if [ -n "$id" ]; then
    log_success "Created session with ID: $id"
    log_info "Next steps:"
    echo "  $0 start $id"
    echo "  $0 connect $id"
  fi
}

cmd_get() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 get <SESSION_ID>"; return 1; fi
  log_info "Getting status for session $id..."
  local result=$(novm_api_call GET "/sessions/$id" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_start() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 start <SESSION_ID>"; return 1; fi
  log_info "Starting session $id..."
  local result=$(novm_api_call POST "/sessions/$id/start" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_stop() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 stop <SESSION_ID>"; return 1; fi
  log_info "Stopping session $id..."
  local result=$(novm_api_call POST "/sessions/$id/stop" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_pause() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 pause <SESSION_ID>"; return 1; fi
  log_info "Pausing session $id..."
  local result=$(novm_api_call POST "/sessions/$id/pause" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_resume() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 resume <SESSION_ID>"; return 1; fi
  log_info "Resuming session $id..."
  local result=$(novm_api_call POST "/sessions/$id/resume" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_restart() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 restart <SESSION_ID>"; return 1; fi
  log_info "Restarting session $id..."
  local result=$(novm_api_call POST "/sessions/$id/restart" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_recover() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 recover <SESSION_ID>"; return 1; fi
  log_info "Recovering session $id..."
  local result=$(novm_api_call POST "/sessions/$id/recover" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_connect() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 connect <SESSION_ID>"; return 1; fi
  log_info "Getting connection link for session $id (valid 15 min, auto-refreshes while active)..."
  local result=$(novm_api_call POST "/sessions/$id/connect" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  
  local url=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('url',''))" 2>/dev/null || echo "")
  if [ -n "$url" ]; then
    log_success "Connection URL (expires in 15 min):"
    echo "$url"
    log_warn "Share this URL with the user. It auto-refreshes while someone is connected."
    log_warn "If idle 15 min, NoVM stops the workstation and revokes links."
  fi
}

cmd_disconnect() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 disconnect <SESSION_ID>"; return 1; fi
  log_info "Disconnecting session $id (revokes links)..."
  local result=$(novm_api_call POST "/sessions/$id/disconnect" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_delete() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 delete <SESSION_ID>"; return 1; fi
  log_warn "Deleting session $id permanently..."
  read -p "Are you sure? (y/N): " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    log_info "Cancelled"
    return 0
  fi
  local result=$(novm_api_call DELETE "/sessions/$id" "")
  if [ -z "$result" ]; then
    log_success "Session $id deleted (empty response = success)"
  else
    echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  fi
}

cmd_rename() {
  local id="$1"
  local new_name="$2"
  if [ -z "$id" ] || [ -z "$new_name" ]; then log_error "Usage: $0 rename <SESSION_ID> <NEW_NAME>"; return 1; fi
  log_info "Renaming session $id to $new_name..."
  local data="{\"name\":\"$new_name\"}"
  local result=$(novm_api_call PATCH "/sessions/$id" "$data")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_duplicate() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 duplicate <SESSION_ID>"; return 1; fi
  log_info "Duplicating session $id..."
  local result=$(novm_api_call POST "/sessions/$id/duplicate" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_apps_list() {
  log_info "Listing installable apps..."
  local result=$(novm_api_call GET "/apps" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_app_install() {
  local id="$1"
  local appId="$2"
  if [ -z "$id" ] || [ -z "$appId" ]; then log_error "Usage: $0 install-app <SESSION_ID> <APP_ID>"; return 1; fi
  log_info "Installing app $appId on session $id..."
  local data="{\"appId\":\"$appId\"}"
  local result=$(novm_api_call POST "/sessions/$id/apps" "$data")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_files_list() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 files <SESSION_ID>"; return 1; fi
  log_info "Listing files for session $id..."
  local result=$(novm_api_call GET "/sessions/$id/files" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_backups_list() {
  local id="$1"
  if [ -z "$id" ]; then log_error "Usage: $0 backups <SESSION_ID>"; return 1; fi
  log_info "Listing backups for session $id..."
  local result=$(novm_api_call GET "/sessions/$id/backups" "")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
}

cmd_quickstart() {
  local name="${1:-My Desktop}"
  log_info "=== NoVM Quick Start ==="
  log_info "1. Checking existing sessions..."
  cmd_list
  echo ""
  if ! check_vm_limit; then
    log_error "Cannot proceed - too many VMs. Delete one first."
    return 1
  fi
  log_info "2. Creating workstation: $name"
  local data="{\"name\":\"$name\",\"resolution\":\"1280x720\",\"disableTimeouts\":false}"
  local result=$(novm_api_call POST "/sessions" "$data")
  echo "$result" | python3 -m json.tool 2>/dev/null || echo "$result"
  local id=$(echo "$result" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('id',''))" 2>/dev/null || echo "")
  if [ -z "$id" ]; then
    log_error "Failed to create session"
    return 1
  fi
  log_info "3. Starting session $id..."
  sleep 2
  novm_api_call POST "/sessions/$id/start" "" | python3 -m json.tool 2>/dev/null || true
  sleep 3
  log_info "4. Getting connection URL..."
  cmd_connect "$id"
  log_success "Done! Open the URL in your browser."
}

cmd_help() {
  cat <<EOF
NoVM - Workstation Manager CLI
Base URL: $NOVM (fallback: $NOVM_FALLBACK)
Uses \$NOVM env var from .novm dot file

Usage: $0 <command> [args]

Session Management:
  list                          List all workstations (GET /api/sessions)
  create [name] [res] [noTO]    Create workstation (checks 2 VM limit!)
  get <id>                      Get workstation status
  start <id>                    Start a stopped workstation
  stop <id>                     Stop a running workstation
  pause <id>                    Pause desktop (preserves files)
  resume <id>                   Resume paused workstation
  restart <id>                  Restart workstation services
  recover <id>                  Recover stopped/failed workstation
  rename <id> <new_name>        Rename workstation
  duplicate <id>                Duplicate workstation and files
  delete <id>                   STOP AND PERMANENTLY DELETE (use with caution)

Connection:
  connect <id>                  Issue 15-min browser URL (auto-refreshes while active)
  disconnect <id>               Revoke links and close viewers
  quickstart [name]             Create+start+connect in one command

Apps & Files:
  apps                          List installable apps
  install-app <id> <appId>      Install app (e.g. chromium)
  files <id>                    List workstation files
  backups <id>                  List backups

Other:
  help                          Show this help
  env                           Show current env config
  check-limit                   Check if 2 VM limit reached

Examples:
  $0 list
  $0 create "My Desktop" "1920x1080" false
  $0 quickstart "Support Desktop"
  $0 connect SESSION_ID
  $0 install-app SESSION_ID chromium
  $0 delete SESSION_ID

Operational Notes:
  - Connection links expire in 15 min, auto-refresh while active
  - If idle 15 min, NoVM stops workstation and revokes links
  - Use disableTimeouts=true only for trusted manually managed workstations
  - Empty response on DELETE = success
  - API can return "Rate exceeded." - script auto-retries with backoff

Dot file: .novm contains base URL, corresponds to \$NOVM env var
EOF
}

cmd_env() {
  echo "NOVM=$NOVM"
  echo "NOVM_FALLBACK=$NOVM_FALLBACK"
  echo "Dot file (.novm): $(cat "$SCRIPT_DIR/.novm" 2>/dev/null || echo 'not found')"
  echo "Script dir: $SCRIPT_DIR"
}

# Main dispatcher
case "${1:-help}" in
  list|ls) cmd_list ;;
  create|new) cmd_create "$2" "$3" "$4" ;;
  get|status) cmd_get "$2" ;;
  start) cmd_start "$2" ;;
  stop) cmd_stop "$2" ;;
  pause) cmd_pause "$2" ;;
  resume) cmd_resume "$2" ;;
  restart) cmd_restart "$2" ;;
  recover) cmd_recover "$2" ;;
  connect|url) cmd_connect "$2" ;;
  disconnect) cmd_disconnect "$2" ;;
  delete|rm|terminate) cmd_delete "$2" ;;
  rename) cmd_rename "$2" "$3" ;;
  duplicate|clone) cmd_duplicate "$2" ;;
  apps|apps-list) cmd_apps_list ;;
  install-app|install) cmd_app_install "$2" "$3" ;;
  files|ls-files) cmd_files_list "$2" ;;
  backups) cmd_backups_list "$2" ;;
  quickstart|qs) cmd_quickstart "$2" ;;
  env) cmd_env ;;
  check-limit) check_vm_limit ;;
  help|--help|-h) cmd_help ;;
  *) log_error "Unknown command: $1"; cmd_help; exit 1 ;;
esac
