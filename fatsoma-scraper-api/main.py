from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
import uvicorn
import asyncio

from models import SessionLocal, Event, Ticket
from api_scraper import FatsomaAPIScraper
from supabase_syncer import SupabaseSyncer
from event_cleanup import EventCleanup
from fixr_transfer_extractor import FixrTransferExtractor
from pydantic import BaseModel

app = FastAPI(title="Fatsoma Scraper API")

# CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for API responses
class TicketResponse(BaseModel):
    ticket_type: str
    price: float
    currency: str
    availability: str

    class Config:
        from_attributes = True

class EventResponse(BaseModel):
    id: int
    event_id: str
    name: str
    company: Optional[str]
    date: Optional[datetime]
    time: Optional[str]
    last_entry: Optional[str]
    location: Optional[str]
    age_restriction: Optional[str]
    url: str
    image_url: Optional[str]
    tickets: List[TicketResponse]
    updated_at: datetime

    class Config:
        from_attributes = True

# Database dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Background scraping function
async def update_events():
    """Background task to update events"""
    print(f"Starting event update at {datetime.now()}")
    server_status["is_syncing"] = True
    scraper = FatsomaAPIScraper()

    try:
        # Scrape events from multiple UK student cities
        all_events = []
        locations = ["london", "manchester", "nottingham", "birmingham", "leeds"]

        for location in locations:
            print(f"\n📍 Scraping {location.title()}...")
            location_events = await scraper.scrape_events(location=location, limit=100)
            all_events.extend(location_events)
            print(f"   Found {len(location_events)} events in {location.title()}")

        # Fetch manual events (UUIDs and organizer profiles)
        print(f"\n🎯 Fetching manual events...")
        manual_events = await scraper.fetch_manual_events()
        if manual_events:
            print(f"   Found {len(manual_events)} manual events")
            all_events.extend(manual_events)

        events = all_events
        print(f"\n✅ Total events scraped: {len(events)}")

        # Sync to Supabase
        try:
            supabase_syncer = SupabaseSyncer()
            supabase_results = await supabase_syncer.sync_events(events)
            print(f"Supabase sync: {supabase_results['success']} events synced ({supabase_results['created']} created, {supabase_results['updated']} updated)")

            # After sync, clean up past events
            print(f"\n🗑️  Cleaning up past events...")
            cleanup = EventCleanup()
            past_events = cleanup.archive_past_events(dry_run=False)
            print(f"✅ Archived {len(past_events)} past events")
        except Exception as e:
            print(f"⚠️ Supabase sync failed (continuing with local DB): {e}")

        # Also save to local SQLite database
        try:
            db = SessionLocal()

            for event_data in events:
                tickets_data = event_data.pop('tickets', [])

                # Check if event exists
                existing_event = db.query(Event).filter(Event.event_id == event_data['event_id']).first()

                if existing_event:
                    # Update existing event
                    for key, value in event_data.items():
                        setattr(existing_event, key, value)
                    existing_event.updated_at = datetime.utcnow()

                    # Delete old tickets
                    db.query(Ticket).filter(Ticket.event_id == existing_event.id).delete()
                else:
                    # Create new event
                    existing_event = Event(**event_data)
                    db.add(existing_event)

                db.flush()

                # Add tickets
                for ticket_data in tickets_data:
                    ticket = Ticket(event_id=existing_event.id, **ticket_data)
                    db.add(ticket)

            db.commit()
            print(f"Successfully updated {len(events)} events in local database")
        except Exception as db_error:
            print(f"⚠️ Local SQLite update failed (Supabase sync succeeded): {db_error}")
        finally:
            db.close()

        # Update status
        server_status["is_syncing"] = False
        server_status["last_sync"] = datetime.now().isoformat()
        server_status["ready"] = True

    except Exception as e:
        print(f"Error updating events: {e}")
        server_status["is_syncing"] = False

# Server status tracking
server_status = {
    "ready": False,
    "startup_complete": False,
    "last_sync": None,
    "is_syncing": False
}

# API Endpoints
@app.get("/")
async def root():
    return {"message": "Fatsoma Scraper API", "status": "running"}

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy" if server_status["ready"] else "starting",
        "timestamp": datetime.now().isoformat()
    }

