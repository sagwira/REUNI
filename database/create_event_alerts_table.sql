-- Create event_alerts table for tracking user-watched events
-- Users can watch specific events and get notified when new tickets are listed

CREATE TABLE IF NOT EXISTS event_alerts (
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

-- Index for fast lookups by user
CREATE INDEX IF NOT EXISTS idx_event_alerts_user_id ON event_alerts(user_id);

-- Index for active alerts
CREATE INDEX IF NOT EXISTS idx_event_alerts_active ON event_alerts(is_active) WHERE is_active = true;

-- Index for event matching
CREATE INDEX IF NOT EXISTS idx_event_alerts_event_name ON event_alerts(event_name);

-- Enable RLS
ALTER TABLE event_alerts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own alerts
CREATE POLICY "Users can view own alerts" ON event_alerts
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: Users can create their own alerts
CREATE POLICY "Users can create own alerts" ON event_alerts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own alerts
CREATE POLICY "Users can update own alerts" ON event_alerts
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own alerts
CREATE POLICY "Users can delete own alerts" ON event_alerts
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to check for new ticket listings and notify users
CREATE OR REPLACE FUNCTION notify_event_alert_users()
RETURNS TRIGGER AS $$
BEGIN
    -- When a new ticket is inserted (status='active'), check if any users are watching this event
    -- This will be used to create notifications in the app
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
            AND (ea.user_id != NEW.user_id) -- Don't notify user of their own listing
            -- Only notify if not notified in last 5 minutes to prevent spam
            AND (ea.last_notified_at IS NULL OR ea.last_notified_at < NOW() - INTERVAL '5 minutes');

        -- Update last_notified_at timestamp
        UPDATE event_alerts
        SET last_notified_at = NOW()
        WHERE event_name = NEW.event_name
            AND is_active = true
            AND (ticket_source IS NULL OR ticket_source = NEW.ticket_source)
            AND (user_id != NEW.user_id)
            AND (last_notified_at IS NULL OR last_notified_at < NOW() - INTERVAL '5 minutes');
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run notification function when new tickets are inserted
DROP TRIGGER IF EXISTS trigger_notify_event_alert_users ON user_tickets;
CREATE TRIGGER trigger_notify_event_alert_users
    AFTER INSERT ON user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION notify_event_alert_users();

-- Create notifications table if it doesn't exist
CREATE TABLE IF NOT EXISTS notifications (
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

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- Enable RLS on notifications
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own notifications
CREATE POLICY "Users can view own notifications" ON notifications
    FOR SELECT USING (auth.uid() = user_id);

-- Policy: System can insert notifications (handled by trigger)
CREATE POLICY "System can create notifications" ON notifications
    FOR INSERT WITH CHECK (true);

-- Policy: Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications" ON notifications
    FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete own notifications" ON notifications
    FOR DELETE USING (auth.uid() = user_id);

COMMENT ON TABLE event_alerts IS 'Stores user event watch subscriptions for new ticket notifications';
COMMENT ON TABLE notifications IS 'Stores in-app notifications for users';
COMMENT ON COLUMN event_alerts.last_notified_at IS 'Timestamp of last notification sent to prevent spam';
COMMENT ON COLUMN notifications.notification_type IS 'Type of notification: new_listing, offer_accepted, etc.';
