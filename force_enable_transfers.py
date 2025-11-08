#!/usr/bin/env python3
"""
Force enable transfers capability for Stripe test account
This bypasses the normal onboarding requirements for testing purposes
"""

import stripe
import subprocess
import json

# Get Stripe secret key from Supabase secrets
result = subprocess.run(['supabase', 'secrets', 'list'], capture_output=True, text=True)
for line in result.stdout.split('\n'):
    if 'STRIPE_SECRET_KEY' in line:
        # Extract the hash, then get the actual value
        break

# Use Stripe CLI to get the key
result = subprocess.run(['stripe', 'config', '--list'], capture_output=True, text=True)
api_key = None
for line in result.stdout.split('\n'):
    if 'test_mode_api_key' in line:
        api_key = line.split('=')[1].strip()
        break

if not api_key:
    print("❌ Could not find Stripe API key")
    exit(1)

stripe.api_key = api_key
print(f"✅ Using Stripe key: {api_key[:20]}...")

account_id = "acct_1SQ7oHJm3a5vohI0"

print(f"\n🔍 Checking account: {account_id}")
account = stripe.Account.retrieve(account_id)

print(f"\n📊 Current status:")
print(f"   charges_enabled: {account.charges_enabled}")
print(f"   payouts_enabled: {account.payouts_enabled}")
print(f"   details_submitted: {account.details_submitted}")
print(f"   capabilities: {account.capabilities}")

print(f"\n🔧 Updating account to enable transfers...")

try:
    # Update the account with minimal requirements for test mode
    updated_account = stripe.Account.modify(
        account_id,
        capabilities={
            "transfers": {"requested": True},
            "card_payments": {"requested": True},
        },
        # Add test external account (bank account)
        external_account={
            "object": "bank_account",
            "country": "GB",
            "currency": "gbp",
            "account_number": "00012345",
            "routing_number": "108800",  # UK sort code format: 10-88-00
        },
        # Mark TOS as accepted (test mode only)
        tos_acceptance={
            "date": 1234567890,
            "ip": "127.0.0.1",
        },
    )

    print(f"\n✅ Account updated!")
    print(f"   New capabilities: {updated_account.capabilities}")
    print(f"   charges_enabled: {updated_account.charges_enabled}")
    print(f"   payouts_enabled: {updated_account.payouts_enabled}")

except Exception as e:
    print(f"\n❌ Error: {e}")
    print(f"\n💡 Alternative: Update via Stripe CLI")
    print(f"   stripe accounts update {account_id} --capabilities.transfers.requested=true")
