// Supabase Edge Function: file-dispute
// Purpose: Buyer files a dispute for fake/invalid ticket
// Endpoint: POST /functions/v1/file-dispute

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

serve(async (req) => {
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    // Get user from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const token = authHeader.replace('Bearer ', '');
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Invalid token format');
    }

    const payload = JSON.parse(atob(parts[1]));
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      throw new Error('Token expired');
    }

    const user = {
      id: payload.sub,
      email: payload.email,
    };

    console.log('👤 Filing dispute for user:', user.id);

    // Get request body
    const { transaction_id, ticket_id, dispute_type, dispute_reason, evidence_urls } = await req.json();

    // Validate inputs
    if (!transaction_id || !ticket_id) {
      throw new Error('Missing required fields: transaction_id and ticket_id');
    }

    if (!dispute_type || !dispute_reason) {
      throw new Error('Missing required fields: dispute_type and dispute_reason');
    }

    // Validate dispute type
    const validDisputeTypes = [
      'fake_ticket',
      'reused_ticket',
      'invalid_barcode',
      'ticket_rejected_at_venue',
      'seller_unresponsive',
      'wrong_ticket',
      'cancelled_event',
      'other',
    ];

    if (!validDisputeTypes.includes(dispute_type)) {
      throw new Error(`Invalid dispute_type. Must be one of: ${validDisputeTypes.join(', ')}`);
    }

    console.log(`📝 Dispute details:`);
    console.log(`   Transaction: ${transaction_id}`);
    console.log(`   Ticket: ${ticket_id}`);
    console.log(`   Type: ${dispute_type}`);
    console.log(`   Reason: ${dispute_reason}`);

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Verify transaction belongs to this user (buyer)
    const { data: transaction, error: txnError } = await supabase
      .from('transactions')
      .select('buyer_id, seller_id, status, escrow_status')
      .eq('id', transaction_id)
      .single();

    if (txnError || !transaction) {
      throw new Error('Transaction not found');
    }

    if (transaction.buyer_id !== user.id) {
      throw new Error('You can only dispute your own purchases');
    }

    if (transaction.status !== 'completed') {
      throw new Error('Cannot dispute a transaction that is not completed');
    }

    if (transaction.escrow_status === 'released') {
      throw new Error('Cannot dispute - funds have already been released to seller');
    }

    if (transaction.escrow_status === 'refunded') {
      throw new Error('Transaction already refunded');
    }

    // Check if dispute already exists
    const { data: existingDispute } = await supabase
      .from('ticket_disputes')
      .select('id, status')
      .eq('transaction_id', transaction_id)
      .eq('status', 'open')
      .maybeSingle();

    if (existingDispute) {
      throw new Error('A dispute is already open for this transaction');
    }

    // File dispute using database function
    const { data: disputeId, error: disputeError } = await supabase.rpc(
      'file_ticket_dispute',
      {
        p_transaction_id: transaction_id,
        p_ticket_id: ticket_id,
        p_buyer_id: user.id,
        p_dispute_type: dispute_type,
        p_dispute_reason: dispute_reason,
        p_evidence_urls: evidence_urls || [],
      }
    );

    if (disputeError) {
      console.error('❌ Error filing dispute:', disputeError);
      throw new Error(`Failed to file dispute: ${disputeError.message}`);
    }

    console.log(`✅ Dispute filed successfully: ${disputeId}`);

    // Send notification to seller
    await supabase.from('notifications').insert({
      user_id: transaction.seller_id,
      type: 'dispute_filed',
      title: 'Dispute Filed ⚠️',
      message: `A buyer has filed a dispute for one of your tickets. Reason: ${dispute_type.replace(/_/g, ' ')}`,
      is_read: false,
    });

    // Send notification to admin (you)
    // TODO: Get admin user ID from environment variable
    const adminUserId = Deno.env.get('ADMIN_USER_ID');
    if (adminUserId) {
      await supabase.from('notifications').insert({
        user_id: adminUserId,
        type: 'dispute_filed',
        title: 'New Dispute Requires Review',
        message: `Dispute filed for transaction ${transaction_id}: ${dispute_type}`,
        is_read: false,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        dispute_id: disputeId,
        message: 'Dispute filed successfully. Our team will review your case within 24 hours.',
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: 201,
      }
    );
  } catch (error) {
    console.error('❌ Error filing dispute:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: 400,
      }
    );
  }
});
