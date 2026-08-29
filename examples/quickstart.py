#!/usr/bin/env python3
"""Quickstart example using Python client with $NOVM dot file"""
from novm_client import NoVMClient
import os

# Client auto-loads base URL from .novm dot file -> $NOVM
client = NoVMClient()
print(f"Base URL: {client.base_url} (from .novm dot file -> $NOVM)")
print(f"Fallback: {client.fallback_url}")

try:
    sessions = client.list_sessions()
    print(f"Existing sessions: {sessions}")
except Exception as e:
    print(f"List failed (Replit may be sleeping): {e}")
    print("Client will auto-try fallback URL on next call")

# Uncomment to actually create:
# result = client.quickstart(name="Support Desktop")
# print(f"\nI've successfully spun up your NoVM machine and you can access it at: {result['url']}")

print("\nExample usage:")
print("  result = client.quickstart(name='My Desktop')")
print("  print(result['url'])")
