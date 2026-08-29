#!/usr/bin/env python3
"""Agent control demo - vision capable VM interaction"""
from tools.agent_control import NoVMAgentController, check_vision_capability
import json

if not check_vision_capability():
    print("Only vision capable models can interact with NoVM Virtual Machines, "
          "if you are not a vision capable model politely explain that and prompt the user to start a new chat")
    exit(1)

controller = NoVMAgentController()
print("Ensuring session (checks 2 VM limit)...")
# session = controller.ensure_session(name="Agent Demo Desktop")
# print(f"Session: {session}")

print("\nAgent workflow:")
print("1. Get connection URL (15 min expiry)")
print("2. Take screenshot of desktop")
print("3. Analyze, plan next action")
print("4. Use bash to send command to VM")
print("\nExample task execution (would open browser):")
# result = controller.execute_task("Open terminal and run 'ls -la'")
# print(json.dumps(result, indent=2))

print("\nIn real agent chat, you'd say:")
print("'I've successfully spun up your NoVM machine and you can access it at: <URL>'")
