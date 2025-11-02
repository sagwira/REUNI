from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import asyncio
from datetime import datetime
from typing import List, Dict
import re
import random
import logging
from pathlib import Path
from alerting import EmailAlerter
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('fixr_scraper.log'),
        logging.StreamHandler()
    ]
)

class ScraperMetrics:
    """Track scraper success/failure rates"""
    def __init__(self):
        self.total_attempts = 0
        self.successful_scrapes = 0
        self.failed_scrapes = 0
        self.events_scraped = 0
        self.errors = []

    def log_success(self, event_count: int):
        self.total_attempts += 1
        self.successful_scrapes += 1
        self.events_scraped += event_count
        logging.info(f"✅ Scrape successful: {event_count} events")

    def log_failure(self, error: str):
        self.total_attempts += 1
        self.failed_scrapes += 1
        self.errors.append({'time': datetime.now(), 'error': error})
        logging.error(f"❌ Scrape failed: {error}")

    def get_summary(self) -> Dict:
        return {
            'total_attempts': self.total_attempts,
            'successful': self.successful_scrapes,
            'failed': self.failed_scrapes,
            'success_rate': f"{(self.successful_scrapes/self.total_attempts*100):.1f}%" if self.total_attempts > 0 else "0%",
            'total_events': self.events_scraped,
            'recent_errors': [str(e['error']) for e in self.errors[-5:]]
        }

