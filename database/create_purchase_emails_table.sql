-- Create table to track purchase receipt emails

CREATE TABLE IF NOT EXISTS purchase_emails (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id UUID REFERENCES transactions(id) NOT NULL,
  buyer_id TEXT NOT NULL,
  buyer_email TEXT NOT NULL,
  email_provider TEXT DEFAULT 'resend',
  email_status TEXT DEFAULT 'sent', -- sent, failed, delivered, bounced
  email_id TEXT, -- Provider's email ID for tracking
  sent_at TIMESTAMPTZ DEFAULT NOW(),
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_purchase_emails_transaction_id ON purchase_emails(transaction_id);
CREATE INDEX IF NOT EXISTS idx_purchase_emails_buyer_id ON purchase_emails(buyer_id);
CREATE INDEX IF NOT EXISTS idx_purchase_emails_status ON purchase_emails(email_status);

-- Comment
COMMENT ON TABLE purchase_emails IS 'Tracks purchase receipt emails sent to buyers';

SELECT '✅ purchase_emails table created successfully!' as status;
