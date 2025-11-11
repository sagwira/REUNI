-- =====================================================
-- REUNI Admin Dashboard Database Schema
-- =====================================================
-- This schema adds admin functionality for managing
-- the REUNI app: user monitoring, error tracking,
-- activity logs, and communication logs.
-- =====================================================

-- =====================================================
-- 1. ADMIN USERS TABLE
-- =====================================================
-- Stores admin accounts with role-based permissions

CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'worker')),
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES admin_users(id),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_admin_users_email ON admin_users(email);
CREATE INDEX idx_admin_users_role ON admin_users(role);

-- =====================================================
-- 2. ERROR LOGS TABLE
-- =====================================================
-- Comprehensive error tracking for all user actions

CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    error_type TEXT NOT NULL,
    error_code TEXT,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    context JSONB,
    severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
    is_resolved BOOLEAN DEFAULT false,
    resolved_by UUID REFERENCES admin_users(id),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    user_agent TEXT,
    ip_address INET,
    app_version TEXT,
    os_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for filtering and searching
CREATE INDEX idx_error_logs_user_id ON error_logs(user_id);
CREATE INDEX idx_error_logs_error_type ON error_logs(error_type);
CREATE INDEX idx_error_logs_severity ON error_logs(severity);
CREATE INDEX idx_error_logs_is_resolved ON error_logs(is_resolved);
CREATE INDEX idx_error_logs_created_at ON error_logs(created_at DESC);

-- Error types enum for reference:
COMMENT ON COLUMN error_logs.error_type IS
'Types: payment_declined, stripe_connection_failed, supabase_connection_failed,
authentication_failed, upload_failed, invalid_data, client_crash, api_error';

-- =====================================================
-- 3. ACTIVITY LOGS TABLE
-- =====================================================
-- Track all user inputs and actions

CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL,
    action_category TEXT NOT NULL,
    description TEXT,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX idx_activity_logs_action_type ON activity_logs(action_type);
CREATE INDEX idx_activity_logs_action_category ON activity_logs(action_category);
CREATE INDEX idx_activity_logs_created_at ON activity_logs(created_at DESC);

-- Action categories for reference:
COMMENT ON COLUMN activity_logs.action_category IS
'Categories: ticket_management, purchases, profile, authentication,
search, support, payment_method, reviews, uploads';

-- Action types for reference:
COMMENT ON COLUMN activity_logs.action_type IS
'Types: ticket_upload, ticket_purchase, ticket_list, ticket_delist,
profile_edit, login, logout, password_reset, search_query,
payment_method_add, payment_method_remove, review_submit,
image_upload, report_submit';

-- =====================================================
-- 4. COMMUNICATION LOGS TABLE
-- =====================================================
-- Log all outbound communications to users

CREATE TABLE IF NOT EXISTS communication_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    communication_type TEXT NOT NULL CHECK (
        communication_type IN ('email', 'push_notification', 'sms', 'in_app_notification')
    ),
    channel TEXT NOT NULL,
    recipient_email TEXT,
    recipient_phone TEXT,
    subject TEXT,
    body_preview TEXT,
    full_body TEXT,
    template_id TEXT,
    template_name TEXT,
    status TEXT CHECK (status IN ('queued', 'sent', 'delivered', 'failed', 'bounced')) DEFAULT 'queued',
    provider TEXT,
    provider_message_id TEXT,
    error_message TEXT,
    metadata JSONB,
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_communication_logs_user_id ON communication_logs(user_id);
CREATE INDEX idx_communication_logs_type ON communication_logs(communication_type);
CREATE INDEX idx_communication_logs_status ON communication_logs(status);
CREATE INDEX idx_communication_logs_created_at ON communication_logs(created_at DESC);
CREATE INDEX idx_communication_logs_template ON communication_logs(template_name);

-- =====================================================
-- 5. ADMIN ACTIONS TABLE
-- =====================================================
-- Audit trail for all admin actions

CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    admin_email TEXT NOT NULL,
    action_type TEXT NOT NULL,
    target_type TEXT NOT NULL,
    target_id UUID,
    description TEXT NOT NULL,
    previous_state JSONB,
    new_state JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_admin_actions_admin_user_id ON admin_actions(admin_user_id);
