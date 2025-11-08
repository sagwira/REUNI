// Supabase Edge Function: resolve-dispute
// Purpose: Admin resolves a ticket dispute (refund, partial refund, or reject)
// Endpoint: POST /functions/v1/resolve-dispute

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import Stripe from "https://esm.sh/stripe@14.0.0?target=deno";

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

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
    const adminUser = {
      id: payload.sub,
      email: payload.email,
    };

    // TODO: Verify user is admin (check against admin table or role)
    console.log('👤 Admin resolving dispute:', adminUser.id);

    // Get request body
    const { dispute_id, resolution, resolution_reason } = await req.json();

    // Validate inputs
    if (!dispute_id || !resolution) {
      throw new Error('Missing required fields: dispute_id and resolution');
    }

    const validResolutions = ['refund_buyer_full', 'refund_buyer_partial', 'reject_dispute'];
    if (!validResolutions.includes(resolution)) {
      throw new Error(`Invalid resolution. Must be one of: ${validResolutions.join(', ')}`);
    }

    console.log(`⚖️ Resolving dispute: ${dispute_id}`);
    console.log(`   Resolution: ${resolution}`);
    console.log(`   Reason: ${resolution_reason || 'None provided'}`);

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get dispute details
    const { data: dispute, error: disputeError } = await supabase
      .from('ticket_disputes')
      .select('*, transactions(*)')
      .eq('id', dispute_id)
      .single();

    if (disputeError || !dispute) {
      throw new Error('Dispute not found');
    }

    if (dispute.status !== 'open' && dispute.status !== 'investigating') {
      throw new Error('Dispute has already been resolved');
    }

    const transaction = dispute.transactions;
    if (!transaction) {
      throw new Error('Associated transaction not found');
    }

    console.log(`💰 Transaction details:`);
    console.log(`   Buyer total: £${transaction.buyer_total}`);
    console.log(`   Seller amount: £${transaction.seller_amount}`);
    console.log(`   Platform fee: £${transaction.platform_fee}`);
    console.log(`   Payment Intent: ${transaction.stripe_payment_intent_id}`);

    let refundAmount = 0;
    let stripeRefundId = null;

    // Process refund via Stripe if needed
    if (resolution === 'refund_buyer_full' || resolution === 'refund_buyer_partial') {
      refundAmount = resolution === 'refund_buyer_full'
        ? parseFloat(transaction.buyer_total)
        : parseFloat(transaction.buyer_total) * 0.5;

      console.log(`💸 Refunding buyer: £${refundAmount}`);

      try {
        const refund = await stripe.refunds.create({
          payment_intent: transaction.stripe_payment_intent_id,
          amount: Math.round(refundAmount * 100), // Convert to pence
          reason: 'requested_by_customer',
          metadata: {
            dispute_id: dispute_id,
            resolution: resolution,
            admin_id: adminUser.id,
          },
        });

        stripeRefundId = refund.id;
        console.log(`   ✅ Stripe refund created: ${stripeRefundId}`);
      } catch (stripeError) {
        console.error('❌ Stripe refund failed:', stripeError);
        throw new Error(`Stripe refund failed: ${stripeError.message}`);
      }
    }

    // Resolve dispute using database function
    const { error: resolveError } = await supabase.rpc('resolve_dispute', {
      p_dispute_id: dispute_id,
      p_resolution: resolution,
      p_resolution_reason: resolution_reason || `Resolved by admin: ${adminUser.email}`,
      p_resolved_by: adminUser.id,
    });

    if (resolveError) {
      console.error('❌ Error resolving dispute:', resolveError);
      throw new Error(`Failed to resolve dispute: ${resolveError.message}`);
    }

    console.log(`✅ Dispute resolved successfully`);

    // Send notifications
    if (resolution === 'refund_buyer_full' || resolution === 'refund_buyer_partial') {
      // Notify buyer of refund
      await supabase.from('notifications').insert({
        user_id: transaction.buyer_id,
        type: 'dispute_resolved',
        title: 'Dispute Resolved - Refund Issued',
        message: `Your dispute has been resolved in your favor. £${refundAmount.toFixed(2)} has been refunded.`,
        is_read: false,
      });

      // Notify seller of refund
      await supabase.from('notifications').insert({
        user_id: transaction.seller_id,
        type: 'dispute_resolved',
        title: 'Dispute Resolved - Refund Issued',
        message: `A dispute was resolved against your ticket. The buyer has been refunded.`,
        is_read: false,
      });
    } else {
      // Dispute rejected - notify buyer
      await supabase.from('notifications').insert({
        user_id: transaction.buyer_id,
        type: 'dispute_resolved',
        title: 'Dispute Rejected',
        message: `Your dispute has been reviewed and rejected. ${resolution_reason || 'No additional information provided.'}`,
        is_read: false,
      });

      // Notify seller - dispute rejected
      await supabase.from('notifications').insert({
        user_id: transaction.seller_id,
        type: 'dispute_resolved',
        title: 'Dispute Resolved in Your Favor',
        message: `A dispute against your ticket has been rejected. Payment will be released as scheduled.`,
        is_read: false,
      });
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Dispute resolved: ${resolution}`,
        refund_amount: refundAmount > 0 ? refundAmount : null,
        refund_id: stripeRefundId,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: 200,
      }
    );
  } catch (error) {
    console.error('❌ Error resolving dispute:', error);
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
