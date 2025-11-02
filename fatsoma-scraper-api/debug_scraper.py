"""
Debug script to inspect Fatsoma's HTML structure
This will help us identify the correct CSS selectors
"""
import asyncio
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import re

async def debug_fatsoma():
    print("🔍 Starting Fatsoma HTML inspection...")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()

        # Navigate to London events
        url = "https://www.fatsoma.com/e/london"
        print(f"\n📍 Navigating to: {url}")

        try:
            await page.goto(url, wait_until="networkidle", timeout=30000)
            print("✅ Page loaded successfully")

            # Wait a bit for any dynamic content
            await asyncio.sleep(2)

            # Scroll to load more content
            print("\n📜 Scrolling to load more content...")
            for i in range(3):
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                await asyncio.sleep(1)
                print(f"  Scroll {i+1}/3 complete")

            # Get page content
            content = await page.content()

            # Save full HTML for inspection
            with open('fatsoma_debug.html', 'w', encoding='utf-8') as f:
                f.write(content)
            print("\n💾 Full HTML saved to: fatsoma_debug.html")

            # Parse with BeautifulSoup
            soup = BeautifulSoup(content, 'html.parser')

            # Debug: Find all divs with class containing 'event'
            print("\n" + "="*60)
            print("🔎 SEARCHING FOR EVENT CONTAINERS")
            print("="*60)

            event_divs = soup.find_all('div', class_=re.compile(r'event', re.IGNORECASE))
            print(f"\n📦 Found {len(event_divs)} divs with 'event' in class name")

            if event_divs:
                print("\n📋 Sample class names:")
                for i, div in enumerate(event_divs[:5]):  # Show first 5
                    classes = div.get('class', [])
                    print(f"  {i+1}. {' '.join(classes)}")

            # Look for card-like elements
            print("\n" + "="*60)
            print("🔎 SEARCHING FOR CARD ELEMENTS")
            print("="*60)

            card_divs = soup.find_all('div', class_=re.compile(r'card', re.IGNORECASE))
            print(f"\n📦 Found {len(card_divs)} divs with 'card' in class name")

            if card_divs:
                print("\n📋 Sample class names:")
                for i, div in enumerate(card_divs[:5]):
                    classes = div.get('class', [])
                    print(f"  {i+1}. {' '.join(classes)}")

            # Look for links to event pages
            print("\n" + "="*60)
            print("🔎 SEARCHING FOR EVENT LINKS")
            print("="*60)

            event_links = soup.find_all('a', href=re.compile(r'/e/'))
            print(f"\n🔗 Found {len(event_links)} links with '/e/' in href")

            if event_links:
                print("\n📋 Sample event links:")
                for i, link in enumerate(event_links[:5]):
                    href = link.get('href', '')
                    text = link.get_text(strip=True)[:50]  # First 50 chars
                    print(f"  {i+1}. {href}")
                    print(f"     Text: {text}")

            # Look for common container patterns
            print("\n" + "="*60)
            print("🔎 SEARCHING FOR COMMON PATTERNS")
            print("="*60)

            # Check for article tags
            articles = soup.find_all('article')
            print(f"\n📰 Found {len(articles)} <article> tags")

            # Check for list items
            list_items = soup.find_all('li', class_=re.compile(r'event|card', re.IGNORECASE))
            print(f"📝 Found {len(list_items)} <li> tags with event/card classes")

            # Check for sections
            sections = soup.find_all('section')
            print(f"📄 Found {len(sections)} <section> tags")

            # Try to find the first event-like element with detailed info
            print("\n" + "="*60)
            print("🔎 DETAILED INSPECTION OF FIRST EVENT-LIKE ELEMENT")
            print("="*60)

            if event_links:
                first_link = event_links[0]
                parent = first_link.parent

                print(f"\n🎯 Parent tag: <{parent.name}>")
                print(f"🏷️  Parent classes: {' '.join(parent.get('class', []))}")
                print(f"\n📝 HTML structure:")
                print(parent.prettify()[:500])  # First 500 chars

                # Save first event structure
                with open('fatsoma_first_event.html', 'w', encoding='utf-8') as f:
                    f.write(parent.prettify())
                print("\n💾 First event HTML saved to: fatsoma_first_event.html")

            print("\n" + "="*60)
            print("✅ DEBUG COMPLETE")
            print("="*60)
            print("\n📂 Files created:")
            print("  1. fatsoma_debug.html - Full page HTML")
            print("  2. fatsoma_first_event.html - First event element structure")
            print("\n💡 Next steps:")
            print("  1. Open these files to inspect the HTML structure")
            print("  2. Identify the correct CSS selectors")
            print("  3. Update scraper.py with the correct selectors")

        except Exception as e:
            print(f"\n❌ Error: {e}")
            import traceback
            traceback.print_exc()

        finally:
            await browser.close()

if __name__ == "__main__":
    asyncio.run(debug_fatsoma())
