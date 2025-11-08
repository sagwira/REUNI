#!/bin/bash
# Stop API server and ngrok tunnel

echo "🛑 Stopping REUNI API server..."

# Stop using PID files if they exist
if [ -f /tmp/reuni-api.pid ]; then
    API_PID=$(cat /tmp/reuni-api.pid)
    kill $API_PID 2>/dev/null && echo "✅ Stopped API server (PID: $API_PID)"
    rm /tmp/reuni-api.pid
fi

if [ -f /tmp/reuni-ngrok.pid ]; then
    NGROK_PID=$(cat /tmp/reuni-ngrok.pid)
    kill $NGROK_PID 2>/dev/null && echo "✅ Stopped ngrok (PID: $NGROK_PID)"
    rm /tmp/reuni-ngrok.pid
fi

# Fallback: kill by process name
pkill -f 'python main.py' 2>/dev/null && echo "✅ Stopped all Python API processes"
pkill ngrok 2>/dev/null && echo "✅ Stopped all ngrok processes"

echo ""
echo "✅ All services stopped"
