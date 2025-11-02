"""
Test script to explore Fatsoma's API
"""
import asyncio
import aiohttp
import json

async def test_fatsoma_api():
    print("🔍 Testing Fatsoma API...")

    base_url = "https://api.fatsoma.com/v1"

    # API key from the HTML
    api_key = "fk_ui_cust_aff50532-bbb5-45ed-9d0a-4ad144814b9f"

    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "application/json",
    }

    async with aiohttp.ClientSession() as session:

        # Test 1: Try to get events for London
        print("\n" + "="*60)
        print("TEST 1: Fetching events")
        print("="*60)

        # Try different endpoints
        endpoints = [
            f"{base_url}/events?location=london",
            f"{base_url}/events?city=london",
            f"{base_url}/events?q=london",
            f"{base_url}/search/events?location=london",
            f"{base_url}/events",
        ]

        for endpoint in endpoints:
            print(f"\n📍 Trying: {endpoint}")
            try:
                async with session.get(endpoint, headers=headers) as response:
                    print(f"   Status: {response.status}")

                    if response.status == 200:
                        data = await response.json()
                        print(f"   ✅ Success!")
                        print(f"   Response keys: {data.keys()}")

                        if 'data' in data:
                            print(f"   Events found: {len(data['data'])}")

                            if len(data['data']) > 0:
                                # Print first event as sample
                                print("\n   📋 Sample event:")
                                print(json.dumps(data['data'][0], indent=2)[:500])

                        # Save full response
                        with open('api_response.json', 'w') as f:
                            json.dump(data, f, indent=2)
                        print(f"\n   💾 Full response saved to: api_response.json")

                        return  # Success, exit
                    else:
                        text = await response.text()
                        print(f"   ❌ Error: {text[:200]}")

            except Exception as e:
                print(f"   ❌ Exception: {e}")

        # Test 2: Try to get categories
        print("\n" + "="*60)
        print("TEST 2: Fetching categories")
        print("="*60)

        try:
            endpoint = f"{base_url}/categories"
            print(f"\n📍 Trying: {endpoint}")

            async with session.get(endpoint, headers=headers) as response:
                print(f"   Status: {response.status}")

                if response.status == 200:
                    data = await response.json()
                    print(f"   ✅ Success!")
                    print(f"   Categories found: {len(data.get('data', []))}")

                    # Save response
                    with open('api_categories.json', 'w') as f:
                        json.dump(data, f, indent=2)
                    print(f"   💾 Saved to: api_categories.json")

        except Exception as e:
            print(f"   ❌ Exception: {e}")

if __name__ == "__main__":
    asyncio.run(test_fatsoma_api())