CREATE INDEX idx_admin_actions_action_type ON admin_actions(action_type);
CREATE INDEX idx_admin_actions_target_type ON admin_actions(target_type);
CREATE INDEX idx_admin_actions_target_id ON admin_actions(target_id);
CREATE INDEX idx_admin_actions_created_at ON admin_actions(created_at DESC);

-- Action types for reference:
COMMENT ON COLUMN admin_actions.action_type IS
'Types: user_restrict, user_unrestrict, user_suspend, user_delete,
report_resolve, report_reject, error_acknowledge,
refund_approve, payout_approve, account_delete,
config_change, admin_user_create, admin_user_delete';

-- =====================================================
-- 6. SYSTEM HEALTH TABLE
-- =====================================================
-- Track system-wide health metrics

CREATE TABLE IF NOT EXISTS system_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL,
    metric_value DECIMAL,
    metric_unit TEXT,
    status TEXT CHECK (status IN ('healthy', 'degraded', 'critical')) DEFAULT 'healthy',
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_system_health_metric_name ON system_health(metric_name);
CREATE INDEX idx_system_health_created_at ON system_health(created_at DESC);

-- Metrics for reference:
COMMENT ON COLUMN system_health.metric_name IS
'Metrics: supabase_connection, stripe_api_health, database_response_time,
edge_function_response_time, active_users, error_rate,
webhook_delivery_rate, email_delivery_rate';

-- =====================================================
-- 7. ADMIN NOTES TABLE
-- =====================================================
-- Internal notes about users, reports, issues

CREATE TABLE IF NOT EXISTS admin_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID REFERENCES admin_users(id) ON DELETE SET NULL,
    admin_email TEXT NOT NULL,
    note_type TEXT NOT NULL,
    related_type TEXT,
    related_id UUID,
    note_text TEXT NOT NULL,
    is_important BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_admin_notes_admin_user_id ON admin_notes(admin_user_id);
CREATE INDEX idx_admin_notes_related_type ON admin_notes(related_type);
CREATE INDEX idx_admin_notes_related_id ON admin_notes(related_id);
CREATE INDEX idx_admin_notes_created_at ON admin_notes(created_at DESC);

-- Note types for reference:
COMMENT ON COLUMN admin_notes.note_type IS
'Types: user_note, report_investigation, transaction_note,
error_investigation, general';

-- =====================================================
-- 8. AUTO-RESTRICTION RULES TABLE
-- =====================================================
-- Configurable rules for automatic account restrictions

CREATE TABLE IF NOT EXISTS auto_restriction_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_name TEXT UNIQUE NOT NULL,
    rule_description TEXT,
    trigger_condition TEXT NOT NULL,
    trigger_threshold INTEGER,
    trigger_timeframe_days INTEGER,
    restriction_type TEXT NOT NULL CHECK (
        restriction_type IN ('selling_disabled', 'full_suspension', 'warning')
    ),
    restriction_duration_days INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Example rules:
COMMENT ON TABLE auto_restriction_rules IS
'Example: 3+ fake_ticket reports in 30 days = selling_disabled for 60 days
Example: 5+ payment_declined errors in 7 days = warning
Example: 2+ account_restrictions in 90 days = full_suspension';

-- =====================================================
-- 9. RESTRICTION HISTORY TABLE
-- =====================================================
-- Complete history of all restrictions (links to account_restrictions)

CREATE TABLE IF NOT EXISTS restriction_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    restriction_id UUID REFERENCES account_restrictions(id),
    restriction_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    applied_by UUID REFERENCES admin_users(id),
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    removed_by UUID REFERENCES admin_users(id),
    removed_at TIMESTAMPTZ,
    removal_reason TEXT,
    duration_days INTEGER,
    was_auto_restricted BOOLEAN DEFAULT false,
    rule_id UUID REFERENCES auto_restriction_rules(id)
);

-- Indexes
CREATE INDEX idx_restriction_history_user_id ON restriction_history(user_id);
CREATE INDEX idx_restriction_history_applied_at ON restriction_history(applied_at DESC);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on admin tables
ALTER TABLE admin_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE error_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_health ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE auto_restriction_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE restriction_history ENABLE ROW LEVEL SECURITY;

