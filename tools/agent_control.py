#!/usr/bin/env python3
"""
Agent Control for NoVM - Vision capable VM control
Per skill.md: You are able to control a NoVM Virtual Machine over NoVNC Websockets.
To properly use the Virtual machine you must take a screenshot of the desktop,
look at it, plan next action then use Bash to send a command to the VM.

This module provides helpers for vision models to interact with NoVM.

Only vision capable models can interact with NoVM VMs, if you are not a vision
capable model politely explain that and prompt the user to start a new chat.
"""

import os
import json
import base64
import time
from typing import Optional

from novm_client import NoVMClient, _load_base_url

class NoVMAgentController:
    """
    Helper for agent to control VM via screenshots and bash commands
    This is a conceptual implementation - actual VNC interaction requires
    websockets and screenshot capability.
    """

    def __init__(self, base_url: Optional[str] = None):
        self.client = NoVMClient(base_url=base_url)
        self.current_session_id: Optional[str] = None
        self.current_connection: Optional[dict] = None

    def ensure_session(self, name: str = "Agent Controlled Desktop") -> dict:
        """Ensure we have a running session"""
        sessions = self.client.list_sessions()
        if isinstance(sessions, list) and len(sessions) > 0:
            # Use first running session
            for s in sessions:
                if s.get("status") == "running":
                    self.current_session_id = s["id"]
                    print(f"[Agent] Reusing existing session: {self.current_session_id}")
                    return s
        
        # Create new one (checks 2 VM limit internally)
        print("[Agent] Creating new session for agent control...")
        session = self.client.create_session(name=name, resolution="1280x720")
        self.current_session_id = session["id"]
        
        # Start it
        self.client.start_session(self.current_session_id)
        time.sleep(5)
        
        return session

    def get_connection_url(self, session_id: Optional[str] = None) -> str:
        """Get fresh connection URL (15 min expiry, auto-refreshes while active)"""
        sid = session_id or self.current_session_id
        if not sid:
            raise ValueError("No session ID - call ensure_session first")
        
        conn = self.client.connect_session(sid)
        self.current_connection = conn
        url = conn.get("url", "")
        print(f"[Agent] Connection URL: {url}")
        print(f"[Agent] Expires in {conn.get('expiresInSeconds', 900)}s")
        return url

    def screenshot_instruction(self) -> str:
        """
        Returns instruction for vision model to take screenshot
        In real implementation, this would capture VNC frame
        """
        return """
        To control the NoVM:
        1. Open the connection URL in browser: {url}
        2. Take a screenshot of the XFCE desktop
        3. Analyze the screenshot - what do you see? What's the task?
        4. Plan next action
        5. Use bash to send command to VM via API or via VNC input

        For bash commands inside VM, you would use the VM's terminal.
        If you need to install apps: use client.install_app(session_id, appId)
        
        Remember:
        - Connection links are temporary (15 min) but auto-refresh while active
        - If idle 15 min, NoVM stops workstation and revokes links
        - Always get fresh URL if link doesn't load
        """.format(url=self.current_connection.get("url") if self.current_connection else "GET URL FIRST via connect_session")

    def execute_task(self, task_description: str) -> dict:
        """
        High-level task execution for agent
        """
        if not self.current_session_id:
            self.ensure_session()
        
        url = self.get_connection_url()
        
        return {
            "session_id": self.current_session_id,
            "connection_url": url,
            "task": task_description,
            "instructions": self.screenshot_instruction(),
            "next_steps": [
                "1. Open URL in browser",
                "2. Take screenshot",
                "3. Analyze and plan",
                "4. Use bash to interact",
                f"5. For this task: {task_description}"
            ]
        }


def check_vision_capability() -> bool:
    """
    Check if current model is vision capable
    In real agent environment, this would check model capabilities
    """
    # For now, assume we can check via env var
    return os.getenv("VISION_CAPABLE", "true").lower() == "true"


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="NoVM Agent Controller")
    parser.add_argument("--task", default="Open terminal and list files", help="Task to perform")
    parser.add_argument("--name", default="Agent Desktop")
    args = parser.parse_args()

    if not check_vision_capability():
        print("Only vision capable models can interact with NoVM Virtual Machines, if you are not a vision capable model politely explain that and prompt the user to start a new chat")
        exit(1)

    controller = NoVMAgentController()
    result = controller.execute_task(args.task)
    print(json.dumps(result, indent=2))
