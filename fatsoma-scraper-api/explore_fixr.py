"""
Script to explore Fixr website structure
"""
from playwright.async_api import async_playwright
import asyncio

async def explore_fixr():
    """Explore Fixr's HTML structure"""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        # Try different potential URLs
        test_urls = [
            "https://www.fixr.co/search?query=london",
            "https://www.fixr.co/events/london",
            "https://www.fixr.co/london",
            "https://fixr.co/search?q=london"
        ]

        for url in test_urls:
            try:
                print(f"\n🔍 Trying: {url}")
                await page.goto(url, wait_until="networkidle", timeout=15000)

                # Wait a bit for content to load
                await asyncio.sleep(3)

                # Get page title
                title = await page.title()
                print(f"   Title: {title}")

                # Get page URL (might redirect)
                current_url = page.url
                print(f"   Current URL: {current_url}")

                # Try to find event cards with common class names
                selectors = [
                    '.event-card',
                    '.event-item',
                    '[data-testid*="event"]',
                    'article',
                    '.card',
                    '.result',
                    '.search-result'
                ]

                for selector in selectors:
                    count = await page.locator(selector).count()
                    if count > 0:
                        print(f"   Found {count} elements with selector: {selector}")

                # Save HTML for inspection
                content = await page.content()
                with open(f'fixr_explore_{test_urls.index(url)}.html', 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"   Saved HTML to fixr_explore_{test_urls.index(url)}.html")

                # If we got here successfully, break
                print(f"✅ Success with: {url}")
                break

            except Exception as e:
                print(f"   ❌ Failed: {str(e)}")
                continue

        await browser.close()

if __name__ == "__main__":
    asyncio.run(explore_fixr())
