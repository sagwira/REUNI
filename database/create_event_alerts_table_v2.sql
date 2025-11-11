-- Create event_alerts table for tracking user-watched events
-- This is a safe migration that checks if objects exist before creating them

-- Create event_alerts table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'event_alerts') THEN
        CREATE TABLE event_alerts (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            event_name TEXT NOT NULL,
            event_date TIMESTAMPTZ,
            event_location TEXT,
            ticket_source TEXT, -- 'fatsoma' or 'fixr' or NULL for all sources
            is_active BOOLEAN DEFAULT true,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            last_notified_at TIMESTAMPTZ,

            -- Prevent duplicate alerts for same user/event
            UNIQUE(user_id, event_name, event_date)
        );

        -- Create indexes
        CREATE INDEX idx_event_alerts_user_id ON event_alerts(user_id);
        CREATE INDEX idx_event_alerts_active ON event_alerts(is_active) WHERE is_active = true;
        CREATE INDEX idx_event_alerts_event_name ON event_alerts(event_name);

        -- Enable RLS
        ALTER TABLE event_alerts ENABLE ROW LEVEL SECURITY;

        -- Create policies
        CREATE POLICY "Users can view own alerts" ON event_alerts
            FOR SELECT USING (auth.uid() = user_id);

        CREATE POLICY "Users can create own alerts" ON event_alerts
            FOR INSERT WITH CHECK (auth.uid() = user_id);

        CREATE POLICY "Users can update own alerts" ON event_alerts
            FOR UPDATE USING (auth.uid() = user_id);

        CREATE POLICY "Users can delete own alerts" ON event_alerts
            FOR DELETE USING (auth.uid() = user_id);

        RAISE NOTICE 'Created event_alerts table';
    ELSE
        RAISE NOTICE 'event_alerts table already exists';
    END IF;
END
$$;

-- Handle notifications table - check if it exists and has correct structure
DO $$
BEGIN
    -- Check if notifications table exists
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notifications') THEN
        RAISE NOTICE 'notifications table already exists, checking structure...';

        -- Add missing columns if they don't exist
        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'notifications' AND column_name = 'notification_type') THEN
            ALTER TABLE notifications ADD COLUMN notification_type TEXT NOT NULL DEFAULT 'new_listing';
            RAISE NOTICE 'Added notification_type column';
        END IF;

        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'notifications' AND column_name = 'title') THEN
            ALTER TABLE notifications ADD COLUMN title TEXT NOT NULL DEFAULT 'Notification';
            RAISE NOTICE 'Added title column';
        END IF;

        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'notifications' AND column_name = 'message') THEN
            ALTER TABLE notifications ADD COLUMN message TEXT NOT NULL DEFAULT '';
            RAISE NOTICE 'Added message column';
        END IF;

        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'notifications' AND column_name = 'ticket_id') THEN
            ALTER TABLE notifications ADD COLUMN ticket_id UUID REFERENCES user_tickets(id) ON DELETE CASCADE;
            RAISE NOTICE 'Added ticket_id column';
        END IF;

        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'notifications' AND column_name = 'event_name') THEN
            ALTER TABLE notifications ADD COLUMN event_name TEXT;
            RAISE NOTICE 'Added event_name column';
        END IF;

        IF NOT EXISTS (SELECT FROM information_schema.columns
                      WHERE table_name = 'notifications' AND column_name = 'is_read') THEN
            ALTER TABLE notifications ADD COLUMN is_read BOOLEAN DEFAULT false;
            RAISE NOTICE 'Added is_read column';
        END IF;
    ELSE
        -- Create new notifications table
        CREATE TABLE notifications (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
            notification_type TEXT NOT NULL, -- 'new_listing', 'offer_accepted', etc.
            title TEXT NOT NULL,
            message TEXT NOT NULL,
            ticket_id UUID REFERENCES user_tickets(id) ON DELETE CASCADE,
            event_name TEXT,
            is_read BOOLEAN DEFAULT false,
            created_at TIMESTAMPTZ DEFAULT NOW()
        );
        RAISE NOTICE 'Created notifications table';
    END IF;
END
$$;

-- Create indexes for notifications if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_indexes WHERE indexname = 'idx_notifications_user_id') THEN
        CREATE INDEX idx_notifications_user_id ON notifications(user_id);
    END IF;

    IF NOT EXISTS (SELECT FROM pg_indexes WHERE indexname = 'idx_notifications_unread') THEN
        CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;
    END IF;

    IF NOT EXISTS (SELECT FROM pg_indexes WHERE indexname = 'idx_notifications_created_at') THEN
        CREATE INDEX idx_notifications_created_at ON notifications(created_at DESC);
    END IF;
END
$$;

-- Enable RLS on notifications if not already enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can create notifications" ON notifications;
CREATE POLICY "System can create notifications" ON notifications
    FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
CREATE POLICY "Users can delete own notifications" ON notifications
    FOR DELETE USING (auth.uid() = user_id);

-- Create or replace the notification trigger function
CREATE OR REPLACE FUNCTION notify_event_alert_users()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new ticket is inserted (status='active'), check if any users are watching this event
    IF (NEW.status = 'active') THEN
        INSERT INTO notifications (
            user_id,
            notification_type,
            title,
            message,
            ticket_id,
            event_name,
            created_at
        )
        SELECT
            ea.user_id,
            'new_listing',
            'New Ticket Available!',
            'A new ticket for ' || NEW.event_name || ' has been listed.',
            NEW.id,
            NEW.event_name,
            NOW()
        FROM event_alerts ea
        WHERE ea.event_name = NEW.event_name
            AND ea.is_active = true
            AND (ea.ticket_source IS NULL OR ea.ticket_source = NEW.ticket_source)
            AND (ea.user_id::text != NEW.user_id::text) -- Don't notify user of their own listing
            -- Only notify if not notified in last 5 minutes to prevent spam
            AND (ea.last_notified_at IS NULL OR ea.last_notified_at < NOW() - INTERVAL '5 minutes');

        -- Update last_notified_at timestamp
        UPDATE event_alerts
        SET last_notified_at = NOW()
        WHERE event_name = NEW.event_name
            AND is_active = true
            AND (ticket_source IS NULL OR ticket_source = NEW.ticket_source)
            AND (user_id::text != NEW.user_id::text)
            AND (last_notified_at IS NULL OR last_notified_at < NOW() - INTERVAL '5 minutes');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS trigger_notify_event_alert_users ON user_tickets;
CREATE TRIGGER trigger_notify_event_alert_users
    AFTER INSERT ON user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION notify_event_alert_users();

-- Add comments for documentation
COMMENT ON TABLE event_alerts IS 'Stores user event watch subscriptions for new ticket notifications';
COMMENT ON TABLE notifications IS 'Stores in-app notifications for users';
COMMENT ON COLUMN event_alerts.last_notified_at IS 'Timestamp of last notification sent to prevent spam';
COMMENT ON COLUMN notifications.notification_type IS 'Type of notification: new_listing, offer_accepted, etc.';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ Event alerts migration completed successfully!';
    RAISE NOTICE 'Created tables: event_alerts, notifications';
    RAISE NOTICE 'Created trigger: trigger_notify_event_alert_users';
END
$$;
