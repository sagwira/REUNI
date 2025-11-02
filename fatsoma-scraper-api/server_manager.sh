#!/bin/bash

# Fatsoma Scraper API - Server Management Script
# Usage: ./server_manager.sh [start|stop|restart|status|logs]

API_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$API_DIR/.server.pid"
LOG_FILE="$API_DIR/server.log"
PORT=8000

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if server is running
is_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

# Function to get server status from API
get_api_status() {
    curl -s http://localhost:$PORT/status 2>/dev/null
}

# Function to start the server
start_server() {
    if is_running; then
        echo -e "${YELLOW}⚠️  Server is already running (PID: $(cat $PID_FILE))${NC}"
        return 1
    fi

    echo -e "${BLUE}🚀 Starting Fatsoma Scraper API...${NC}"

    cd "$API_DIR"
    source venv/bin/activate

    # Start server in background
    nohup uvicorn main:app --host 0.0.0.0 --port $PORT > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    echo -e "${GREEN}✅ Server started (PID: $(cat $PID_FILE))${NC}"
    echo -e "${BLUE}📋 Log file: $LOG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}⏳ Waiting for server to be ready (this may take 2-3 minutes)...${NC}"
    echo -e "${BLUE}   The server is syncing events from the database...${NC}"
    echo ""

    # Wait for server to be ready
    for i in {1..60}; do
        sleep 3
        STATUS=$(curl -s http://localhost:$PORT/health 2>/dev/null)
        if echo "$STATUS" | grep -q "healthy"; then
            echo -e "\n${GREEN}✅ Server is ready!${NC}"
            echo ""
            show_status
            return 0
        fi
        echo -n "."
    done

    echo -e "\n${YELLOW}⚠️  Server started but may still be initializing. Check status with: $0 status${NC}"
}

# Function to stop the server
stop_server() {
    if ! is_running; then
        echo -e "${YELLOW}⚠️  Server is not running${NC}"
        return 1
    fi

    PID=$(cat "$PID_FILE")
    echo -e "${BLUE}🛑 Stopping server (PID: $PID)...${NC}"

    kill "$PID"

    # Wait for process to stop
    for i in {1..10}; do
        if ! ps -p "$PID" > /dev/null 2>&1; then
            rm -f "$PID_FILE"
            echo -e "${GREEN}✅ Server stopped${NC}"
            return 0
        fi
        sleep 1
    done

    # Force kill if still running
    echo -e "${YELLOW}⚠️  Force killing server...${NC}"
    kill -9 "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    echo -e "${GREEN}✅ Server stopped${NC}"
}

# Function to show server status
show_status() {
    if ! is_running; then
        echo -e "${RED}❌ Server is NOT running${NC}"
        return 1
    fi

    PID=$(cat "$PID_FILE")
    echo -e "${GREEN}✅ Server is running (PID: $PID)${NC}"
    echo ""

    # Try to get detailed status from API
    STATUS=$(get_api_status)
    if [ -n "$STATUS" ]; then
        echo -e "${BLUE}📊 Server Status:${NC}"
        echo "$STATUS" | python3 -m json.tool 2>/dev/null || echo "$STATUS"
        echo ""
        echo -e "${BLUE}🌐 API Endpoints:${NC}"
        echo "   Health:  http://localhost:$PORT/health"
        echo "   Status:  http://localhost:$PORT/status"
        echo "   Docs:    http://localhost:$PORT/docs"
        echo "   Events:  http://localhost:$PORT/events"
    else
        echo -e "${YELLOW}⚠️  Server is starting up, API not responding yet...${NC}"
        echo -e "${BLUE}   Check logs: tail -f $LOG_FILE${NC}"
    fi
}

# Function to show logs
show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${YELLOW}⚠️  No log file found${NC}"
        return 1
    fi

    echo -e "${BLUE}📄 Server logs (last 50 lines):${NC}"
    echo ""
    tail -50 "$LOG_FILE"
    echo ""
    echo -e "${BLUE}💡 To follow logs in real-time: tail -f $LOG_FILE${NC}"
}

# Function to restart server
restart_server() {
    echo -e "${BLUE}🔄 Restarting server...${NC}"
    stop_server
    sleep 2
    start_server
}

# Main script
case "${1:-}" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Fatsoma Scraper API - Server Management"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the API server"
        echo "  stop     - Stop the API server"
        echo "  restart  - Restart the API server"
        echo "  status   - Show server status and info"
        echo "  logs     - Show recent server logs"
        echo ""
        exit 1
        ;;
esac
