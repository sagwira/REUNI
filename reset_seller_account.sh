#!/bin/bash
# Reset seller account - delete old one and they can create a new individual account

USER_ID="4e954dfb-0835-46e8-aa0d-b79838691344"
ACCOUNT_ID="acct_1SQ7oHJm3a5vohI0"

echo "🗑️  Deleting Stripe account: $ACCOUNT_ID"
stripe accounts delete $ACCOUNT_ID 2>&1

echo ""
echo "🗑️  Deleting from database..."
psql "postgresql://postgres.skkaksjbnfxklivniqwy:Afg02Mjf*HKz3gJ@aws-0-eu-west-2.pooler.supabase.com:6543/postgres" << EOF
DELETE FROM stripe_connected_accounts WHERE user_id = '$USER_ID';
SELECT 'Deleted ' || ROW_COUNT() || ' rows from stripe_connected_accounts';
EOF

echo ""
echo "✅ Done! User can now create a new INDIVIDUAL Stripe account."
echo "   They should:"
echo "   1. Go to Profile → Become a Seller"
echo "   2. Complete the form (will be INDIVIDUAL this time)"
