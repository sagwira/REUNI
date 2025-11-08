#!/bin/bash
# Fix Stripe account to be individual type

echo "Updating account to individual type..."

# Use stripe CLI to update the account
stripe accounts update acct_1SQ7oHJm3a5vohI0 \
  --business-type individual \
  2>&1

echo ""
echo "Checking updated account..."
stripe accounts retrieve acct_1SQ7oHJm3a5vohI0 2>&1 | grep -E "(business_type|business_profile)" -A5