class FixrScraper:
    def __init__(self, min_delay: float = 1.0, max_delay: float = 3.0, enable_alerts: bool = True):
        self.base_url = "https://www.fixr.co"
        self.min_delay = min_delay
        self.max_delay = max_delay
        self.metrics = ScraperMetrics()
        self.logger = logging.getLogger(__name__)
        self.alerter = EmailAlerter() if enable_alerts else None

        if self.alerter and self.alerter.is_configured():
            self.logger.info("📧 Email alerting enabled")
        elif self.alerter:
            self.logger.warning("⚠️  Email alerting disabled - missing configuration")

    async def _random_delay(self):
        """Add random human-like delay between requests"""
        delay = random.uniform(self.min_delay, self.max_delay)
        self.logger.debug(f"Waiting {delay:.2f}s before next request")
        await asyncio.sleep(delay)

    async def scrape_events(self, city: str = "london", limit: int = 50) -> List[Dict]:
        """Scrape events from Fixr with monitoring and rate limiting"""
        try:
            self.logger.info(f"🚀 Starting Fixr scrape for city: {city}, limit: {limit}")

            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()

                # Set user agent to appear more human
                await page.set_extra_http_headers({
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                })

                # Navigate to events search page
                url = f"{self.base_url}/search?query={city}&type=events"
                self.logger.info(f"📡 Fetching: {url}")
                await page.goto(url, wait_until="networkidle", timeout=30000)

                # Rate limiting delay after initial page load
                await self._random_delay()

                # Scroll to load more events (Fixr loads dynamically)
                for i in range(5):
                    await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                    await asyncio.sleep(2)  # Wait for content to load

                # Wait for event cards to load
                try:
                    await page.wait_for_selector('a[href*="/event/"]', timeout=10000)
                except Exception as e:
                    self.logger.warning(f"Timeout waiting for event links: {e}")

                content = await page.content()
                soup = BeautifulSoup(content, 'html.parser')

                # Find all event links
                event_links = soup.find_all('a', href=re.compile(r'/event/'))

                if not event_links:
                    error_msg = f"No event links found for {city}. HTML structure may have changed."
                    self.metrics.log_failure(error_msg)
                    if self.alerter:
                        self.alerter.alert_no_event_cards(city, self.metrics.get_summary())
                    await browser.close()
                    return []

                # Extract unique event URLs
                event_urls = list(set([link.get('href') for link in event_links if link.get('href')]))
                event_urls = [url if url.startswith('http') else f"{self.base_url}{url}" for url in event_urls]
                event_urls = event_urls[:limit]

                self.logger.info(f"📋 Found {len(event_urls)} unique events")

                events = []
                for idx, event_url in enumerate(event_urls, 1):
                    try:
                        self.logger.info(f"🎫 Scraping event {idx}/{len(event_urls)}: {event_url}")

                        # Rate limiting before each request
                        if idx > 1:
                            await self._random_delay()

                        event_data = await self._scrape_event_details(page, event_url)
                        if event_data:
                            events.append(event_data)

                    except Exception as e:
                        self.logger.error(f"Error scraping event {event_url}: {str(e)}")
                        continue

                await browser.close()

                # Validation: Check if we got minimum events
                if len(events) < 3:
                    warning_msg = f"Low event count for {city}: {len(events)} events"
                    self.logger.warning(warning_msg)
                    if self.alerter:
                        self.alerter.alert_low_event_count(city, len(events), self.metrics.get_summary())

                self.metrics.log_success(len(events))
                return events

        except Exception as e:
            error_msg = f"Fatal error scraping {city}: {str(e)}"
            self.metrics.log_failure(error_msg)
            if self.alerter:
                self.alerter.alert_fatal_error(city, str(e), self.metrics.get_summary())
            raise

    async def _scrape_event_details(self, page, event_url: str) -> Dict:
        """Scrape details from a single event page"""
        try:
            await page.goto(event_url, wait_until="networkidle", timeout=30000)
            await asyncio.sleep(1)  # Brief wait for dynamic content

            content = await page.content()
            soup = BeautifulSoup(content, 'html.parser')

            # Extract event data from page
            # Note: Adjust these selectors based on actual Fixr HTML structure
            event_data = {
                'name': '',
                'date': '',
                'location': '',
                'venue': '',
                'description': '',
                'imageUrl': '',
                'lastEntry': '',
                'company': '',
                'url': event_url,
                'source': 'fixr',
                'tickets': []
            }

            # Extract event name
            title = soup.find('h1')
            if title:
                event_data['name'] = title.get_text(strip=True)

            # Extract event image
            img = soup.find('img', {'alt': re.compile(r'event', re.I)}) or soup.find('img')
            if img and img.get('src'):
                img_url = img['src']
                event_data['imageUrl'] = img_url if img_url.startswith('http') else f"{self.base_url}{img_url}"

            # Extract date/time information
            # Fixr typically uses structured data or specific elements for dates
            time_elements = soup.find_all(text=re.compile(r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}'))
            if time_elements:
                event_data['date'] = time_elements[0].strip()

            # Extract location/venue
            location_elements = soup.find_all(string=re.compile(r'venue|location', re.I))
            if location_elements:
                # Find parent and get next text
                for elem in location_elements[:3]:
                    parent = elem.parent
                    if parent and parent.name:
                        venue_text = parent.get_text(strip=True)
                        if len(venue_text) > 3 and len(venue_text) < 100:
                            event_data['venue'] = venue_text
                            break

            # Extract description
            desc_elem = soup.find('div', {'class': re.compile(r'description', re.I)})
            if desc_elem:
                event_data['description'] = desc_elem.get_text(strip=True)[:500]

            # Extract organizer/company
            org_elem = soup.find('a', {'href': re.compile(r'/organiser/')})
            if org_elem:
                event_data['company'] = org_elem.get_text(strip=True)

            # Extract ticket information
            # Fixr typically shows ticket types and prices
            ticket_elements = soup.find_all(text=re.compile(r'£\d+|\$\d+|free', re.I))
            for ticket_text in ticket_elements[:5]:
                price_match = re.search(r'[£$](\d+(?:\.\d{2})?)', ticket_text)
                if price_match:
                    ticket_data = {
                        'ticketType': 'General Admission',
                        'price': float(price_match.group(1)),
                        'available': True
                    }
                    event_data['tickets'].append(ticket_data)

            # If no tickets found, add a default one
            if not event_data['tickets']:
                event_data['tickets'].append({
                    'ticketType': 'General Admission',
                    'price': 0.0,
                    'available': True
                })

            self.logger.info(f"✅ Extracted: {event_data['name']}")
            return event_data

        except Exception as e:
            self.logger.error(f"Error extracting event details from {event_url}: {str(e)}")
            return None


# Example usage
async def main():
    scraper = FixrScraper()

    cities = ["london", "manchester", "birmingham", "nottingham"]

    for city in cities:
        try:
            events = await scraper.scrape_events(city, limit=20)
            print(f"\n{'='*50}")
            print(f"City: {city.upper()}")
            print(f"Events found: {len(events)}")
            print(f"{'='*50}\n")

            # Print first few events as examples
            for event in events[:3]:
                print(f"📅 {event['name']}")
                print(f"   📍 {event['venue']} - {event['location']}")
                print(f"   🎫 {len(event['tickets'])} ticket types")
                print(f"   🔗 {event['url']}\n")

        except Exception as e:
            print(f"Error scraping {city}: {e}")
            continue

    # Print metrics
    print(f"\n{'='*50}")
    print("SCRAPER METRICS:")
    print(json.dumps(scraper.metrics.get_summary(), indent=2))
    print(f"{'='*50}\n")


if __name__ == "__main__":
    asyncio.run(main())
