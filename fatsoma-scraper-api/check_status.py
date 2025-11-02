#!/usr/bin/env python3
"""
Quick server status checker
Usage: python check_status.py
"""
import requests
import sys
import json
from datetime import datetime

PORT = 8000
BASE_URL = f"http://localhost:{PORT}"

def check_health():
    """Check if server is healthy"""
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=2)
        return response.status_code == 200, response.json()
    except requests.exceptions.ConnectionError:
        return False, {"error": "Server not responding"}
    except Exception as e:
        return False, {"error": str(e)}

def get_status():
    """Get detailed server status"""
    try:
        response = requests.get(f"{BASE_URL}/status", timeout=2)
        return response.status_code == 200, response.json()
    except requests.exceptions.ConnectionError:
        return False, {"error": "Server not responding"}
    except Exception as e:
        return False, {"error": str(e)}

def main():
    print("\n🔍 Checking Fatsoma Scraper API Status...\n")

    # Check health
    healthy, health_data = check_health()

    if not healthy:
        print("❌ Server is NOT running or not responding")
        if "error" in health_data:
            print(f"   Error: {health_data['error']}")
        sys.exit(1)

    # Get detailed status
    ok, status_data = get_status()

    if status_data.get("ready"):
        print("✅ Server is READY")
    else:
        print("⏳ Server is STARTING (not ready yet)")

    print(f"\n📊 Status Details:")
    print(f"   Server:           {status_data.get('server', 'unknown')}")
    print(f"   Ready:            {'Yes' if status_data.get('ready') else 'No'}")
    print(f"   Startup Complete: {'Yes' if status_data.get('startup_complete') else 'No'}")
    print(f"   Is Syncing:       {'Yes' if status_data.get('is_syncing') else 'No'}")

    if status_data.get('last_sync'):
        print(f"   Last Sync:        {status_data['last_sync']}")

    if 'database' in status_data:
        db = status_data['database']
        print(f"\n💾 Database:")
        print(f"   Total Events:     {db.get('total_events', 0)}")
        if db.get('latest_update'):
            print(f"   Latest Update:    {db['latest_update']}")

    print(f"\n🌐 API Endpoints:")
    print(f"   Health:  {BASE_URL}/health")
    print(f"   Status:  {BASE_URL}/status")
    print(f"   Docs:    {BASE_URL}/docs")
    print(f"   Events:  {BASE_URL}/events")
    print()

if __name__ == "__main__":
    main()
