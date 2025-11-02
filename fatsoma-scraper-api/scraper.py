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

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('scraper.log'),
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

class FatsomaScraper:
    def __init__(self, min_delay: float = 1.0, max_delay: float = 3.0, enable_alerts: bool = True):
        self.base_url = "https://www.fatsoma.com"
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
        """Scrape events from Fatsoma with monitoring and rate limiting"""
        try:
            self.logger.info(f"🚀 Starting scrape for city: {city}, limit: {limit}")

            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()

                # Set user agent to appear more human
                await page.set_extra_http_headers({
                    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
                })

                # Navigate to events page
                url = f"{self.base_url}/e/{city}"
                self.logger.info(f"📡 Fetching: {url}")
                await page.goto(url, wait_until="networkidle")

                # Rate limiting delay after initial page load
                await self._random_delay()

                # Scroll to load more events
                for i in range(3):
                    await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                    await asyncio.sleep(1)  # Keep scroll delay short

                content = await page.content()
                soup = BeautifulSoup(content, 'html.parser')

                events = []
                event_cards = soup.find_all('div', class_=re.compile(r'event-card|EventCard'))[:limit]

                # Validation: Check if we found event cards
                if not event_cards:
                    error_msg = f"No event cards found for {city}. HTML structure may have changed."
                    self.metrics.log_failure(error_msg)
                    self.logger.warning(f"⚠️  {error_msg}")

                    # Send critical alert for HTML structure change
                    if self.alerter:
                        self.alerter.alert_no_event_cards(city, self.metrics.get_summary())

                    await browser.close()
                    return []

                self.logger.info(f"📋 Found {len(event_cards)} event cards")

                for idx, card in enumerate(event_cards, 1):
                    try:
                        self.logger.info(f"🎫 Scraping event {idx}/{len(event_cards)}")
                        event_data = await self._extract_event_data(page, card)
                        if event_data:
                            events.append(event_data)

                        # Rate limiting between event detail pages
                        if idx < len(event_cards):  # Don't delay after last event
                            await self._random_delay()

                    except Exception as e:
                        self.logger.error(f"❌ Error extracting event {idx}: {str(e)}")
                        continue

                await browser.close()

                # Validation: Check minimum event count
                if len(events) < 3:
                    error_msg = f"Only scraped {len(events)} events for {city}. Expected more."
                    self.metrics.log_failure(error_msg)
                    self.logger.warning(f"⚠️  {error_msg}")

                    # Send alert for low event count
                    if self.alerter and len(events) > 0:
                        self.alerter.alert_low_event_count(city, len(events), self.metrics.get_summary())
                else:
                    self.metrics.log_success(len(events))

                self.logger.info(f"✅ Scrape complete: {len(events)} events scraped")
                return events

        except Exception as e:
            error_msg = f"Fatal error during scrape: {str(e)}"
            self.metrics.log_failure(error_msg)
            self.logger.error(f"💥 {error_msg}", exc_info=True)

            # Send alert for fatal error
            if self.alerter:
                self.alerter.alert_scrape_failure(city, error_msg, self.metrics.get_summary())

            return []

    async def _extract_event_data(self, page, card) -> Dict:
        """Extract detailed event information with error handling"""
        detail_page = None
        try:
            # Extract basic info from card
            event_link = card.find('a', href=re.compile(r'/e/'))
            if not event_link:
                self.logger.warning("No event link found in card")
                return None

            event_url = self.base_url + event_link['href'] if event_link['href'].startswith('/') else event_link['href']

            # Navigate to event detail page
            detail_page = await page.context.new_page()
            await detail_page.goto(event_url, wait_until="networkidle", timeout=30000)

            detail_content = await detail_page.content()
            detail_soup = BeautifulSoup(detail_content, 'html.parser')

            # Extract event details with fallback selectors
            event_data = {
                'event_id': self._extract_event_id(event_url),
                'name': self._extract_text(detail_soup, ['h1', 'class', re.compile(r'event-title|EventTitle')]) or "Unknown Event",
                'company': self._extract_text(detail_soup, ['div', 'class', re.compile(r'organizer|promoter')]),
                'date': self._extract_date(detail_soup),
                'time': self._extract_text(detail_soup, ['span', 'class', re.compile(r'time|event-time')]),
                'last_entry': self._extract_text(detail_soup, ['span', 'class', re.compile(r'last-entry')]),
                'location': self._extract_text(detail_soup, ['div', 'class', re.compile(r'venue|location')]),
                'age_restriction': self._extract_text(detail_soup, ['span', 'class', re.compile(r'age|restriction')]),
                'url': event_url,
                'image_url': self._extract_image(detail_soup),
                'tickets': self._extract_tickets(detail_soup)
            }

            # Validate required fields
            if not event_data['name'] or event_data['name'] == "Unknown Event":
                self.logger.warning(f"Event at {event_url} missing name - possible structure change")

            return event_data

        except Exception as e:
            self.logger.error(f"Error extracting event data: {str(e)}")
            return None
        finally:
            if detail_page:
                await detail_page.close()

    def _extract_event_id(self, url: str) -> str:
        """Extract event ID from URL"""
        match = re.search(r'/e/([^/]+)', url)
        return match.group(1) if match else url.split('/')[-1]

    def _extract_text(self, soup, selector) -> str:
        """Helper to extract text from BeautifulSoup"""
        element = soup.find(selector[0], {selector[1]: selector[2]})
        return element.get_text(strip=True) if element else ""

    def _extract_date(self, soup) -> str:
        """Extract and parse event date"""
        date_elem = soup.find(['time', 'span'], class_=re.compile(r'date|event-date'))
        if date_elem:
            date_str = date_elem.get('datetime') or date_elem.get_text(strip=True)
            return date_str
        return ""

    def _extract_image(self, soup) -> str:
        """Extract event image URL"""
        img = soup.find('img', class_=re.compile(r'event-image|poster'))
        return img.get('src', '') if img else ""

    def _extract_tickets(self, soup) -> List[Dict]:
        """Extract ticket information"""
        tickets = []
        ticket_elements = soup.find_all(['div', 'li'], class_=re.compile(r'ticket|price'))

        for ticket_elem in ticket_elements:
            ticket_type = ticket_elem.find(['span', 'div'], class_=re.compile(r'ticket-name|type'))
            price_elem = ticket_elem.find(['span', 'div'], class_=re.compile(r'price|cost'))

            if ticket_type and price_elem:
                price_text = price_elem.get_text(strip=True)
                price = self._parse_price(price_text)

                tickets.append({
                    'ticket_type': ticket_type.get_text(strip=True),
                    'price': price,
                    'currency': 'GBP',
                    'availability': 'Available' if price else 'Sold Out'
                })

        return tickets

    def _parse_price(self, price_text: str) -> float:
        """Parse price from text"""
        match = re.search(r'[\d.]+', price_text.replace(',', ''))
        return float(match.group(0)) if match else 0.0