-- Admin users can read their own record
CREATE POLICY admin_users_select_own ON admin_users
    FOR SELECT
    USING (auth.uid() = id OR auth.jwt()->>'role' = 'admin');

-- Only active admins can read admin tables
CREATE POLICY admin_read_error_logs ON error_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

CREATE POLICY admin_read_activity_logs ON activity_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

CREATE POLICY admin_read_communication_logs ON communication_logs
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

CREATE POLICY admin_read_admin_actions ON admin_actions
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

CREATE POLICY admin_read_system_health ON system_health
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE id = auth.uid()
            AND is_active = true
        )
    );

-- Only owners can create/delete admin users
CREATE POLICY admin_users_manage_owner_only ON admin_users
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM admin_users
            WHERE id = auth.uid()
            AND role = 'owner'
            AND is_active = true
        )
    );

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to log admin actions automatically
CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO admin_actions (
        admin_user_id,
        admin_email,
        action_type,
        target_type,
        target_id,
        description,
        previous_state,
        new_state
    )
    VALUES (
        auth.uid(),
        auth.jwt()->>'email',
        TG_ARGV[0], -- action_type passed as trigger argument
        TG_TABLE_NAME,
        NEW.id,
        TG_ARGV[1], -- description passed as trigger argument
        row_to_json(OLD),
        row_to_json(NEW)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check and apply auto-restriction rules
CREATE OR REPLACE FUNCTION check_auto_restriction_rules(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_rule RECORD;
    v_count INTEGER;
    v_restriction_id UUID;
BEGIN
    FOR v_rule IN
        SELECT * FROM auto_restriction_rules
        WHERE is_active = true
    LOOP
        -- Check if user meets trigger condition
        -- This is simplified - actual implementation would be more complex
        IF v_rule.trigger_condition = 'fake_ticket_reports' THEN
            SELECT COUNT(*) INTO v_count
            FROM ticket_reports
            WHERE buyer_id = p_user_id
            AND report_type = 'fake_ticket'
            AND created_at > NOW() - (v_rule.trigger_timeframe_days || ' days')::INTERVAL;

            IF v_count >= v_rule.trigger_threshold THEN
                -- Apply restriction
                INSERT INTO account_restrictions (
                    user_id,
                    restriction_type,
                    reason,
                    restricted_by,
                    notes,
                    expires_at
                )
                VALUES (
                    p_user_id,
                    v_rule.restriction_type,
                    'Auto-restricted: ' || v_rule.rule_name,
                    NULL, -- system-triggered
                    v_rule.rule_description,
                    NOW() + (v_rule.restriction_duration_days || ' days')::INTERVAL
                )
                RETURNING id INTO v_restriction_id;

                -- Log in restriction history
                INSERT INTO restriction_history (
                    user_id,
                    restriction_id,
                    restriction_type,
                    reason,
                    duration_days,
                    was_auto_restricted,
                    rule_id
                )
                VALUES (
                    p_user_id,
                    v_restriction_id,
                    v_rule.restriction_type,
                    'Auto-restricted: ' || v_rule.rule_name,
                    v_rule.restriction_duration_days,
                    true,
                    v_rule.rule_id
                );
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ANALYTICS VIEWS
-- =====================================================

-- User activity summary view
CREATE OR REPLACE VIEW admin_user_activity_summary AS
SELECT
    u.id as user_id,
    u.username,
    u.email,
    u.university,
    COUNT(DISTINCT al.id) as total_actions,
    COUNT(DISTINCT CASE WHEN al.created_at > NOW() - INTERVAL '24 hours' THEN al.id END) as actions_last_24h,
    COUNT(DISTINCT CASE WHEN al.created_at > NOW() - INTERVAL '7 days' THEN al.id END) as actions_last_7d,
    MAX(al.created_at) as last_activity_at
FROM users u
LEFT JOIN activity_logs al ON al.user_id = u.id
GROUP BY u.id, u.username, u.email, u.university;

-- Error summary by type
CREATE OR REPLACE VIEW admin_error_summary AS
SELECT
    error_type,
    severity,
    COUNT(*) as error_count,
    COUNT(DISTINCT user_id) as affected_users,
    COUNT(CASE WHEN is_resolved = false THEN 1 END) as unresolved_count,
    MAX(created_at) as most_recent_error
FROM error_logs
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY error_type, severity
ORDER BY error_count DESC;

-- Report resolution metrics
CREATE OR REPLACE VIEW admin_report_metrics AS
SELECT
    report_type,
    status,
    COUNT(*) as report_count,
    AVG(EXTRACT(EPOCH FROM (resolved_at - created_at))/3600) as avg_resolution_hours,
    COUNT(CASE WHEN status = 'resolved_buyer_favor' THEN 1 END) as buyer_favor_count,
    COUNT(CASE WHEN status = 'resolved_seller_favor' THEN 1 END) as seller_favor_count
FROM ticket_reports
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY report_type, status;

-- Daily transaction metrics
CREATE OR REPLACE VIEW admin_transaction_metrics AS
SELECT
    DATE(created_at) as transaction_date,
    COUNT(*) as total_transactions,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_count,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_count,
    SUM(CASE WHEN status = 'completed' THEN total_amount ELSE 0 END) as total_revenue,
    SUM(CASE WHEN status = 'completed' THEN platform_fee ELSE 0 END) as platform_revenue
FROM transactions
WHERE created_at > NOW() - INTERVAL '90 days'
GROUP BY DATE(created_at)
ORDER BY transaction_date DESC;

-- =====================================================
-- INITIAL DATA
-- =====================================================

-- Insert default auto-restriction rules
INSERT INTO auto_restriction_rules (
    rule_name,
    rule_description,
    trigger_condition,
    trigger_threshold,
    trigger_timeframe_days,
    restriction_type,
    restriction_duration_days,
    is_active
) VALUES
(
    'Multiple Fake Ticket Reports',
    'User receives 3+ fake ticket reports within 30 days',
    'fake_ticket_reports',
    3,
    30,
    'selling_disabled',
    60,
    true
),
(
    'Excessive Payment Failures',
    'User has 5+ payment failures within 7 days',
    'payment_failures',
    5,
    7,
    'warning',
    NULL,
    true
),
(
    'Repeated Restrictions',
    'User has been restricted 2+ times within 90 days',
    'restriction_count',
    2,
    90,
    'full_suspension',
    NULL,
    true
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Composite indexes for common queries
CREATE INDEX idx_error_logs_user_type_created ON error_logs(user_id, error_type, created_at DESC);
CREATE INDEX idx_activity_logs_user_category_created ON activity_logs(user_id, action_category, created_at DESC);
CREATE INDEX idx_communication_logs_user_type_status ON communication_logs(user_id, communication_type, status);

-- =====================================================
-- COMMENTS FOR DOCUMENTATION
-- =====================================================

COMMENT ON TABLE admin_users IS 'Admin dashboard users with role-based access control';
COMMENT ON TABLE error_logs IS 'Comprehensive error tracking for all user actions and system failures';
COMMENT ON TABLE activity_logs IS 'Audit trail of all user actions and inputs';
COMMENT ON TABLE communication_logs IS 'Log of all outbound communications (emails, notifications, SMS)';
COMMENT ON TABLE admin_actions IS 'Audit trail of all admin actions for accountability';
COMMENT ON TABLE system_health IS 'System-wide health and performance metrics';
COMMENT ON TABLE admin_notes IS 'Internal notes for admins about users, reports, and issues';
COMMENT ON TABLE auto_restriction_rules IS 'Configurable rules for automatic account restrictions';
COMMENT ON TABLE restriction_history IS 'Complete history of all account restrictions and removals';

-- =====================================================
-- COMPLETION
-- =====================================================

-- Verify tables created
DO $$
DECLARE
    table_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO table_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
    AND table_name IN (
        'admin_users', 'error_logs', 'activity_logs',
        'communication_logs', 'admin_actions', 'system_health',
        'admin_notes', 'auto_restriction_rules', 'restriction_history'
    );

    RAISE NOTICE '✅ Admin schema created successfully. Tables created: %', table_count;
END $$;
