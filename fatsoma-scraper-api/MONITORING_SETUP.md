# Scraper Monitoring & Alert Setup

This guide explains how to set up monitoring and email alerts for the Fatsoma scraper.

## Features

✅ **Rate Limiting**: Random 1-3 second delays between requests
✅ **Logging**: Detailed logs saved to `scraper.log`
✅ **Metrics Tracking**: Success/failure rates and event counts
✅ **Email Alerts**: Automatic notifications for scraper issues
✅ **Validation**: Detects HTML structure changes and low event counts

## Quick Setup

### 1. Configure Email Alerts

Add these variables to your `.env` file:

```bash
# For Gmail (recommended)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
ALERT_EMAIL_FROM=your-email@gmail.com
ALERT_EMAIL_PASSWORD=your-app-password
ALERT_EMAIL_TO=alerts@yourdomain.com

# Alert thresholds
MIN_EVENTS_THRESHOLD=3
ALERT_ON_ZERO_EVENTS=true
```

### 2. Get a Gmail App Password

**Important**: Don't use your regular Gmail password!

1. Go to your Google Account: https://myaccount.google.com
2. Enable 2-Factor Authentication if not already enabled
3. Go to App Passwords: https://myaccount.google.com/apppasswords
4. Select "Mail" and your device
5. Copy the 16-character password
6. Use this as `ALERT_EMAIL_PASSWORD` in `.env`

### 3. Test Your Configuration

```bash
python test_alerts.py
```

You should receive a test email within seconds.

## What Triggers Alerts?

### 1. 🔴 Critical: HTML Structure Change
**When**: No event cards found on the page
**Means**: Fatsoma changed their website structure
**Action**: Update selectors in `scraper.py`

### 2. ⚠️  Warning: Low Event Count
**When**: Fewer than 3 events scraped
**Means**: Something is filtering out events or partial failure
**Action**: Check logs and verify selectors

### 3. 💥 Fatal: Scrape Failure
**When**: Complete failure to scrape (network, timeout, etc.)
**Means**: Network issues or server problems
**Action**: Check logs and retry

## Monitoring Logs

### View Real-time Logs
```bash
tail -f scraper.log
```

### View Recent Errors
```bash
grep "ERROR" scraper.log | tail -20
```

### Check Success Rate
The scraper tracks metrics internally:
- Total attempts
- Successful scrapes
- Failed scrapes
- Success rate percentage
- Total events scraped

## Email Alert Examples

### Critical Alert (HTML Change)
```
Subject: [Fatsoma Scraper Alert] 🔴 CRITICAL: HTML Structure Change Detected

No event cards found for nottingham.

This strongly indicates that Fatsoma has changed their HTML structure.
The event card selectors are no longer matching.

You need to:
1. Visit https://www.fatsoma.com/e/nottingham
2. Inspect the HTML structure
3. Update the selectors in scraper.py
```

### Warning Alert (Low Events)
```
Subject: [Fatsoma Scraper Alert] Low Event Count for manchester

The scraper found only 2 events for manchester, which is below
the expected threshold of 3.

This might indicate:
- HTML structure changes on Fatsoma
- Incorrect selectors
- Events being filtered out unexpectedly

Recent scrape success rate: 85.0%
```

## Rate Limiting

The scraper automatically:
- Adds 1-3 second random delays between event pages
- Uses realistic User-Agent headers
- Respects Fatsoma's servers

**Adjust delays** in scraper initialization:
```python
scraper = FatsomaScraper(
    min_delay=2.0,  # Minimum 2 seconds
    max_delay=5.0   # Maximum 5 seconds
)
```

## Disable Alerts (Not Recommended)

If you want to disable email alerts:

```python
scraper = FatsomaScraper(enable_alerts=False)
```

Or simply don't configure the email environment variables.

## Troubleshooting

### "Email alerting not configured"
- Check your `.env` file has all required variables
- Make sure you're using an App Password for Gmail
- Verify the email addresses are correct

### "Failed to send alert email"
- Check your internet connection
- Verify Gmail App Password is correct
- Try generating a new App Password
- Check if Gmail is blocking "less secure apps"

### "Authentication failed"
- You're probably using your regular password instead of App Password
- Generate a new App Password and try again

### Not receiving emails
- Check spam/junk folder
- Verify `ALERT_EMAIL_TO` is correct
- Try sending a test email: `python test_alerts.py`

## Other SMTP Providers

### Outlook/Office 365
```bash
SMTP_SERVER=smtp.office365.com
SMTP_PORT=587
```

### Yahoo Mail
```bash
SMTP_SERVER=smtp.mail.yahoo.com
SMTP_PORT=587
```

### Custom SMTP Server
```bash
SMTP_SERVER=mail.yourserver.com
SMTP_PORT=587
```

## Best Practices

1. **Monitor regularly**: Check `scraper.log` weekly
2. **Test alerts**: Run `test_alerts.py` after any email config changes
3. **Set up a dedicated email**: Use alerts@yourdomain.com for better organization
4. **Don't ignore warnings**: Low event counts often precede complete failures
5. **Update selectors promptly**: When HTML changes, fix it quickly to avoid data gaps

## Support

If you're having issues:
1. Check `scraper.log` for detailed error messages
2. Run `python test_alerts.py` to test email configuration
3. Verify all environment variables are set correctly
