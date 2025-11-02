# Quick Start: Monitoring & Alerts

## 5-Minute Setup

### 1. Configure Email (Optional but Recommended)

Edit your `.env` file and add:

```bash
# Gmail Configuration
ALERT_EMAIL_FROM=your-email@gmail.com
ALERT_EMAIL_PASSWORD=your-gmail-app-password
ALERT_EMAIL_TO=alerts@yourdomain.com
```

**Get Gmail App Password**: https://myaccount.google.com/apppasswords

### 2. Test Your Setup

```bash
python test_alerts.py
```

You should receive a test email!

### 3. You're Done!

The scraper now automatically:
- ✅ Rate limits requests (1-3 second delays)
- ✅ Logs everything to `scraper.log`
- ✅ Sends email alerts on failures
- ✅ Tracks success/failure metrics
- ✅ Detects HTML structure changes

## Daily Usage

### View Logs
```bash
tail -f scraper.log  # Real-time
```

### Check for Errors
```bash
grep "ERROR" scraper.log | tail -20
```

## When You Get an Alert

### 🔴 HTML Structure Change
**Action**: Update selectors in `scraper.py`
1. Visit the URL in the alert
2. Inspect the HTML
3. Update class names/selectors

### ⚠️  Low Event Count
**Action**: Check logs and verify
```bash
grep "WARNING" scraper.log | tail -10
```

### 💥 Fatal Error
**Action**: Check network and retry
```bash
tail -50 scraper.log  # See full error
```

## Configuration

### Adjust Rate Limiting
In your scraper code:
```python
# Slower (safer)
scraper = FatsomaScraper(min_delay=2.0, max_delay=5.0)

# Default (recommended)
scraper = FatsomaScraper()  # 1-3 seconds
```

### Disable Alerts
```python
scraper = FatsomaScraper(enable_alerts=False)
```

## Files to Know

- `scraper.log` - All scraper activity
- `alerting.py` - Email alert system
- `test_alerts.py` - Test your email config
- `MONITORING_SETUP.md` - Detailed setup guide

## Common Issues

**"Email not configured"**
→ Add email settings to `.env`

**"Authentication failed"**
→ Use App Password, not regular password

**No email received**
→ Check spam folder, verify email address

## Need Help?

1. Read `MONITORING_SETUP.md` for full details
2. Check `scraper.log` for error messages
3. Run `python test_alerts.py` to test email

That's it! Your scraper is now production-ready with monitoring. 🎉
