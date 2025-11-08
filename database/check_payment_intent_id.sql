-- Check the stripe_payment_intent_id for transaction 6FCBE832-3FBE-4926-83D2-9C844DC3CCAA

SELECT
    id,
    ticket_id,
    buyer_id,
    seller_id,
    stripe_payment_intent_id,
    status,
    created_at
FROM transactions
WHERE id = '6FCBE832-3FBE-4926-83D2-9C844DC3CCAA';
