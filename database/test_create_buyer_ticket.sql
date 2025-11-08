-- Get transaction details first
SELECT
    t.id::text as transaction_id,
    t.buyer_id::text,
    t.seller_id::text,
    t.ticket_id::text as original_ticket_id
FROM transactions t
WHERE t.id = '9016954d-6b1b-41ea-aee3-48187422bb90';

-- Now manually call the RPC function to create buyer ticket
SELECT * FROM create_buyer_ticket_from_seller(
    p_buyer_id := '4e954dfb-0835-46e8-aa0d-b79838691344'::uuid,
    p_seller_id := (SELECT seller_id FROM transactions WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90'),
    p_transaction_id := '9016954d-6b1b-41ea-aee3-48187422bb90'::uuid,
    p_original_ticket_id := (SELECT ticket_id FROM transactions WHERE id = '9016954d-6b1b-41ea-aee3-48187422bb90')
);
