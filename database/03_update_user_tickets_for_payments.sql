-- Migration: Update user_tickets table for payment system
-- Purpose: Add payment-related columns to track sales
-- Date: 2025-11-04

-- Add new columns to user_tickets table
ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS buyer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS sold_at TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS sale_status TEXT CHECK (sale_status IN (
    'available',
    'pending_payment',
    'sold',
    'refunded'
)) DEFAULT 'available';

-- Create indexes for new columns
CREATE INDEX IF NOT EXISTS idx_user_tickets_sale_status ON user_tickets(sale_status);
CREATE INDEX IF NOT EXISTS idx_user_tickets_buyer_id ON user_tickets(buyer_id) WHERE buyer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_tickets_transaction_id ON user_tickets(transaction_id) WHERE transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_tickets_available ON user_tickets(is_listed, sale_status) WHERE is_listed = true AND sale_status = 'available';

-- Update existing tickets to have correct sale_status
UPDATE user_tickets
SET sale_status = CASE
    WHEN is_listed = true THEN 'available'
    WHEN is_listed = false AND buyer_id IS NOT NULL THEN 'sold'
    ELSE 'available'
END
WHERE sale_status IS NULL;

-- Create function to automatically unlist ticket when sold
CREATE OR REPLACE FUNCTION auto_unlist_sold_tickets()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sale_status = 'sold' AND OLD.sale_status != 'sold' THEN
        NEW.is_listed = false;
        NEW.sold_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for auto-unlisting
DROP TRIGGER IF EXISTS trigger_auto_unlist_sold_tickets ON user_tickets;
CREATE TRIGGER trigger_auto_unlist_sold_tickets
    BEFORE UPDATE ON user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION auto_unlist_sold_tickets();

-- Create view for marketplace tickets with seller verification status
CREATE OR REPLACE VIEW marketplace_tickets_with_seller_info AS
SELECT
    ut.*,
    p.username as seller_username,
    p.profile_picture_url as seller_profile_picture_url,
    p.university as seller_university,
    CASE
        WHEN sca.onboarding_completed = true THEN true
        ELSE false
    END as seller_can_receive_payments
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id = p.id
LEFT JOIN stripe_connected_accounts sca ON ut.user_id = sca.user_id
WHERE ut.is_listed = true
  AND ut.sale_status = 'available';

-- Grant access to the view
GRANT SELECT ON marketplace_tickets_with_seller_info TO authenticated;
GRANT SELECT ON marketplace_tickets_with_seller_info TO anon;

-- Create function to get user's purchase history
CREATE OR REPLACE FUNCTION get_user_purchase_history(user_uuid UUID)
RETURNS TABLE (
    ticket_id UUID,
    event_name TEXT,
    event_date TEXT,
    event_location TEXT,
    ticket_type TEXT,
    price_paid DECIMAL,
    seller_username TEXT,
    purchased_at TIMESTAMPTZ,
    transaction_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ut.id as ticket_id,
        ut.event_name,
        ut.event_date,
        ut.event_location,
        ut.ticket_type,
        t.ticket_price as price_paid,
        p.username as seller_username,
        t.payment_completed_at as purchased_at,
        t.status as transaction_status
    FROM user_tickets ut
    JOIN transactions t ON ut.transaction_id = t.id
    LEFT JOIN profiles p ON ut.user_id = p.id
    WHERE ut.buyer_id = user_uuid
    ORDER BY t.payment_completed_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to get user's sales history
CREATE OR REPLACE FUNCTION get_user_sales_history(user_uuid UUID)
RETURNS TABLE (
    ticket_id UUID,
    event_name TEXT,
    event_date TEXT,
    ticket_type TEXT,
    sale_price DECIMAL,
    buyer_username TEXT,
    sold_at TIMESTAMPTZ,
    payout_amount DECIMAL,
    payout_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ut.id as ticket_id,
        ut.event_name,
        ut.event_date,
        ut.ticket_type,
        t.ticket_price as sale_price,
        p.username as buyer_username,
        t.payment_completed_at as sold_at,
        t.seller_amount as payout_amount,
        t.status as payout_status
    FROM user_tickets ut
    JOIN transactions t ON ut.transaction_id = t.id
    LEFT JOIN profiles p ON t.buyer_id = p.id
    WHERE ut.user_id = user_uuid
      AND ut.sale_status IN ('sold', 'refunded')
    ORDER BY t.payment_completed_at DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Verify the changes
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'user_tickets'
AND column_name IN ('buyer_id', 'transaction_id', 'sold_at', 'sale_status')
ORDER BY ordinal_position;

-- Test the view
SELECT COUNT(*) as available_tickets_count
FROM marketplace_tickets_with_seller_info;
