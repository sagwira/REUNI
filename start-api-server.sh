#!/bin/bash
# Start API server and ngrok tunnel automatically
# Run this whenever you restart your Mac

cd "$(dirname "$0")/fatsoma-scraper-api"

echo "🚀 Starting REUNI API server..."

# Activate virtual environment
source venv/bin/activate

# Start Python API in background
python main.py > /tmp/reuni-api.log 2>&1 &
API_PID=$!

echo "✅ API server started (PID: $API_PID)"
echo "📝 Logs: /tmp/reuni-api.log"

# Wait for API to be ready
sleep 3

# Start ngrok tunnel
echo "🌐 Starting ngrok tunnel..."
ngrok http 8000 --log=stdout > /tmp/ngrok.log 2>&1 &
NGROK_PID=$!

echo "✅ ngrok started (PID: $NGROK_PID)"

# Wait for ngrok to start
sleep 3

# Get public URL
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['tunnels'][0]['public_url'] if data.get('tunnels') else 'No tunnel')" 2>/dev/null)

echo ""
echo "========================================="
echo "✅ REUNI API Server is running!"
echo "========================================="
echo "Local URL:  http://localhost:8000"
echo "Public URL: $NGROK_URL"
echo ""
echo "API PID:    $API_PID"
echo "ngrok PID:  $NGROK_PID"
echo ""
echo "To stop:"
echo "  kill $API_PID $NGROK_PID"
echo ""
echo "Or run:"
echo "  pkill -f 'python main.py'"
echo "  pkill ngrok"
echo "========================================="

# Save PIDs to file for easy stopping
echo "$API_PID" > /tmp/reuni-api.pid
echo "$NGROK_PID" > /tmp/reuni-ngrok.pid
