-- Create issue_reports table for ticket dispute resolution
-- Run this in Supabase SQL Editor

-- Create issue_reports table
CREATE TABLE IF NOT EXISTS issue_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE, -- Nullable in case transaction not found
    ticket_id UUID NOT NULL REFERENCES user_tickets(id) ON DELETE CASCADE,
    buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    seller_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    issue_type TEXT NOT NULL, -- 'Ticket Already Scanned' or 'Ticket is Fake/Invalid'
    description TEXT,
    image_urls TEXT[], -- Array of image URLs from storage
    status TEXT NOT NULL DEFAULT 'pending', -- pending, under_review, approved, rejected, resolved
    admin_notes TEXT,
    resolution TEXT, -- refund_issued, seller_warning, case_closed, etc.
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_issue_reports_transaction_id ON issue_reports(transaction_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_ticket_id ON issue_reports(ticket_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_buyer_id ON issue_reports(buyer_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_seller_id ON issue_reports(seller_id);
CREATE INDEX IF NOT EXISTS idx_issue_reports_status ON issue_reports(status);
CREATE INDEX IF NOT EXISTS idx_issue_reports_created_at ON issue_reports(created_at DESC);

-- Enable Row Level Security
ALTER TABLE issue_reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view own issue reports" ON issue_reports;
DROP POLICY IF EXISTS "Users can create issue reports" ON issue_reports;
DROP POLICY IF EXISTS "Service role can manage all issue reports" ON issue_reports;

-- RLS Policies

-- Buyers can view their own reports
CREATE POLICY "Users can view own issue reports"
ON issue_reports
FOR SELECT
USING (
    auth.uid()::text = buyer_id::text
    OR auth.uid()::text = seller_id::text
);

-- Buyers can create issue reports for their purchases
CREATE POLICY "Users can create issue reports"
ON issue_reports
FOR INSERT
WITH CHECK (auth.uid()::text = buyer_id::text);

-- Service role (admin) can manage all reports
CREATE POLICY "Service role can manage all issue reports"
ON issue_reports
FOR ALL
USING (auth.jwt()->>'role' = 'service_role');

-- Grant permissions
GRANT SELECT, INSERT ON issue_reports TO authenticated;
GRANT ALL ON issue_reports TO service_role;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_issue_report_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updated_at
DROP TRIGGER IF EXISTS issue_reports_updated_at ON issue_reports;
CREATE TRIGGER issue_reports_updated_at
    BEFORE UPDATE ON issue_reports
    FOR EACH ROW
    EXECUTE FUNCTION update_issue_report_updated_at();

-- Create storage bucket for issue attachments
INSERT INTO storage.buckets (id, name, public)
VALUES ('issue-reports', 'issue-reports', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage policy for issue attachments
CREATE POLICY "Authenticated users can upload issue attachments"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'issue-reports');

CREATE POLICY "Public read access for issue attachments"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'issue-reports');

-- Comments
COMMENT ON TABLE issue_reports IS 'Ticket issue reports and disputes';
COMMENT ON COLUMN issue_reports.issue_type IS 'Type of issue: Ticket Already Scanned, Ticket is Fake/Invalid';
COMMENT ON COLUMN issue_reports.status IS 'Current status: pending, under_review, approved, rejected, resolved';
COMMENT ON COLUMN issue_reports.image_urls IS 'Array of evidence image URLs from Supabase Storage';
COMMENT ON COLUMN issue_reports.admin_notes IS 'Internal notes from support team';
COMMENT ON COLUMN issue_reports.resolution IS 'Final resolution action taken';

-- Sample query to view pending reports (for admin dashboard)
-- SELECT
--     ir.*,
--     bp.username as buyer_username,
--     bp.email as buyer_email,
--     sp.username as seller_username,
--     sp.email as seller_email,
--     ut.event_name,
--     t.buyer_total as amount_paid
-- FROM issue_reports ir
-- JOIN profiles bp ON ir.buyer_id = bp.id
-- JOIN profiles sp ON ir.seller_id = sp.id
-- JOIN user_tickets ut ON ir.ticket_id = ut.id
-- JOIN transactions t ON ir.transaction_id = t.id
-- WHERE ir.status = 'pending'
-- ORDER BY ir.created_at DESC;
