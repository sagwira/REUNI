#!/bin/bash
# Enable transfers capability for Stripe Express account in test mode

ACCOUNT_ID="acct_1SQ7oHJm3a5vohI0"

echo "Enabling transfers capability for account: $ACCOUNT_ID"

stripe accounts update $ACCOUNT_ID \
  --capabilities.transfers.requested=true

echo ""
echo "Checking account status:"
stripe accounts retrieve --account $ACCOUNT_ID | grep -A10 "capabilities"