@app.get("/status")
async def get_status(db: Session = Depends(get_db)):
    """Get detailed server status"""
    event_count = db.query(Event).count()
    latest_event = db.query(Event).order_by(Event.updated_at.desc()).first()

    return {
        "server": "running",
        "ready": server_status["ready"],
        "startup_complete": server_status["startup_complete"],
        "is_syncing": server_status["is_syncing"],
        "last_sync": server_status["last_sync"],
        "database": {
            "total_events": event_count,
            "latest_update": latest_event.updated_at.isoformat() if latest_event else None
        },
        "timestamp": datetime.now().isoformat()
    }

@app.get("/events", response_model=List[EventResponse])
async def get_events(
    skip: int = 0,
    limit: int = 100,
    city: str = None,
    db: Session = Depends(get_db)
):
    """Get all events from database"""
    query = db.query(Event)

    if city:
        query = query.filter(Event.location.contains(city))

    events = query.offset(skip).limit(limit).all()
    return events

@app.get("/events/{event_id}", response_model=EventResponse)
async def get_event(event_id: str, db: Session = Depends(get_db)):
    """Get specific event by ID"""
    event = db.query(Event).filter(Event.event_id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    return event

@app.post("/refresh")
async def refresh_events(background_tasks: BackgroundTasks):
    """Trigger manual event refresh"""
    background_tasks.add_task(update_events)
    return {"message": "Event refresh started"}

@app.get("/events/search/{query}")
async def search_events(query: str, db: Session = Depends(get_db)):
    """Search events by name or location"""
    events = db.query(Event).filter(
        (Event.name.contains(query)) |
        (Event.location.contains(query)) |
        (Event.company.contains(query))
    ).all()
    return events

@app.post("/fixr/extract-transfer")
async def extract_fixr_transfer(transfer_url: str):
    """
    Extract event information from a Fixr transfer ticket link and save to database

    Example: POST /fixr/extract-transfer?transfer_url=https://fixr.co/transfer-ticket/2156d6630b191850eb92a326
    """
    try:
        extractor = FixrTransferExtractor()
        event_data = await extractor.extract_from_transfer_link(transfer_url)

        if not event_data:
            raise HTTPException(status_code=404, detail="Could not extract event data from transfer link")

        # Save event to fixr_events table as trusted source
        try:
            # Generate event_id from URL
            event_id = event_data['url'].replace('https://', '').replace('http://', '').replace('/', '-')

            # Prepare event for database
            db_event = {
                'event_id': event_id,
                'name': event_data['name'],
                'date': event_data['date'],
                'location': event_data['location'],
                'venue': event_data['venue'],
                'address': event_data.get('address', ''),
                'postcode': event_data.get('postcode', ''),
                'description': event_data.get('description', ''),
                'image_url': event_data.get('imageUrl', ''),
                'url': event_data['url'],
                'company': event_data.get('company', ''),
                'last_entry': event_data.get('lastEntry', ''),
                'last_entry_type': event_data.get('lastEntryType'),
                'last_entry_label': event_data.get('lastEntryLabel'),
                'source': 'fixr',
                'tickets': event_data.get('tickets', [])
            }

            # Upsert to database (insert or update if exists)
            supabase.table('fixr_events').upsert(db_event, on_conflict='event_id').execute()
            print(f"✅ Saved Fixr transfer event to database: {event_data['name']}")

        except Exception as db_error:
            print(f"⚠️  Warning: Could not save to database: {db_error}")
            # Continue anyway - we still have the event data to return

        return {
            "success": True,
            "event": event_data
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error extracting transfer link: {str(e)}")

# Scheduler for automatic updates
scheduler = BackgroundScheduler()
scheduler.add_job(lambda: asyncio.run(update_events()), 'interval', hours=6)  # Update every 6 hours

@app.on_event("startup")
async def startup_event():
    """Start scheduler and initial scrape"""
    print("🚀 Server starting up...")
    scheduler.start()
    print("📅 Scheduler started")
    # Mark server as ready immediately - sync will happen in background
    server_status["ready"] = True
    print("✅ Server is ready to accept requests!")
    print("🔄 Running initial event sync in background...")
    # Run initial scrape in background
    import threading
    def run_initial_sync():
        import asyncio
        asyncio.run(update_events())
        server_status["startup_complete"] = True
        print("✅ Initial sync complete!")

    thread = threading.Thread(target=run_initial_sync, daemon=True)
    thread.start()

@app.on_event("shutdown")
async def shutdown_event():
    scheduler.shutdown()

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
