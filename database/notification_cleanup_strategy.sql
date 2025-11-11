-- Notification Cleanup Strategy
-- Option C: Hybrid approach with tiered retention
--
-- Retention Rules:
-- 1. Read notifications: Delete after 7 days
-- 2. Unread notifications: Keep for 30 days, then delete
-- 3. All notifications: Hard delete after 60 days
-- 4. Related ticket sold/deleted: Delete immediately

-- Create cleanup function
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER := 0;
    read_deleted INTEGER := 0;
    old_deleted INTEGER := 0;
    orphan_deleted INTEGER := 0;
BEGIN
    -- 1. Delete read notifications older than 7 days
    DELETE FROM notifications
    WHERE is_read = true
      AND created_at < NOW() - INTERVAL '7 days';

    GET DIAGNOSTICS read_deleted = ROW_COUNT;
    deleted_count := deleted_count + read_deleted;
    RAISE NOTICE 'Deleted % read notifications older than 7 days', read_deleted;

    -- 2. Delete all notifications older than 60 days (regardless of read status)
    DELETE FROM notifications
    WHERE created_at < NOW() - INTERVAL '60 days';

    GET DIAGNOSTICS old_deleted = ROW_COUNT;
    deleted_count := deleted_count + old_deleted;
    RAISE NOTICE 'Deleted % notifications older than 60 days', old_deleted;

    -- 3. Delete notifications for tickets that no longer exist or are sold
    DELETE FROM notifications
    WHERE ticket_id IS NOT NULL
      AND ticket_id NOT IN (
          SELECT id FROM user_tickets WHERE status = 'active'
      );

    GET DIAGNOSTICS orphan_deleted = ROW_COUNT;
    deleted_count := deleted_count + orphan_deleted;
    RAISE NOTICE 'Deleted % notifications for sold/deleted tickets', orphan_deleted;

    -- 4. Optional: Delete unread notifications older than 30 days
    -- (Uncomment if you want stricter cleanup)
    -- DELETE FROM notifications
    -- WHERE is_read = false
    --   AND created_at < NOW() - INTERVAL '30 days';

    RAISE NOTICE 'Total deleted: % notifications', deleted_count;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-delete notifications when ticket is sold/deleted
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

-- Apply trigger to user_tickets table
DROP TRIGGER IF EXISTS trigger_cleanup_ticket_notifications ON user_tickets;
CREATE TRIGGER trigger_cleanup_ticket_notifications
    AFTER UPDATE ON user_tickets
    FOR EACH ROW
    EXECUTE FUNCTION cleanup_ticket_notifications();

-- Add index for faster cleanup queries (without NOW() - can't use in predicate)
CREATE INDEX IF NOT EXISTS idx_notifications_cleanup
    ON notifications(created_at, is_read);

-- Create a scheduled job using pg_cron (if available)
-- Note: pg_cron must be enabled in Supabase/PostgreSQL
-- Run cleanup daily at 3 AM UTC
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
COMMENT ON FUNCTION cleanup_old_notifications() IS 'Deletes old notifications based on tiered retention strategy: read (7d), all (60d), orphaned (immediate)';
COMMENT ON FUNCTION cleanup_ticket_notifications() IS 'Automatically deletes notifications when related ticket is sold or deleted';

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ Notification cleanup strategy implemented!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Retention Rules:';
    RAISE NOTICE '   • Read notifications: 7 days';
    RAISE NOTICE '   • Unread notifications: 60 days';
    RAISE NOTICE '   • All notifications: 60 days max';
    RAISE NOTICE '   • Sold/deleted tickets: immediate';
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
