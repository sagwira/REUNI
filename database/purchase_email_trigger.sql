-- Database trigger to automatically send purchase confirmation emails
-- when a transaction status changes to 'completed'

-- Enable pg_net for HTTP requests from database
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function to send purchase email via Edge Function
CREATE OR REPLACE FUNCTION send_purchase_email_on_completion()
RETURNS TRIGGER AS $$
DECLARE
  function_url TEXT;
  service_role_key TEXT;
BEGIN
  -- Only proceed if status changed to 'completed'
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN

    -- Get Supabase URL and service role key from environment
    -- NOTE: You'll need to set these in your Supabase dashboard
    -- Settings -> API -> Project URL and service_role key
    function_url := current_setting('app.supabase_url', true) || '/functions/v1/send-purchase-email';
    service_role_key := current_setting('app.service_role_key', true);

    -- Call the Edge Function asynchronously using pg_net
    PERFORM net.http_post(
      url := function_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || service_role_key
      ),
      body := jsonb_build_object(
        'transaction_id', NEW.id,
        'buyer_id', NEW.buyer_id,
        'seller_id', NEW.seller_id,
        'ticket_id', NEW.ticket_id
      )
    );

    RAISE NOTICE 'Purchase email queued for transaction: %', NEW.id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger on transactions table
DROP TRIGGER IF EXISTS trigger_send_purchase_email ON transactions;

CREATE TRIGGER trigger_send_purchase_email
  AFTER INSERT OR UPDATE ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION send_purchase_email_on_completion();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA net TO postgres, authenticated, service_role;

COMMENT ON FUNCTION send_purchase_email_on_completion() IS
  'Automatically sends purchase confirmation emails when a transaction is completed';

COMMENT ON TRIGGER trigger_send_purchase_email ON transactions IS
  'Triggers purchase email sending when transaction status becomes completed';
