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

class FixrScraperStealth:
    def __init__(self, min_delay: float = 2.0, max_delay: float = 5.0, enable_alerts: bool = True):
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

    async def _setup_stealth_browser(self, playwright):
        """Setup browser with anti-detection measures"""
        # Use a real Chrome browser with stealth settings
        browser = await playwright.chromium.launch(
            headless=False,  # Run in non-headless mode to avoid detection
            args=[
                '--disable-blink-features=AutomationControlled',
                '--disable-dev-shm-usage',
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-web-security',
                '--disable-features=IsolateOrigins,site-per-process',
                '--window-size=1920,1080'
            ]
        )

        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            locale='en-GB',
            timezone_id='Europe/London',
            geolocation={'longitude': -0.1276, 'latitude': 51.5074},  # London coordinates
            permissions=['geolocation']
        )

        page = await context.new_page()

        # Inject scripts to mask automation
        await page.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });

            Object.defineProperty(navigator, 'plugins', {
                get: () => [1, 2, 3, 4, 5]
            });

            Object.defineProperty(navigator, 'languages', {
                get: () => ['en-GB', 'en-US', 'en']
            });

            window.chrome = {
                runtime: {}
            };

            Object.defineProperty(navigator, 'permissions', {
                get: () => ({
                    query: () => Promise.resolve({ state: 'granted' })
                })
            });
        """)

        return browser, page

    async def scrape_events(self, city: str = "london", limit: int = 50) -> List[Dict]:
        """Scrape events from Fixr with stealth techniques"""
        try:
            self.logger.info(f"🚀 Starting Fixr scrape for city: {city}, limit: {limit}")

            async with async_playwright() as p:
                browser, page = await self._setup_stealth_browser(p)

                # Navigate to homepage first (more human-like)
                self.logger.info("📡 Loading Fixr homepage...")
                await page.goto(self.base_url, wait_until="domcontentloaded", timeout=60000)
                await asyncio.sleep(random.uniform(2, 4))

                # Simulate human mouse movements
                await page.mouse.move(random.randint(100, 500), random.randint(100, 500))
                await asyncio.sleep(0.5)

                # Now navigate to search page
                url = f"{self.base_url}/search?query={city}&type=events"
                self.logger.info(f"📡 Navigating to: {url}")

                try:
                    await page.goto(url, wait_until="domcontentloaded", timeout=60000)
                except Exception as e:
                    self.logger.warning(f"Timeout on networkidle, trying domcontentloaded: {e}")

                # Wait for page to settle
                await asyncio.sleep(random.uniform(3, 5))

                # Simulate human scrolling behavior
                for i in range(5):
                    scroll_amount = random.randint(300, 800)
                    await page.evaluate(f"window.scrollBy(0, {scroll_amount})")
                    await asyncio.sleep(random.uniform(0.5, 1.5))

                # Wait for dynamic content
                await asyncio.sleep(3)

                # Take screenshot for debugging
                await page.screenshot(path='fixr_page.png')
                self.logger.info("📸 Screenshot saved to fixr_page.png")

                content = await page.content()

                # Save HTML for inspection
                with open('fixr_page.html', 'w', encoding='utf-8') as f:
                    f.write(content)
                self.logger.info("💾 HTML saved to fixr_page.html")

                soup = BeautifulSoup(content, 'html.parser')

                # Find all event links - try multiple selectors
                event_links = []

                # Method 1: Look for links with /event/ in href
                links_method1 = soup.find_all('a', href=re.compile(r'/event/'))
                event_links.extend(links_method1)
                self.logger.info(f"Found {len(links_method1)} links with /event/ pattern")

                # Method 2: Look for event titles/cards
                event_cards = soup.find_all(['article', 'div'], class_=re.compile(r'event|card', re.I))
                for card in event_cards:
                    links = card.find_all('a', href=True)
                    event_links.extend(links)
                self.logger.info(f"Found {len(event_cards)} event cards")

                if not event_links:
                    error_msg = f"No event links found for {city}. Page may need manual inspection."
                    self.logger.warning(error_msg)
                    # Don't fail completely, just log and continue
                    await browser.close()

                    # Try to extract any data from what we got
                    self.logger.info("Attempting to extract data from page content...")
                    events = await self._extract_events_from_html(soup, city)

                    if not events:
                        self.metrics.log_failure(error_msg)
                        if self.alerter:
                            self.alerter.alert_no_event_cards(city, self.metrics.get_summary())
                    else:
                        self.metrics.log_success(len(events))

                    return events

                # Extract unique event URLs
                event_urls = list(set([link.get('href') for link in event_links if link.get('href')]))
                event_urls = [url if url.startswith('http') else f"{self.base_url}{url}" for url in event_urls]
                event_urls = [url for url in event_urls if '/event/' in url][:limit]

                self.logger.info(f"📋 Found {len(event_urls)} unique event URLs")

                events = []
                for idx, event_url in enumerate(event_urls, 1):
                    try:
                        self.logger.info(f"🎫 Scraping event {idx}/{len(event_urls)}: {event_url}")

                        # Longer delay between requests for stealth
                        if idx > 1:
                            await asyncio.sleep(random.uniform(self.min_delay, self.max_delay))

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

    async def _extract_events_from_html(self, soup, city: str) -> List[Dict]:
        """Try to extract event data directly from the search results page"""
        events = []

        # Look for any elements that might contain event data
        potential_events = soup.find_all(['article', 'div', 'a'], class_=re.compile(r'event|card|item', re.I))

        for elem in potential_events[:20]:  # Limit to 20
            try:
                event_data = {
                    'name': '',
                    'date': '',
                    'location': city,
                    'venue': '',
                    'description': '',
                    'imageUrl': '',
                    'lastEntry': '',
                    'company': '',
                    'url': '',
                    'source': 'fixr',
                    'tickets': []
                }

                # Extract name
                title_elem = elem.find(['h1', 'h2', 'h3', 'h4'])
                if title_elem:
                    event_data['name'] = title_elem.get_text(strip=True)

                # Extract link
                link_elem = elem.find('a', href=True) if elem.name != 'a' else elem
                if link_elem and link_elem.get('href'):
                    href = link_elem['href']
                    event_data['url'] = href if href.startswith('http') else f"{self.base_url}{href}"

                # Extract image
                img_elem = elem.find('img', src=True)
                if img_elem:
                    src = img_elem['src']
                    event_data['imageUrl'] = src if src.startswith('http') else f"{self.base_url}{src}"

                # Only add if we have at least a name and URL
                if event_data['name'] and event_data['url'] and '/event/' in event_data['url']:
                    event_data['tickets'].append({
                        'ticketType': 'General Admission',
                        'price': 0.0,
                        'available': True
                    })
                    events.append(event_data)
                    self.logger.info(f"✅ Extracted from search: {event_data['name']}")

            except Exception as e:
                self.logger.debug(f"Could not extract event from element: {e}")
                continue

        return events

    async def _scrape_event_details(self, page, event_url: str) -> Dict:
        """Scrape details from a single event page with stealth"""
        try:
            # Human-like navigation
            await page.goto(event_url, wait_until="domcontentloaded", timeout=60000)
            await asyncio.sleep(random.uniform(2, 4))

            # Simulate scrolling
            await page.evaluate("window.scrollTo(0, document.body.scrollHeight / 2)")
            await asyncio.sleep(1)

            content = await page.content()
            soup = BeautifulSoup(content, 'html.parser')

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

            # Extract event name (h1 is most common)
            title = soup.find('h1')
            if title:
                event_data['name'] = title.get_text(strip=True)

            # Extract event image
            img = soup.find('img', {'alt': re.compile(r'.+')})
            if img and img.get('src'):
                img_url = img['src']
                event_data['imageUrl'] = img_url if img_url.startswith('http') else f"{self.base_url}{img_url}"

            # Extract date
            date_patterns = [
                r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}',
                r'\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{4}',
            ]
            for pattern in date_patterns:
                date_match = soup.find(text=re.compile(pattern))
                if date_match:
                    event_data['date'] = date_match.strip()
                    break

            # Extract venue/location
            venue_keywords = ['venue', 'location', 'address']
            for keyword in venue_keywords:
                venue_elem = soup.find(text=re.compile(keyword, re.I))
                if venue_elem and venue_elem.parent:
                    parent = venue_elem.parent
                    venue_text = parent.get_text(strip=True)
                    if 5 < len(venue_text) < 100:
                        event_data['venue'] = venue_text
                        break

            # Extract description
            desc_elem = soup.find(['div', 'p'], class_=re.compile(r'desc|about|details', re.I))
            if desc_elem:
                event_data['description'] = desc_elem.get_text(strip=True)[:500]

            # Extract organizer
            org_elem = soup.find('a', href=re.compile(r'/organiser/'))
            if org_elem:
                event_data['company'] = org_elem.get_text(strip=True)

            # Extract ticket info
            price_pattern = r'[£$](\d+(?:\.\d{2})?)'
            prices = soup.find_all(text=re.compile(price_pattern))
            for price_text in prices[:5]:
                price_match = re.search(price_pattern, price_text)
                if price_match:
                    ticket_data = {
                        'ticketType': 'General Admission',
                        'price': float(price_match.group(1)),
                        'available': True
                    }
                    event_data['tickets'].append(ticket_data)

            # Default ticket if none found
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
    scraper = FixrScraperStealth(min_delay=3.0, max_delay=6.0, enable_alerts=False)

    cities = ["london"]  # Start with just one city for testing

    for city in cities:
        try:
            events = await scraper.scrape_events(city, limit=10)
            print(f"\n{'='*50}")
            print(f"City: {city.upper()}")
            print(f"Events found: {len(events)}")
            print(f"{'='*50}\n")

            # Print events
            for event in events:
                print(f"📅 {event['name']}")
                print(f"   📍 {event['venue']} - {event['location']}")
                print(f"   🎫 {len(event['tickets'])} ticket types")
                print(f"   🔗 {event['url']}\n")

        except Exception as e:
            print(f"Error scraping {city}: {e}")
            import traceback
            traceback.print_exc()
            continue

    # Print metrics
    print(f"\n{'='*50}")
    print("SCRAPER METRICS:")
    print(json.dumps(scraper.metrics.get_summary(), indent=2))
    print(f"{'='*50}\n")


if __name__ == "__main__":
    asyncio.run(main())
