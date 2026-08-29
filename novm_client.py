#!/usr/bin/env python3
"""
NoVM Python Client - Workstation Manager
Implements full NoVM HTTP API for https://virtual-xfce-spin--ogsincord.replit.app/
Uses $NOVM env var from .novm dot file.

Install: pip install requests (or use urllib if requests unavailable)
Usage:
    from novm_client import NoVMClient
    client = NoVMClient()
    sessions = client.list_sessions()
    session = client.create_session(name="My Desktop")
    client.start_session(session['id'])
    link = client.connect_session(session['id'])
    print(link['url'])
"""

import os
import json
import time
import base64
import pathlib
from typing import Optional, Dict, List, Any

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False
    import urllib.request
    import urllib.error
    import urllib.parse

# Load base URL from dot file or env
def _load_base_url() -> str:
    # Check .novm file in same dir, home, and current dir
    possible_paths = [
        pathlib.Path(__file__).parent / ".novm",
        pathlib.Path.cwd() / ".novm",
        pathlib.Path.home() / ".novm",
        pathlib.Path.home() / ".novmrc",
    ]
    for p in possible_paths:
        if p.exists():
            try:
                content = p.read_text().strip()
                # If it's a shell file with export, parse it
                if "export NOVM=" in content or "NOVM=" in content:
                    for line in content.splitlines():
                        if "NOVM=" in line and "FALLBACK" not in line and "PRIMARY" not in line:
                            # Extract URL
                            url = line.split("=", 1)[1].strip().strip('"').strip("'").strip()
                            if url.startswith("http"):
                                return url if url.endswith("/") else url + "/"
                elif content.startswith("http"):
                    url = content.splitlines()[0].strip()
                    return url if url.endswith("/") else url + "/"
            except Exception:
                continue
    
    # Env var
    env_url = os.getenv("NOVM") or os.getenv("NOVM_API") or os.getenv("NOVM_PRIMARY")
    if env_url:
        return env_url if env_url.endswith("/") else env_url + "/"
    
    # Default - user's requested URL
    return "https://virtual-xfce-spin--ogsincord.replit.app/"

DEFAULT_BASE_URL = _load_base_url()
FALLBACK_URL = os.getenv("NOVM_FALLBACK", "https://no-vm-desktop-fix--novm4.replit.app/")
if not FALLBACK_URL.endswith("/"):
    FALLBACK_URL += "/"


class NoVMError(Exception):
    pass

class RateLimitError(NoVMError):
    pass

class VMLimitError(NoVMError):
    pass


