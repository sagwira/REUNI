# Running the Fatsoma Scraper in Background

The scraper automatically syncs Fatsoma events to Supabase every 6 hours.

## Option 1: Run Locally (Development)

Keep the scraper running in a terminal:

```bash
cd /Users/rentamac/documents/REUNI/fatsoma-scraper-api
source venv/bin/activate
python main.py
```

The scraper will:
- Start immediately and scrape ~50 events
- Sync them to Supabase
- Repeat every 6 hours automatically

## Option 2: Run as Background Process (macOS)

Create a LaunchAgent to run it automatically:

```bash
# Create the plist file
cat > ~/Library/LaunchAgents/com.reuni.fatsoma-scraper.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.reuni.fatsoma-scraper</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/rentamac/documents/REUNI/fatsoma-scraper-api/venv/bin/python</string>
        <string>/Users/rentamac/documents/REUNI/fatsoma-scraper-api/main.py</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/rentamac/documents/REUNI/fatsoma-scraper-api</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/fatsoma-scraper.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/fatsoma-scraper-error.log</string>
</dict>
</plist>
EOF

# Load the service
launchctl load ~/Library/LaunchAgents/com.reuni.fatsoma-scraper.plist

# Check if it's running
launchctl list | grep fatsoma
```

To stop:
```bash
launchctl unload ~/Library/LaunchAgents/com.reuni.fatsoma-scraper.plist
```

To view logs:
```bash
tail -f /tmp/fatsoma-scraper.log
```

## Option 3: Deploy to a Server (Production)

For production, deploy to:

### Render.com (Free Tier)
1. Push code to GitHub
2. Go to [render.com](https://render.com)
3. Create new "Background Worker"
4. Connect your repo
5. Set build command: `pip install -r requirements.txt && playwright install chromium`
6. Set start command: `python main.py`
7. Add environment variables from `.env`

### Railway.app (Free Tier)
1. Push code to GitHub
2. Go to [railway.app](https://railway.app)
3. Click "New Project" → "Deploy from GitHub"
4. Select your repo
5. Add environment variables
6. Will auto-deploy

### Heroku (Paid)
```bash
heroku create reuni-fatsoma-scraper
heroku buildpacks:add heroku/python
git push heroku main
```

## Current Status

The scraper is already configured to:
- ✅ Sync to Supabase automatically
- ✅ Run every 6 hours
- ✅ Handle errors gracefully
- ✅ Update existing events
- ✅ Create new events

Your iOS app now queries Supabase directly, so you don't need ngrok anymore!

## Manual Trigger

You can manually trigger a sync:
```bash
curl -X POST http://localhost:8000/refresh
```

Or from your iOS app (already implemented in EventViewModel).
