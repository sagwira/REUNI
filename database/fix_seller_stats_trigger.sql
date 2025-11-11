-- Fix the update_seller_stats trigger to handle UUID/TEXT casting properly

CREATE OR REPLACE FUNCTION update_seller_stats()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE seller_profiles
    SET
        active_listings = (
            SELECT COUNT(*)
            FROM user_tickets
            WHERE user_id::text = NEW.user_id::text
              AND is_listed = true
              AND sale_status = 'available'
        ),
        total_listings = (
            SELECT COUNT(*)
            FROM user_tickets
            WHERE user_id::text = NEW.user_id::text
        ),
        sold_listings = (
            SELECT COUNT(*)
            FROM user_tickets
            WHERE user_id::text = NEW.user_id::text
              AND sale_status = 'sold'
        ),
        updated_at = NOW()
    WHERE user_id::text = NEW.user_id::text;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