class NoVMClient:
    """
    NoVM Workstation Manager Client
    Handles all endpoints documented in skill.md
    """

    def __init__(self, base_url: Optional[str] = None, fallback_url: Optional[str] = None, timeout: int = 30):
        self.base_url = (base_url or DEFAULT_BASE_URL).rstrip("/") + "/"
        self.fallback_url = (fallback_url or FALLBACK_URL).rstrip("/") + "/"
        self.timeout = timeout
        self.session = None
        if HAS_REQUESTS:
            self.session = requests.Session()
            self.session.headers.update({"Content-Type": "application/json"})

    def _api_url(self, endpoint: str, use_fallback: bool = False) -> str:
        base = self.fallback_url if use_fallback else self.base_url
        # Ensure endpoint starts with /
        if not endpoint.startswith("/"):
            endpoint = "/" + endpoint
        # API prefix
        if not endpoint.startswith("/api"):
            endpoint = "/api" + endpoint
        return base.rstrip("/") + endpoint

    def _request(self, method: str, endpoint: str, data: Optional[Dict] = None, max_retries: int = 3) -> Any:
        """
        Make API request with retry and fallback handling
        """
        retry_delay = 2
        last_error = None

        for attempt in range(1, max_retries + 1):
            for use_fallback in [False, True] if attempt == max_retries else [False]:
                url = self._api_url(endpoint, use_fallback=use_fallback)
                try:
                    if HAS_REQUESTS:
                        resp = self.session.request(
                            method, url,
                            json=data if data is not None else None,
                            timeout=self.timeout
                        )
                        text = resp.text
                        # Rate limiting
                        if "Rate exceeded" in text:
                            if attempt < max_retries:
                                time.sleep(retry_delay)
                                retry_delay *= 2
                                continue
                            raise RateLimitError("Rate exceeded")
                        
                        # Empty body on DELETE = success
                        if not text and resp.status_code == 200 and method == "DELETE":
                            return {"success": True, "message": "Deleted"}

                        if text:
                            try:
                                return json.loads(text)
                            except json.JSONDecodeError:
                                # If not JSON but 2xx, return text
                                if 200 <= resp.status_code < 300:
                                    return {"raw": text, "status_code": resp.status_code}
                                raise NoVMError(f"Non-JSON response {resp.status_code}: {text[:500]}")
                        else:
                            if 200 <= resp.status_code < 300:
                                return {"success": True, "status_code": resp.status_code}
                            raise NoVMError(f"Empty response with status {resp.status_code}")

                    else:
                        # urllib fallback
                        req_data = None
                        headers = {"Content-Type": "application/json"}
                        if data is not None:
                            req_data = json.dumps(data).encode('utf-8')
                        
                        req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
                        try:
                            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                                text = r.read().decode('utf-8')
                                if "Rate exceeded" in text:
                                    if attempt < max_retries:
                                        time.sleep(retry_delay)
                                        retry_delay *= 2
                                        continue
                                    raise RateLimitError("Rate exceeded")
                                if not text and method == "DELETE":
                                    return {"success": True}
                                if text:
                                    try:
                                        return json.loads(text)
                                    except json.JSONDecodeError:
                                        return {"raw": text}
                                return {"success": True}
                        except urllib.error.HTTPError as e:
                            body = e.read().decode('utf-8', errors='ignore')
                            if "Rate exceeded" in body:
                                if attempt < max_retries:
                                    time.sleep(retry_delay)
                                    retry_delay *= 2
                                    continue
                                raise RateLimitError("Rate exceeded")
                            if body:
                                try:
                                    return json.loads(body)
                                except:
                                    raise NoVMError(f"HTTP {e.code}: {body[:500]}")
                            raise NoVMError(f"HTTP {e.code} empty")

                except RateLimitError:
                    raise
                except Exception as e:
                    last_error = e
                    if attempt < max_retries:
                        time.sleep(retry_delay)
                        retry_delay += 1
                    continue

            if attempt < max_retries:
                time.sleep(retry_delay)

        raise NoVMError(f"Failed after {max_retries} attempts: {last_error}")

    # === Core Session Management ===

    def list_sessions(self) -> List[Dict]:
        """GET /api/sessions - List all workstations"""
        result = self._request("GET", "/sessions")
        # API may return list or dict with sessions key
        if isinstance(result, list):
            return result
        if isinstance(result, dict) and "sessions" in result:
            return result["sessions"]
        return result

    def check_vm_limit(self) -> int:
        """
        Check if 2 VMs already running.
        Returns count. Raises VMLimitError if >=2 per skill.md rule.
        """
        sessions = self.list_sessions()
        if isinstance(sessions, list):
            count = len(sessions)
        elif isinstance(sessions, dict):
            count = len(sessions.get("sessions", [])) if isinstance(sessions.get("sessions"), list) else 1
        else:
            count = 0

        if count >= 2:
            raise VMLimitError(
                f"Backend can only handle 2 VMs at a time for now. Found {count} running. "
                f"Terminate a session first? Sessions: {sessions}"
            )
        return count

    def create_session(self, name: str = "Support Desktop", resolution: str = "1280x720", disable_timeouts: bool = False) -> Dict:
        """
        POST /api/sessions - Create workstation
        IMPORTANT: Checks 2 VM limit before creating per skill.md
        """
        try:
            self.check_vm_limit()
        except VMLimitError as e:
            print(f"[NoVM] {e}")
            raise

        data = {
            "name": name,
            "resolution": resolution,
            "disableTimeouts": disable_timeouts
        }
        return self._request("POST", "/sessions", data)

    def get_session(self, session_id: str) -> Dict:
        """GET /api/sessions/{id} - Get workstation status"""
        return self._request("GET", f"/sessions/{session_id}")

    def start_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/start"""
        return self._request("POST", f"/sessions/{session_id}/start")

    def stop_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/stop"""
        return self._request("POST", f"/sessions/{session_id}/stop")

    def pause_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/pause"""
        return self._request("POST", f"/sessions/{session_id}/pause")

    def resume_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/resume"""
        return self._request("POST", f"/sessions/{session_id}/resume")

    def restart_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/restart"""
        return self._request("POST", f"/sessions/{session_id}/restart")

    def recover_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/recover"""
        return self._request("POST", f"/sessions/{session_id}/recover")

    def rename_session(self, session_id: str, new_name: str) -> Dict:
        """PATCH /api/sessions/{id} - Rename workstation"""
        return self._request("PATCH", f"/sessions/{session_id}", {"name": new_name})

    def duplicate_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/duplicate"""
        return self._request("POST", f"/sessions/{session_id}/duplicate")

    def delete_session(self, session_id: str) -> Dict:
        """
        DELETE /api/sessions/{id} - Stop and permanently delete
        Empty response = success per skill.md
        """
        return self._request("DELETE", f"/sessions/{session_id}")

    # === Connection Management ===

    def connect_session(self, session_id: str) -> Dict:
        """
        POST /api/sessions/{id}/connect - Issue 15-min desktop URL
        Returns: {"url": "https://.../api/novnc/viewer?token=...", "expiresInSeconds": 900, ...}
        """
        result = self._request("POST", f"/sessions/{session_id}/connect")
        if "url" in result:
            print(f"[NoVM] Connection URL (15 min, auto-refreshes while active): {result['url']}")
            print(f"[NoVM] Expires in: {result.get('expiresInSeconds', 900)}s")
        return result

    def disconnect_session(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/disconnect - Revoke links and close viewers"""
        return self._request("POST", f"/sessions/{session_id}/disconnect")

    def disconnect_request(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/disconnect/request - Disconnect vote for shared sessions"""
        return self._request("POST", f"/sessions/{session_id}/disconnect/request")

    # === Apps Management ===

    def list_apps(self) -> Dict:
        """GET /api/apps - List apps available to install"""
        return self._request("GET", "/apps")

    def install_app(self, session_id: str, app_id: str) -> Dict:
        """POST /api/sessions/{id}/apps - Install app by id"""
        return self._request("POST", f"/sessions/{session_id}/apps", {"appId": app_id})

    def install_custom_app(self, session_id: str, package_data: Dict) -> Dict:
        """POST /api/sessions/{id}/apps/custom - Register and install custom app"""
        return self._request("POST", f"/sessions/{session_id}/apps/custom", package_data)

    def install_deb(self, session_id: str, file_name: str, content_base64: str) -> Dict:
        """POST /api/sessions/{id}/apps/deb - Upload/install .deb"""
        return self._request("POST", f"/sessions/{session_id}/apps/deb", {
            "fileName": file_name,
            "contentBase64": content_base64
        })

    def update_app(self, session_id: str, app_id: str) -> Dict:
        """POST /api/sessions/{id}/apps/{appId}/update"""
        return self._request("POST", f"/sessions/{session_id}/apps/{app_id}/update")

    # === Profiles ===

    def list_profiles(self, session_id: str) -> Dict:
        """GET /api/sessions/{id}/profiles - List Chromium profiles"""
        return self._request("GET", f"/sessions/{session_id}/profiles")

    def create_profile(self, session_id: str, profile_data: Dict) -> Dict:
        """POST /api/sessions/{id}/profiles - Create Chromium profile"""
        return self._request("POST", f"/sessions/{session_id}/profiles", profile_data)

    # === Files Management ===

    def list_files(self, session_id: str) -> Dict:
        """GET /api/sessions/{id}/files - List workstation and shared files"""
        return self._request("GET", f"/sessions/{session_id}/files")

    def upload_file(self, session_id: str, file_name: str, content_base64: str, path: Optional[str] = None) -> Dict:
        """POST /api/sessions/{id}/files - Upload base64-encoded file"""
        data = {"fileName": file_name, "contentBase64": content_base64}
        if path:
            data["path"] = path
        return self._request("POST", f"/sessions/{session_id}/files", data)

    def download_file(self, session_id: str, file_path: str) -> Dict:
        """GET /api/sessions/{id}/files/download - Download file"""
        # This endpoint uses query param
        return self._request("GET", f"/sessions/{session_id}/files/download?path={file_path}")

    def upload_local_file(self, session_id: str, local_path: str, remote_name: Optional[str] = None) -> Dict:
        """Helper to upload a local file"""
        p = pathlib.Path(local_path)
        if not p.exists():
            raise FileNotFoundError(f"Local file not found: {local_path}")
        content = p.read_bytes()
        b64 = base64.b64encode(content).decode('utf-8')
        return self.upload_file(session_id, remote_name or p.name, b64)

    # === Backups ===

    def create_backup(self, session_id: str) -> Dict:
        """POST /api/sessions/{id}/backups - Create filesystem backup"""
        return self._request("POST", f"/sessions/{session_id}/backups")

    def list_backups(self, session_id: str) -> Dict:
        """GET /api/sessions/{id}/backups - List available backups"""
        return self._request("GET", f"/sessions/{session_id}/backups")

    def restore_backup(self, session_id: str, backup_id: str) -> Dict:
        """POST /api/sessions/{id}/backups/{backupId}/restore - Restore backup (stops desktop first)"""
        return self._request("POST", f"/sessions/{session_id}/backups/{backup_id}/restore")

    # === Permissions ===

    def request_permission(self, session_id: str, permission_data: Dict) -> Dict:
        """POST /api/sessions/{id}/permissions/request - Ask viewers to approve host permission"""
        return self._request("POST", f"/sessions/{session_id}/permissions/request", permission_data)

    # === Quickstart Workflow ===

    def quickstart(self, name: str = "Support Desktop", resolution: str = "1280x720", wait_seconds: int = 5) -> Dict:
        """
        Full quickstart: create + start + connect
        Returns dict with session and connection info
        """
        print(f"[NoVM] Quickstart: {name} ({resolution})")
        print(f"[NoVM] Base URL: {self.base_url}")

        # 1. List existing
        try:
            sessions = self.list_sessions()
            print(f"[NoVM] Existing sessions: {sessions}")
        except Exception as e:
            print(f"[NoVM] Could not list sessions (might be first run): {e}")

        # 2. Create
        print("[NoVM] Creating workstation...")
        session = self.create_session(name=name, resolution=resolution)
        session_id = session.get("id")
        if not session_id:
            raise NoVMError(f"Failed to get session id from creation response: {session}")
        print(f"[NoVM] Created session {session_id}")

        # 3. Start (wait a bit)
        time.sleep(1)
        print(f"[NoVM] Starting session {session_id}...")
        try:
            self.start_session(session_id)
        except Exception as e:
            print(f"[NoVM] Start returned (might already be starting): {e}")

        print(f"[NoVM] Waiting {wait_seconds}s for startup...")
        time.sleep(wait_seconds)

        # 4. Connect
        print(f"[NoVM] Getting connection link...")
        connection = self.connect_session(session_id)

        result = {
            "session": session,
            "session_id": session_id,
            "connection": connection,
            "url": connection.get("url", ""),
            "message": f"I've successfully spun up your NoVM machine and you can access it at: {connection.get('url','')}"
        }
        print(f"[NoVM] {result['message']}")
        return result


# === CLI for direct usage ===
if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="NoVM Workstation Manager CLI (Python)")
    parser.add_argument("--base-url", default=None, help="Base URL override (default from .novm or env $NOVM)")
    parser.add_argument("--fallback-url", default=None, help="Fallback URL")
    
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="List all workstations")
    sub.add_parser("apps", help="List installable apps")

    p_create = sub.add_parser("create", help="Create workstation")
    p_create.add_argument("--name", default="Support Desktop")
    p_create.add_argument("--resolution", default="1280x720")
    p_create.add_argument("--disable-timeouts", action="store_true")

    p_get = sub.add_parser("get", help="Get workstation status")
    p_get.add_argument("id")

    for cmd in ["start", "stop", "pause", "resume", "restart", "recover", "connect", "disconnect", "delete", "duplicate", "files", "backups"]:
        p = sub.add_parser(cmd)
        p.add_argument("id", help="Session ID")

    p_rename = sub.add_parser("rename")
    p_rename.add_argument("id")
    p_rename.add_argument("new_name")

    p_install = sub.add_parser("install-app")
    p_install.add_argument("id")
    p_install.add_argument("appId")

    p_qs = sub.add_parser("quickstart", help="Create+start+connect in one")
    p_qs.add_argument("--name", default="Support Desktop")
    p_qs.add_argument("--resolution", default="1280x720")

    args = parser.parse_args()

    client = NoVMClient(base_url=args.base_url, fallback_url=args.fallback_url)

    try:
        if args.command == "list":
            print(json.dumps(client.list_sessions(), indent=2))
        elif args.command == "apps":
            print(json.dumps(client.list_apps(), indent=2))
        elif args.command == "create":
            result = client.create_session(name=args.name, resolution=args.resolution, disable_timeouts=args.disable_timeouts)
            print(json.dumps(result, indent=2))
        elif args.command == "get":
            print(json.dumps(client.get_session(args.id), indent=2))
        elif args.command == "start":
            print(json.dumps(client.start_session(args.id), indent=2))
        elif args.command == "stop":
            print(json.dumps(client.stop_session(args.id), indent=2))
        elif args.command == "pause":
            print(json.dumps(client.pause_session(args.id), indent=2))
        elif args.command == "resume":
            print(json.dumps(client.resume_session(args.id), indent=2))
        elif args.command == "restart":
            print(json.dumps(client.restart_session(args.id), indent=2))
        elif args.command == "recover":
            print(json.dumps(client.recover_session(args.id), indent=2))
        elif args.command == "connect":
            print(json.dumps(client.connect_session(args.id), indent=2))
        elif args.command == "disconnect":
            print(json.dumps(client.disconnect_session(args.id), indent=2))
        elif args.command == "delete":
            print(json.dumps(client.delete_session(args.id), indent=2))
        elif args.command == "duplicate":
            print(json.dumps(client.duplicate_session(args.id), indent=2))
        elif args.command == "rename":
            print(json.dumps(client.rename_session(args.id, args.new_name), indent=2))
        elif args.command == "install-app":
            print(json.dumps(client.install_app(args.id, args.appId), indent=2))
        elif args.command == "files":
            print(json.dumps(client.list_files(args.id), indent=2))
        elif args.command == "backups":
            print(json.dumps(client.list_backups(args.id), indent=2))
        elif args.command == "quickstart":
            result = client.quickstart(name=args.name, resolution=args.resolution)
            print(json.dumps(result, indent=2))
    except VMLimitError as e:
        print(f"VM Limit Error: {e}")
        print("Prompt user if they would like to terminate a session.")
        exit(2)
    except Exception as e:
        print(f"Error: {e}")
        exit(1)
