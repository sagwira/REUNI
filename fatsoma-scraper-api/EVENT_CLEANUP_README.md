# Event Cleanup & Filtering System

## Overview
Automatically manages event lifecycle by archiving past events and provides powerful filtering to retrieve events by location and date range.

## Features

### 1. **Automatic Cleanup** 🗑️
- Archives events after they've ended (based on event date + last entry time)
- Runs automatically every 6 hours with the main scraper
- Handles early morning events (e.g., events ending at 01:00 are counted as next day)
- Cascades to tickets (deletes associated ticket records)

### 2. **Location-Based Filtering** 📍
- Get all events in a specific city/location
- Filter by date range (default: next 7 days)
- Groups events by date with formatted output
- Shows ticket price ranges

## Usage

### Get Events by Location

**This Week (7 days):**
```bash
python event_cleanup.py location nottingham
```

**Next 2 Weeks (14 days):**
```bash
python event_cleanup.py location nottingham 14
```

**Example Output:**
```
🎫 Getting events in NOTTINGHAM for the next 7 days...
✅ Found 3 events in nottingham this week

📅 Wednesday, October 29, 2025
============================================================
  🎉 HALLOWEEN MANSION PARTY
     Location: SECRET NOTTINGHAM LOCATION
     Time: 22:00
     Last Entry: N/A

📅 Friday, October 31, 2025
============================================================
  🎉 Green Room Sessions x Shapes. Halloween [SOLD OUT]
     Location: Brewhouse & Kitchen - Nottingham
     Time: 19:00
     Last Entry: Last Entry time: Click 'More' on Ticket Options
     Price: £10.00 - £15.00
```

### Archive Past Events

**Dry Run (See what would be archived):**
```bash
python event_cleanup.py archive --dry-run
```

**Actually Archive:**
```bash
python event_cleanup.py archive
```

**Example Output:**
```
🗑️  Checking for past events to archive...

📊 Found 64 past events

Sample of events to archive:
  - ULTIMATE SALFORD ‼️  presents Halloween Project
    Date: 2025-09-07T00:00:00+00:00
    Last Entry: 23:00
    Event End: 2025-09-07 23:00:00
  ... and 59 more

✅ Archived: 64
❌ Errors: 0
