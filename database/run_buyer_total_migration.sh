#!/bin/bash

# Run the buyer_total migration via Supabase SQL Editor
# You need to run this SQL in the Supabase Dashboard > SQL Editor

echo "================================================================"
echo "MANUAL STEP REQUIRED:"
echo "================================================================"
echo ""
echo "1. Go to: https://supabase.com/dashboard/project/skkaksjbnfxklivniqwy/sql"
echo ""
echo "2. Copy and paste this SQL:"
echo ""
cat database/add_buyer_total_column.sql
echo ""
echo "3. Click 'Run' button"
echo ""
echo "================================================================"
