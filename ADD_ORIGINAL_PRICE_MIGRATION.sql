-- Migration: Add original_price column to existing tickets table
-- Run this SQL if you already have a tickets table and need to add the original_price column
-- Run this in your Supabase SQL Editor

-- Add the original_price column
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS original_price DECIMAL(10, 2);

-- Done! The original_price column is now added to your tickets table
-- It's optional, so existing tickets will have NULL for this field
