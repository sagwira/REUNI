-- Clean up old/invalid ticket offers that are missing required fields
-- This ensures the iOS app can properly decode all offers

-- Delete offers missing required fields
DELETE FROM ticket_offers
WHERE ticket_id IS NULL
   OR seller_id IS NULL
   OR buyer_id IS NULL
   OR offer_amount IS NULL
   OR original_price IS NULL
   OR status IS NULL;

-- Verify remaining records
SELECT COUNT(*) as total_offers,
       COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_offers,
       COUNT(CASE WHEN status = 'accepted' THEN 1 END) as accepted_offers,
       COUNT(CASE WHEN status = 'declined' THEN 1 END) as declined_offers
FROM ticket_offers;

-- Show all remaining offers
SELECT id, ticket_id, seller_id, buyer_id, offer_amount, original_price, status, created_at
FROM ticket_offers
ORDER BY created_at DESC;
