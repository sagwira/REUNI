-- Notification Cleanup Strategy V2
-- Instagram-style approach with per-notification countdown
--
-- Retention Rules:
-- 1. Read notifications: Keep for 7 days AFTER read_at timestamp
-- 2. Unread notifications: Keep for 30 days from created_at
-- 3. All notifications auto-marked as read when page opens (like Instagram)

-- Add read_at timestamp column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM information_schema.columns
                  WHERE table_name = 'notifications' AND column_name = 'read_at') THEN
        ALTER TABLE notifications ADD COLUMN read_at TIMESTAMPTZ;
        RAISE NOTICE 'Added read_at column to notifications table';

        -- Backfill: Set read_at for existing read notifications to created_at
        UPDATE notifications
        SET read_at = created_at
        WHERE is_read = true AND read_at IS NULL;

        RAISE NOTICE 'Backfilled read_at for existing read notifications';
    ELSE
        RAISE NOTICE 'read_at column already exists';
    END IF;
END
$$;

-- Update cleanup function with new logic
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    read_deleted INTEGER := 0;
    unread_deleted INTEGER := 0;
    orphan_deleted INTEGER := 0;
BEGIN
    -- 1. Delete read notifications 7 days after they were read
    DELETE FROM notifications
    WHERE is_read = true
      AND read_at IS NOT NULL
      AND read_at < NOW() - INTERVAL '7 days';

    GET DIAGNOSTICS read_deleted = ROW_COUNT;
    deleted_count := deleted_count + read_deleted;
    RAISE NOTICE 'Deleted % read notifications (7+ days after being read)', read_deleted;

    -- 2. Delete unread notifications 30 days after creation
    DELETE FROM notifications
    WHERE is_read = false
      AND created_at < NOW() - INTERVAL '30 days';

    GET DIAGNOSTICS unread_deleted = ROW_COUNT;
    deleted_count := deleted_count + unread_deleted;
    RAISE NOTICE 'Deleted % unread notifications (30+ days old)', unread_deleted;

    -- 3. Delete notifications for tickets that no longer exist or are sold
    DELETE FROM notifications
    WHERE ticket_id IS NOT NULL
      AND ticket_id NOT IN (
          SELECT id FROM user_tickets WHERE status = 'active'
      );

    GET DIAGNOSTICS orphan_deleted = ROW_COUNT;
    deleted_count := deleted_count + orphan_deleted;
    RAISE NOTICE 'Deleted % notifications for sold/deleted tickets', orphan_deleted;

    -- 4. Safety: Delete any notification older than 60 days regardless of status
    DELETE FROM notifications
    WHERE created_at < NOW() - INTERVAL '60 days';

    RAISE NOTICE 'Total deleted: % notifications', deleted_count;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Keep the ticket cleanup trigger (same as before)
CREATE OR REPLACE FUNCTION cleanup_ticket_notifications()
RETURNS TRIGGER AS $$
BEGIN
    -- When a ticket is marked as sold, purchased, or deleted, remove related notifications
    IF (OLD.status = 'active' AND NEW.status IN ('sold', 'purchased', 'deleted')) THEN
        DELETE FROM notifications
        WHERE ticket_id = NEW.id;

        RAISE NOTICE 'Deleted notifications for ticket %', NEW.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to user_tickets table (drop and recreate to ensure latest version)
DROP TRIGGER IF EXISTS trigger_cleanup_ticket_notifications ON user_tickets;
CREATE TRIGGER trigger_cleanup_ticket_notifications
    AFTER UPDATE ON user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_ticket_notifications();

-- Add indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_notifications_read_at
    ON notifications(read_at)
    WHERE read_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_is_read_created
    ON notifications(is_read, created_at);

-- Schedule cleanup job with pg_cron (if available)
DO $$
BEGIN
    -- Check if pg_cron extension exists
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Remove existing job if it exists
        PERFORM cron.unschedule('cleanup-old-notifications');

        -- Schedule new job to run daily at 3 AM UTC
        PERFORM cron.schedule(
            'cleanup-old-notifications',
            '0 3 * * *',  -- Cron expression: daily at 3 AM
            'SELECT cleanup_old_notifications();'
        );

        RAISE NOTICE '✅ Scheduled daily cleanup job at 3 AM UTC';
    ELSE
        RAISE NOTICE '⚠️ pg_cron extension not available. Manual cleanup required.';
        RAISE NOTICE 'Run manually: SELECT cleanup_old_notifications();';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Could not schedule cleanup job: %', SQLERRM;
        RAISE NOTICE 'Run manually: SELECT cleanup_old_notifications();';
END;
$$;

-- Add comments
COMMENT ON COLUMN notifications.read_at IS 'Timestamp when notification was marked as read (starts 7-day deletion countdown)';
COMMENT ON FUNCTION cleanup_old_notifications() IS 'Deletes notifications: read (7d after read_at), unread (30d after created_at), orphaned (immediate)';
COMMENT ON FUNCTION cleanup_ticket_notifications() IS 'Automatically deletes notifications when related ticket is sold or deleted';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Notification cleanup strategy V2 implemented!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Retention Rules (Instagram-style):';
    RAISE NOTICE '   • Read notifications: 7 days after read_at';
    RAISE NOTICE '   • Unread notifications: 30 days after created_at';
    RAISE NOTICE '   • Sold/deleted tickets: immediate';
    RAISE NOTICE '   • Safety limit: 60 days max';
    RAISE NOTICE '';
    RAISE NOTICE '🎨 UX Changes:';
    RAISE NOTICE '   • All notifications auto-marked as read when page opens';
    RAISE NOTICE '   • Each notification has its own 7-day countdown';
    RAISE NOTICE '   • More visual UI like Instagram';
    RAISE NOTICE '';
    RAISE NOTICE '⚙️ Automatic Cleanup:';
    RAISE NOTICE '   • Daily at 3 AM UTC (if pg_cron enabled)';
    RAISE NOTICE '   • On ticket sale/deletion (trigger)';
    RAISE NOTICE '';
    RAISE NOTICE '🔧 Manual Cleanup:';
    RAISE NOTICE '   Run: SELECT cleanup_old_notifications();';
    RAISE NOTICE '';
END;
$$;

-- Test the cleanup function (optional - run to verify it works)
-- SELECT cleanup_old_notifications();
