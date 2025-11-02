"""
Script to explore Fixr transfer ticket link structure
"""
from playwright.async_api import async_playwright
from bs4 import BeautifulSoup
import asyncio
import json

async def explore_transfer_link():
    """Explore Fixr transfer ticket link HTML structure"""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        page = await browser.new_page()

        # The transfer ticket link from user
        url = "https://fixr.co/transfer-ticket/2156d6630b191850eb92a326"

        try:
            print(f"🔍 Fetching: {url}")
            await page.goto(url, wait_until="domcontentloaded", timeout=30000)

            # Wait for content to load
            await asyncio.sleep(5)

            # Get page title
            title = await page.title()
            print(f"\nPage Title: {title}")

            # Get page URL (might redirect)
            current_url = page.url
            print(f"Current URL: {current_url}")

            # Get HTML content
            content = await page.content()

            # Parse with BeautifulSoup
            soup = BeautifulSoup(content, 'html.parser')

            # Save full HTML for inspection
            with open('fixr_transfer_full.html', 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"\n✅ Saved HTML to fixr_transfer_full.html")

            # Look for event information
            print("\n" + "="*60)
            print("EXTRACTING EVENT INFORMATION")
            print("="*60)

            # Look for h1 (usually event name)
            h1_tags = soup.find_all('h1')
            if h1_tags:
                print(f"\n📋 H1 Tags Found ({len(h1_tags)}):")
                for idx, h1 in enumerate(h1_tags, 1):
                    print(f"  {idx}. {h1.get_text(strip=True)}")

            # Look for h2 (might have event details)
            h2_tags = soup.find_all('h2')
            if h2_tags:
                print(f"\n📋 H2 Tags Found ({len(h2_tags)}):")
                for idx, h2 in enumerate(h2_tags, 1):
                    print(f"  {idx}. {h2.get_text(strip=True)}")

            # Look for time/date elements
            print(f"\n⏰ Time/Date Elements:")
            time_tags = soup.find_all('time')
            for time_tag in time_tags:
                print(f"  - {time_tag.get_text(strip=True)} (datetime: {time_tag.get('datetime', 'N/A')})")

            # Look for elements with 'entry' in class or text
            print(f"\n🚪 Last Entry Information:")
            entry_elements = soup.find_all(text=lambda text: text and 'entry' in text.lower())
            for elem in entry_elements[:5]:
                print(f"  - {elem.strip()}")

            # Look for transferer information
            print(f"\n👤 Transferer Information:")
            # Common patterns: "from", "by", "seller", "transferring from"
            transfer_keywords = ['from', 'by', 'seller', 'transferring']
            for keyword in transfer_keywords:
                elements = soup.find_all(text=lambda text: text and keyword in text.lower())
                if elements:
                    print(f"  Keyword '{keyword}':")
                    for elem in elements[:3]:
                        print(f"    - {elem.strip()}")

            # Look for ticket type information
            print(f"\n🎫 Ticket Information:")
            ticket_keywords = ['ticket type', 'admission', 'pass', 'entry type']
            for keyword in ticket_keywords:
                elements = soup.find_all(text=lambda text: text and keyword in text.lower())
                if elements:
                    print(f"  Keyword '{keyword}':")
                    for elem in elements[:3]:
                        print(f"    - {elem.strip()}")

            # Look for price information
            print(f"\n💰 Price Information:")
            price_elements = soup.find_all(text=lambda text: text and '£' in text)
            for elem in price_elements[:5]:
                print(f"  - {elem.strip()}")

            # Look for structured data (JSON-LD)
            print(f"\n📊 Structured Data (JSON-LD):")
            json_ld_scripts = soup.find_all('script', type='application/ld+json')
            for idx, script in enumerate(json_ld_scripts, 1):
                print(f"\n  Script {idx}:")
                try:
                    data = json.loads(script.string)
                    print(json.dumps(data, indent=2)[:500])
                except:
                    print("  Could not parse JSON")

            # Look for meta tags with event info
            print(f"\n🏷️  Meta Tags:")
            meta_tags = soup.find_all('meta', property=True)
            for meta in meta_tags:
                if any(keyword in meta.get('property', '').lower() for keyword in ['title', 'description', 'image']):
                    print(f"  {meta.get('property')}: {meta.get('content', 'N/A')[:100]}")

            # Take screenshot
            await page.screenshot(path='fixr_transfer_screenshot.png', full_page=True)
            print(f"\n📸 Screenshot saved to fixr_transfer_screenshot.png")

            # Keep browser open for manual inspection
            print("\n⏸️  Browser will stay open for 30 seconds for manual inspection...")
            await asyncio.sleep(30)

        except Exception as e:
            print(f"❌ Failed: {str(e)}")
            import traceback
            traceback.print_exc()

        await browser.close()

if __name__ == "__main__":
    asyncio.run(explore_transfer_link())
