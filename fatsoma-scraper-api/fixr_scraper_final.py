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
        browser = await playwright.chromium.launch(
            headless=False,
            args=[
                '--disable-blink-features=AutomationControlled',
                '--disable-dev-shm-usage',
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--window-size=1920,1080'
            ]
        )

        context = await browser.new_context(
            viewport={'width': 1920, 'height': 1080},
            user_agent='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            locale='en-GB',
            timezone_id='Europe/London',
            geolocation={'longitude': -0.1276, 'latitude': 51.5074},
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
            window.chrome = { runtime: {} };
        """)

        return browser, page

    async def scrape_events_by_search(self, search_query: str = "stealth", limit: int = 50) -> List[Dict]:
        """Scrape events from Fixr by search query"""
        try:
            self.logger.info(f"🚀 Starting Fixr scrape for query: {search_query}, limit: {limit}")

            async with async_playwright() as p:
                browser, page = await self._setup_stealth_browser(p)

                # Navigate to homepage first
                self.logger.info("📡 Loading Fixr homepage...")
                await page.goto(self.base_url, wait_until="domcontentloaded", timeout=60000)
                await asyncio.sleep(random.uniform(2, 3))

                # Navigate to search page with query
                url = f"{self.base_url}/search?query={search_query}&type=events"
                self.logger.info(f"📡 Searching for: {url}")
                await page.goto(url, wait_until="domcontentloaded", timeout=60000)
                await asyncio.sleep(random.uniform(3, 5))

                # Scroll to load dynamic content
                for i in range(5):
                    scroll_amount = random.randint(300, 800)
                    await page.evaluate(f"window.scrollBy(0, {scroll_amount})")
                    await asyncio.sleep(random.uniform(0.5, 1.5))

                await asyncio.sleep(3)

                # Take screenshot
                await page.screenshot(path=f'fixr_search_{search_query}.png')
                self.logger.info(f"📸 Screenshot saved")

                content = await page.content()
                soup = BeautifulSoup(content, 'html.parser')

                # Save HTML for debugging
                with open(f'fixr_search_{search_query}.html', 'w', encoding='utf-8') as f:
                    f.write(content)

                # Extract event links - multiple methods
                event_links = []

                # Method 1: Direct event links
                links = soup.find_all('a', href=re.compile(r'/event/'))
                event_links.extend(links)
                self.logger.info(f"Found {len(links)} event links")

                # Method 2: From carousel items
                carousel_items = soup.find_all('div', class_=re.compile(r'carousel-slide'))
                for item in carousel_items:
                    title_elem = item.find(['h2', 'h3'])
                    img_elem = item.find('img')
                    if title_elem:
                        self.logger.info(f"Found carousel event: {title_elem.get_text(strip=True)}")

                # Method 3: Extract from search results directly
                events = await self._extract_events_from_search_page(soup, search_query)

                if events:
                    self.logger.info(f"✅ Extracted {len(events)} events from search page")
                    self.metrics.log_success(len(events))
                    await browser.close()
                    return events

                # Method 4: If we have event URLs, scrape them
                if event_links:
                    event_urls = list(set([link.get('href') for link in event_links if link.get('href')]))
                    event_urls = [url if url.startswith('http') else f"{self.base_url}{url}" for url in event_urls]
                    event_urls = [url for url in event_urls if '/event/' in url][:limit]

                    self.logger.info(f"📋 Found {len(event_urls)} unique event URLs")

                    events = []
                    for idx, event_url in enumerate(event_urls, 1):
                        try:
                            self.logger.info(f"🎫 Scraping event {idx}/{len(event_urls)}")

                            if idx > 1:
                                await asyncio.sleep(random.uniform(self.min_delay, self.max_delay))

                            event_data = await self._scrape_event_details(page, event_url)
                            if event_data:
                                events.append(event_data)

                        except Exception as e:
                            self.logger.error(f"Error scraping event: {str(e)}")
                            continue

                    await browser.close()
                    self.metrics.log_success(len(events))
                    return events

                # No events found
                error_msg = f"No events found for query: {search_query}"
                self.logger.warning(error_msg)
                self.metrics.log_failure(error_msg)
                await browser.close()
                return []

        except Exception as e:
            error_msg = f"Fatal error scraping {search_query}: {str(e)}"
            self.metrics.log_failure(error_msg)
            if self.alerter:
                self.alerter.alert_fatal_error(search_query, str(e), self.metrics.get_summary())
            raise

    async def _extract_events_from_search_page(self, soup, query: str) -> List[Dict]:
        """Extract event data directly from search results page"""
        events = []

        # Look for event cards, articles, or divs with event info
        potential_containers = [
            soup.find_all('article'),
            soup.find_all('div', class_=re.compile(r'event|card', re.I)),
            soup.find_all('a', href=re.compile(r'/event/')),
        ]

        processed_urls = set()

        for container_list in potential_containers:
            for elem in container_list:
                try:
                    event_data = {
                        'name': '',
                        'date': '',
                        'location': '',
                        'venue': '',
                        'description': '',
                        'imageUrl': '',
                        'lastEntry': '',
                        'company': '',
                        'url': '',
                        'source': 'fixr',
                        'tickets': []
                    }

                    # Extract event name
                    title_elem = elem.find(['h1', 'h2', 'h3', 'h4', 'h5'])
                    if title_elem:
                        event_data['name'] = title_elem.get_text(strip=True)

                    # Extract URL
                    link_elem = elem.find('a', href=True) if elem.name != 'a' else elem
                    if link_elem and link_elem.get('href'):
                        href = link_elem['href']
                        event_data['url'] = href if href.startswith('http') else f"{self.base_url}{href}"

                    # Skip if no URL or already processed
                    if not event_data['url'] or '/event/' not in event_data['url']:
                        continue
                    if event_data['url'] in processed_urls:
                        continue
                    processed_urls.add(event_data['url'])

                    # Extract image
                    img_elem = elem.find('img', src=True)
                    if img_elem:
                        src = img_elem['src']
                        event_data['imageUrl'] = src if src.startswith('http') else f"{self.base_url}{src}"

                    # Extract date from text
                    date_match = elem.find(text=re.compile(r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}'))
                    if date_match:
                        event_data['date'] = date_match.strip()

                    # Extract location (look for common UK cities)
                    location_match = elem.find(text=re.compile(r'London|Manchester|Birmingham|Leeds|Nottingham|Bristol|Liverpool|Sheffield|Edinburgh|Glasgow', re.I))
                    if location_match:
                        event_data['location'] = location_match.strip()

                    # Add default ticket
                    event_data['tickets'].append({
                        'ticketType': 'General Admission',
                        'price': 0.0,
                        'available': True
                    })

                    if event_data['name'] and event_data['url']:
                        events.append(event_data)
                        self.logger.info(f"✅ Extracted: {event_data['name']}")

                except Exception as e:
                    self.logger.debug(f"Could not extract event from element: {e}")
                    continue

        return events

    async def _scrape_event_details(self, page, event_url: str) -> Dict:
        """Scrape details from a single event page"""
        try:
            await page.goto(event_url, wait_until="domcontentloaded", timeout=60000)
            await asyncio.sleep(random.uniform(2, 4))

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

            # Extract event name
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

            # Extract location
            location_match = soup.find(text=re.compile(r'London|Manchester|Birmingham|Leeds|Nottingham|Bristol|Liverpool|Sheffield|Edinburgh|Glasgow', re.I))
            if location_match:
                event_data['location'] = location_match.strip()

            # Extract venue
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

            # Extract ticket prices
            price_pattern = r'[£$](\d+(?:\.\d{2})?)'
            prices = soup.find_all(text=re.compile(price_pattern))
            for price_text in prices[:5]:
                price_match = re.search(price_pattern, price_text)
                if price_match:
                    event_data['tickets'].append({
                        'ticketType': 'General Admission',
                        'price': float(price_match.group(1)),
                        'available': True
                    })

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
            self.logger.error(f"Error extracting event details: {str(e)}")
            return None


# Example usage
async def main():
    scraper = FixrScraper(min_delay=2.0, max_delay=4.0, enable_alerts=False)

    # Search for specific events that are likely to have results
    search_queries = [
        "stealth",
        "clubbing",
        "nightlife",
        "rave",
        "festival"
    ]

    all_events = []

    for query in search_queries:
        try:
            events = await scraper.scrape_events_by_search(query, limit=10)
            all_events.extend(events)

            print(f"\n{'='*50}")
            print(f"Query: {query.upper()}")
            print(f"Events found: {len(events)}")
            print(f"{'='*50}\n")

            for event in events[:3]:
                print(f"📅 {event['name']}")
                print(f"   📍 {event['venue']} - {event['location']}")
                print(f"   🎫 {len(event['tickets'])} ticket types")
                print(f"   🔗 {event['url']}\n")

            # Small delay between queries
            await asyncio.sleep(5)

        except Exception as e:
            print(f"Error scraping query '{query}': {e}")
            import traceback
            traceback.print_exc()
            continue

    # Remove duplicates based on URL
    unique_events = []
    seen_urls = set()
    for event in all_events:
        if event['url'] not in seen_urls:
            unique_events.append(event)
            seen_urls.add(event['url'])

    print(f"\n{'='*50}")
    print(f"TOTAL UNIQUE EVENTS: {len(unique_events)}")
    print(f"{'='*50}")

    # Print metrics
    print(f"\n{'='*50}")
    print("SCRAPER METRICS:")
    print(json.dumps(scraper.metrics.get_summary(), indent=2))
    print(f"{'='*50}\n")


if __name__ == "__main__":
    asyncio.run(main())
