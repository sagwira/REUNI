"""
Test Supabase Storage upload to verify RLS policy issue
"""
import os
from supabase import create_client
from dotenv import load_dotenv
import io

load_dotenv()

def test_storage_upload():
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_KEY")

    if not supabase_url or not supabase_key:
        raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")

    client = create_client(supabase_url, supabase_key)

    print("🧪 Testing Supabase Storage Upload...")
    print(f"   Bucket: tickets")
    print(f"   Path: ticket-screenshots/test.jpg")

    # Create a small test image (1x1 red pixel JPEG)
    test_image_data = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x0b\x08\x00\x01\x00\x01\x01\x01\x11\x00\xff\xc4\x00\x1f\x00\x00\x01\x05\x01\x01\x01\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\xff\xc4\x00\xb5\x10\x00\x02\x01\x03\x03\x02\x04\x03\x05\x05\x04\x04\x00\x00\x01}\x01\x02\x03\x00\x04\x11\x05\x12!1A\x06\x13Qa\x07"q\x142\x81\x91\xa1\x08#B\xb1\xc1\x15R\xd1\xf0$3br\x82\t\n\x16\x17\x18\x19\x1a%&\'()*456789:CDEFGHIJSTUVWXYZcdefghijstuvwxyz\x83\x84\x85\x86\x87\x88\x89\x8a\x92\x93\x94\x95\x96\x97\x98\x99\x9a\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xff\xda\x00\x08\x01\x01\x00\x00?\x00\xf5?\xff\xd9'

    try:
        print("\n📤 Attempting upload with SERVICE_KEY (should work)...")

        # Upload using service key (should bypass RLS)
        response = client.storage.from_("tickets").upload(
            path="ticket-screenshots/test.jpg",
            file=test_image_data,
            file_options={
                "content-type": "image/jpeg"
            }
        )

        print(f"✅ Upload successful with SERVICE_KEY!")
        print(f"   Response: {response}")

        # Get public URL
        public_url = client.storage.from_("tickets").get_public_url("ticket-screenshots/test.jpg")
        print(f"   Public URL: {public_url}")

    except Exception as e:
        print(f"❌ Upload failed with SERVICE_KEY: {e}")
        print(f"   Error type: {type(e).__name__}")

    print("\n" + "="*60)

    # Now test with ANON key (simulates iOS app upload)
    try:
        print("\n📤 Attempting upload with ANON_KEY (simulates iOS app)...")
        anon_key = os.getenv("SUPABASE_ANON_KEY")

        if not anon_key:
            print("⚠️  SUPABASE_ANON_KEY not found in .env")
            print("   Add it to test RLS policy enforcement")
            return

        anon_client = create_client(supabase_url, anon_key)

        response = anon_client.storage.from_("tickets").upload(
            path="ticket-screenshots/test_anon.jpg",
            file=test_image_data,
            file_options={
                "content-type": "image/jpeg"
            }
        )

        print(f"✅ Upload successful with ANON_KEY!")
        print(f"   Response: {response}")
        print(f"\n   🎉 RLS policy is working correctly!")

    except Exception as e:
        print(f"❌ Upload failed with ANON_KEY: {e}")
        print(f"   Error type: {type(e).__name__}")
        print(f"\n   ⚠️  This is the RLS policy blocking uploads!")
        print(f"   👉 You need to add the storage policy to fix this.")

    print("\n" + "="*60)
    print("\n📋 Next Steps:")
    print("   1. If ANON upload failed → Add RLS policy in Supabase")
    print("   2. After adding policy → Run this test again")
    print("   3. If ANON upload succeeds → iOS app will work!")

if __name__ == "__main__":
    test_storage_upload()
