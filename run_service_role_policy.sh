#!/bin/bash
# Run the service role INSERT policy migration

echo "🔧 Running service role INSERT policy migration..."
echo ""
echo "📋 This will add a policy to allow Edge Functions to insert Stripe accounts"
echo ""
echo "Please run the following SQL in your Supabase SQL Editor:"
echo "https://supabase.com/dashboard/project/skkaksjbnfxklivniqwy/sql/new"
echo ""
echo "=================================="
cat database/add_service_role_insert_policy.sql
echo "=================================="
echo ""
echo "Or use this one-liner:"
echo ""
echo "CREATE POLICY \"Service role can insert Stripe accounts\" ON stripe_connected_accounts FOR INSERT WITH CHECK (auth.jwt()->>'role' = 'service_role');"
