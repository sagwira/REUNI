"""
Script to explore Fixr website structure with better selectors
"""
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import asyncio
import re

async def explore_fixr():
    """Explore Fixr's HTML structure"""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        # Try events in a specific city
        url = "https://www.fixr.co/search?query=nottingham&type=events"

        try:
            print(f"🔍 Trying: {url}")
            await page.goto(url, wait_until="networkidle", timeout=30000)

            # Wait a bit for content to load
            await asyncio.sleep(5)

            # Scroll to load more
            for i in range(3):
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                await asyncio.sleep(2)

            # Get page title
            title = await page.title()
            print(f"Title: {title}")

            # Get page URL (might redirect)
            current_url = page.url
            print(f"Current URL: {current_url}")

            # Get HTML content
            content = await page.content()

            # Parse with BeautifulSoup
            soup = BeautifulSoup(content, 'html.parser')

            # Look for event elements
            print("\n📋 Searching for event elements...")

            # Try to find event cards
            event_selectors = [
                ('article', None),
                ('a', {'href': re.compile(r'/event/')}),
                ('div', {'class': re.compile(r'event', re.I)}),
                ('div', {'class': re.compile(r'card', re.I)}),
            ]

            for tag, attrs in event_selectors:
                elements = soup.find_all(tag, attrs, limit=5)
                if elements:
                    print(f"\nFound {len(elements)} elements with {tag} {attrs}")
                    for idx, elem in enumerate(elements[:2]):  # Show first 2
                        print(f"\n--- Element {idx+1} ---")
                        print(elem.prettify()[:500])

            # Save full HTML
            with open('fixr_explore_full.html', 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"\n✅ Saved HTML to fixr_explore_full.html")

        except Exception as e:
            print(f"❌ Failed: {str(e)}")

        await asyncio.sleep(5)  # Keep browser open to see results
        await browser.close()

if __name__ == "__main__":
    asyncio.run(explore_fixr())
