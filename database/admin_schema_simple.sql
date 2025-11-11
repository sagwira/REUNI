-- =====================================================
-- REUNI Admin Dashboard Database Schema (Simplified)
-- =====================================================

-- 1. ADMIN USERS TABLE
CREATE TABLE IF NOT EXISTS admin_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('owner', 'worker')),
    is_active BOOLEAN DEFAULT true,
    last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_users_email ON admin_users(email);
CREATE INDEX IF NOT EXISTS idx_admin_users_role ON admin_users(role);

-- Add foreign key constraint after table exists
ALTER TABLE admin_users DROP CONSTRAINT IF EXISTS admin_users_created_by_fkey;
ALTER TABLE admin_users ADD CONSTRAINT admin_users_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES admin_users(id);

-- 2. ERROR LOGS TABLE
CREATE TABLE IF NOT EXISTS error_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    error_type TEXT NOT NULL,
    error_code TEXT,
    error_message TEXT NOT NULL,
    stack_trace TEXT,
    context JSONB,
    severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')) DEFAULT 'medium',
    is_resolved BOOLEAN DEFAULT false,
    resolved_by UUID,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    user_agent TEXT,
    ip_address INET,
    app_version TEXT,
    os_version TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_error_logs_user_id ON error_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_error_logs_error_type ON error_logs(error_type);
CREATE INDEX IF NOT EXISTS idx_error_logs_severity ON error_logs(severity);
CREATE INDEX IF NOT EXISTS idx_error_logs_is_resolved ON error_logs(is_resolved);
CREATE INDEX IF NOT EXISTS idx_error_logs_created_at ON error_logs(created_at DESC);

-- 3. ACTIVITY LOGS TABLE
CREATE TABLE IF NOT EXISTS activity_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    action_type TEXT NOT NULL,
    action_category TEXT NOT NULL,
    description TEXT,
    metadata JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_type ON activity_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_activity_logs_action_category ON activity_logs(action_category);
CREATE INDEX IF NOT EXISTS idx_activity_logs_created_at ON activity_logs(created_at DESC);

-- 4. COMMUNICATION LOGS TABLE
CREATE TABLE IF NOT EXISTS communication_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
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

CREATE INDEX IF NOT EXISTS idx_communication_logs_user_id ON communication_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_communication_logs_type ON communication_logs(communication_type);
CREATE INDEX IF NOT EXISTS idx_communication_logs_status ON communication_logs(status);
CREATE INDEX IF NOT EXISTS idx_communication_logs_created_at ON communication_logs(created_at DESC);

-- 5. ADMIN ACTIONS TABLE
CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID,
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

CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_user_id ON admin_actions(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_action_type ON admin_actions(action_type);
CREATE INDEX IF NOT EXISTS idx_admin_actions_target_type ON admin_actions(target_type);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at ON admin_actions(created_at DESC);

-- 6. SYSTEM HEALTH TABLE
CREATE TABLE IF NOT EXISTS system_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    metric_name TEXT NOT NULL,
    metric_value DECIMAL,
    metric_unit TEXT,
    status TEXT CHECK (status IN ('healthy', 'degraded', 'critical')) DEFAULT 'healthy',
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_health_metric_name ON system_health(metric_name);
CREATE INDEX IF NOT EXISTS idx_system_health_created_at ON system_health(created_at DESC);

-- 7. ADMIN NOTES TABLE
CREATE TABLE IF NOT EXISTS admin_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id UUID,
    admin_email TEXT NOT NULL,
    note_type TEXT NOT NULL,
    related_type TEXT,
    related_id UUID,
    note_text TEXT NOT NULL,
    is_important BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_notes_admin_user_id ON admin_notes(admin_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_notes_related_type ON admin_notes(related_type);
CREATE INDEX IF NOT EXISTS idx_admin_notes_related_id ON admin_notes(related_id);

-- 8. AUTO RESTRICTION RULES TABLE
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

-- 9. RESTRICTION HISTORY TABLE
CREATE TABLE IF NOT EXISTS restriction_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    restriction_id UUID,
    restriction_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    applied_by UUID,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    removed_by UUID,
    removed_at TIMESTAMPTZ,
    removal_reason TEXT,
    duration_days INTEGER,
    was_auto_restricted BOOLEAN DEFAULT false,
    rule_id UUID
);

CREATE INDEX IF NOT EXISTS idx_restriction_history_user_id ON restriction_history(user_id);
CREATE INDEX IF NOT EXISTS idx_restriction_history_applied_at ON restriction_history(applied_at DESC);

-- Insert default auto-restriction rules
INSERT INTO auto_restriction_rules (
    rule_name, rule_description, trigger_condition, trigger_threshold, 
    trigger_timeframe_days, restriction_type, restriction_duration_days, is_active
) VALUES
(
    'Multiple Fake Ticket Reports',
    'User receives 3+ fake ticket reports within 30 days',
    'fake_ticket_reports', 3, 30, 'selling_disabled', 60, true
),
(
    'Excessive Payment Failures',
    'User has 5+ payment failures within 7 days',
    'payment_failures', 5, 7, 'warning', NULL, true
),
(
    'Repeated Restrictions',
    'User has been restricted 2+ times within 90 days',
    'restriction_count', 2, 90, 'full_suspension', NULL, true
)
ON CONFLICT (rule_name) DO NOTHING;

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
