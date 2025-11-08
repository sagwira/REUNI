#!/bin/bash

# Test Escrow Release Function
# This manually triggers the release-escrow-funds Edge Function

echo "🔄 Testing Escrow Release Function..."
echo ""
echo "⚠️  NOTE: You need your Supabase Service Role Key"
echo "    Get it from: https://app.supabase.com/project/skkaksjbnfxklivniqwy/settings/api"
echo ""
echo "Enter your Service Role Key (starts with 'eyJ...'):"
read -r SERVICE_ROLE_KEY

if [ -z "$SERVICE_ROLE_KEY" ]; then
    echo "❌ No key provided. Exiting."
    exit 1
fi

echo ""
echo "📡 Calling release-escrow-funds function..."
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "https://skkaksjbnfxklivniqwy.supabase.co/functions/v1/release-escrow-funds" \
  -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json")

HTTP_BODY=$(echo "$RESPONSE" | sed -e 's/HTTP_STATUS\:.*//g')
HTTP_STATUS=$(echo "$RESPONSE" | tr -d '\n' | sed -e 's/.*HTTP_STATUS://')

echo "Response:"
echo "$HTTP_BODY" | python3 -m json.tool 2>/dev/null || echo "$HTTP_BODY"
echo ""
echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "✅ Function executed successfully!"
else
    echo "❌ Function failed with status $HTTP_STATUS"
fi
