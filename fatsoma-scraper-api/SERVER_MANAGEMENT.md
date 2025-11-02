# Server Management Guide

This document explains how to manage and monitor the Fatsoma Scraper API server.

## Quick Start

### Check Server Status
```bash
# Option 1: Using Python script (detailed)
python check_status.py

# Option 2: Using shell script
./server_manager.sh status

# Option 3: Using curl directly
curl http://localhost:8000/status | python -m json.tool
```

### Start/Stop Server
```bash
# Start the server
./server_manager.sh start

# Stop the server
./server_manager.sh stop

# Restart the server
./server_manager.sh restart
```

### View Logs
```bash
# Show recent logs
./server_manager.sh logs

# Follow logs in real-time
tail -f server.log
```

## Server Status Indicators

### Ready States
- **✅ READY**: Server has completed startup sync and is accepting requests
- **⏳ STARTING**: Server is running but still syncing events (wait 2-3 minutes)
- **❌ NOT RUNNING**: Server is not running

### Status Fields
- `ready`: Server is ready to accept API requests
- `startup_complete`: Initial startup sync has finished
- `is_syncing`: Currently syncing events
- `last_sync`: Timestamp of last successful sync

## API Endpoints

### Health Check
```bash
curl http://localhost:8000/health
```
Returns basic health status:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-29T16:20:52.028"
}
```

### Detailed Status
```bash
curl http://localhost:8000/status
```
Returns comprehensive server status:
```json
{
  "server": "running",
  "ready": true,
  "startup_complete": true,
  "is_syncing": false,
  "last_sync": "2025-10-29T16:25:30.123",
  "database": {
    "total_events": 500,
    "latest_update": "2025-10-29T16:25:30.000"
  },
  "timestamp": "2025-10-29T16:30:00.000"
}
```

### Other Endpoints
- `/` - API info
- `/events` - List all events
- `/events/{event_id}` - Get specific event
- `/docs` - Interactive API documentation
- `/fixr/extract-transfer` - Extract Fixr transfer ticket data

## Understanding Server Startup

### Why Does Startup Take 2-3 Minutes?

When the server starts, it performs an initial sync of all events from the Fatsoma API and syncs them to Supabase. This includes:

1. Fetching 500+ events from Fatsoma API
2. Creating/updating organizers in Supabase
3. Syncing all events to Supabase
4. Cleaning up past events

### Monitoring Startup Progress

**Watch logs in real-time:**
```bash
tail -f server.log
```

**Look for these log messages:**
- `🚀 Server starting up...` - Server process started
- `📅 Scheduler started` - Background scheduler initialized
- `🔄 Running initial event sync...` - Starting event fetch
- `Starting event update at...` - Sync in progress
- `✅ Server startup complete - ready to accept requests!` - Ready!

**Check status programmatically:**
```bash
# Keep checking until ready
while true; do
  python check_status.py && break
  sleep 5
done
```

## Common Scenarios

### Scenario 1: Testing Fixr Transfer Feature
```bash
# 1. Check if server is ready
python check_status.py

# 2. If not ready, wait and monitor
tail -f server.log

# 3. Once you see "✅ Server startup complete", test from iOS app
```

### Scenario 2: Server Not Responding
```bash
# 1. Check if process is running
./server_manager.sh status

# 2. If running but not responding, check logs
./server_manager.sh logs

# 3. Restart if needed
./server_manager.sh restart
```

### Scenario 3: Quick Server Restart
```bash
# Stop and start with one command
./server_manager.sh restart
```

## Troubleshooting

### "Server is STARTING" for Too Long
If the server shows "STARTING" status for more than 5 minutes:
1. Check logs: `./server_manager.sh logs`
2. Look for error messages
3. Restart: `./server_manager.sh restart`

### "Connection Refused" Error
If you get connection errors:
1. Verify server is running: `./server_manager.sh status`
2. If not running, start it: `./server_manager.sh start`
3. Check port 8000 is not in use: `lsof -i :8000`

### Slow API Responses
If API is slow after startup:
1. Check if syncing: `curl http://localhost:8000/status`
2. If `is_syncing: true`, wait for sync to complete
3. Subsequent syncs happen every 6 hours in background

## Tips

### Quick Status Check
Add this alias to your `.zshrc` or `.bashrc`:
```bash
alias apistat='cd ~/Documents/REUNI/fatsoma-scraper-api && python check_status.py'
```

### Auto-Start on Mac Login
Create a LaunchAgent to start server automatically (optional):
```bash
# Create plist file at ~/Library/LaunchAgents/com.reuni.api.plist
# Then: launchctl load ~/Library/LaunchAgents/com.reuni.api.plist
```

### Monitor in Terminal Tab
Keep a terminal tab open with:
```bash
watch -n 2 'curl -s http://localhost:8000/status | python -m json.tool'
```

## Files Reference

- `server_manager.sh` - Main management script
- `check_status.py` - Status checker
- `server.log` - Server logs
- `.server.pid` - Process ID file
- `main.py` - API server code
