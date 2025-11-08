-- Add buyer_total column to transactions table
-- This stores the total amount the buyer pays (ticket price + platform fee)

-- Check if column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'transactions' 
        AND column_name = 'buyer_total'
    ) THEN
        ALTER TABLE transactions 
        ADD COLUMN buyer_total NUMERIC(10,2);
        
        RAISE NOTICE 'Added buyer_total column to transactions table';
    ELSE
        RAISE NOTICE 'buyer_total column already exists';
    END IF;
END $$;

-- Update existing records to calculate buyer_total from ticket_price + platform_fee
UPDATE transactions
SET buyer_total = COALESCE(ticket_price, 0) + COALESCE(platform_fee, 0)
WHERE buyer_total IS NULL;

SELECT 'buyer_total column added and populated!' as status;
