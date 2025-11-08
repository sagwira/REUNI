-- Add event information directly to user_tickets table
-- This removes the dependency on the tickets table LEFT JOIN

-- Add new columns to user_tickets table
ALTER TABLE user_tickets
ADD COLUMN IF NOT EXISTS event_name TEXT,
ADD COLUMN IF NOT EXISTS event_date TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS venue_name TEXT,
ADD COLUMN IF NOT EXISTS event_image_url TEXT,
ADD COLUMN IF NOT EXISTS ticket_type TEXT,
ADD COLUMN IF NOT EXISTS ticket_source TEXT DEFAULT 'user_upload',
ADD COLUMN IF NOT EXISTS organizer_name TEXT,
ADD COLUMN IF NOT EXISTS city TEXT,
ADD COLUMN IF NOT EXISTS is_listed BOOLEAN DEFAULT true;

-- If event_location column exists (from old upload code), copy data to venue_name
-- This handles migration of existing data
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'user_tickets'
        AND column_name = 'event_location'
    ) THEN
        -- Copy event_location to venue_name for existing records
        UPDATE user_tickets
        SET venue_name = event_location
        WHERE venue_name IS NULL AND event_location IS NOT NULL;

        -- Optionally drop the old column (uncomment if you want to clean up)
        -- ALTER TABLE user_tickets DROP COLUMN IF EXISTS event_location;
    END IF;
END $$;

-- Drop the existing view first to avoid column name conflicts
DROP VIEW IF EXISTS user_tickets_with_profiles;

-- Create the view with new columns
CREATE VIEW user_tickets_with_profiles AS
SELECT
    ut.id,
    ut.user_id,
    ut.ticket_id,
    ut.quantity,
    ut.price_paid,
    ut.is_listed,
    ut.created_at,
    ut.updated_at,
    -- Event information from user_tickets table directly
    ut.event_name,
    ut.event_date,
    ut.venue_name,
    ut.event_image_url as ticket_image_url,
    ut.ticket_type,
    ut.ticket_source,
    ut.organizer_name,
    ut.city,
    -- Profile information
    p.username,
    p.full_name,
    p.profile_picture_url,
    p.university,
    p.city as user_city
FROM user_tickets ut
LEFT JOIN profiles p ON ut.user_id::uuid = p.id;

-- Grant access to authenticated and anonymous users
GRANT SELECT ON user_tickets_with_profiles TO authenticated;
GRANT SELECT ON user_tickets_with_profiles TO anon;

-- Note: Views cannot have RLS policies
-- RLS is enforced on the underlying user_tickets table
