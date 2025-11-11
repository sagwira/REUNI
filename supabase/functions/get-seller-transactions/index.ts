// Supabase Edge Function: get-seller-transactions
// Purpose: Get seller's transaction history with pagination
// Endpoint: POST /functions/v1/get-seller-transactions

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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
    console.log('📋 get-seller-transactions called');

    // Get authenticated user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // Extract JWT token
    const token = authHeader.replace('Bearer ', '');
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Invalid token format');
    }

    const payload = JSON.parse(atob(parts[1]));
    const sellerId = payload.sub.toLowerCase();

    // Get pagination params
    const body = await req.json().catch(() => ({}));
    const page = parseInt(body.page || '1');
    const limit = parseInt(body.limit || '20');
    const offset = (page - 1) * limit;

    console.log(`👤 Fetching transactions for seller: ${sellerId}, page: ${page}, limit: ${limit}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Fetch transactions with ticket and buyer details
    const { data: transactions, error: txnError } = await supabase
      .from('transactions')
      .select(`
        id,
        ticket_id,
        buyer_id,
        seller_amount,
        platform_fee,
        buyer_total,
        ticket_price,
        status,
        escrow_status,
        escrow_hold_until,
        payment_completed_at,
        escrow_released_at,
        stripe_transfer_id
      `)
      .eq('seller_id', sellerId)
      .order('payment_completed_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (txnError) {
      console.error('❌ Error fetching transactions:', txnError);
      throw txnError;
    }

    console.log(`📦 Found ${transactions?.length || 0} transactions`);

    // Get ticket and buyer details for each transaction
    const enrichedTransactions = await Promise.all(
      (transactions || []).map(async (txn) => {
        // Fetch ticket details
        const { data: ticket } = await supabase
          .from('user_tickets')
          .select('event_name, event_date, event_location')
          .eq('id', txn.ticket_id)
          .single();

        // Fetch buyer profile
        const { data: buyer } = await supabase
          .from('profiles')
          .select('username, profile_picture_url')
          .eq('id', txn.buyer_id)
          .single();

        // Calculate status display
        let statusDisplay = '';
        let statusColor = '';

        if (txn.status === 'completed') {
          if (txn.escrow_status === 'held') {
            statusDisplay = 'Pending Escrow';
            statusColor = 'orange';
          } else if (txn.escrow_status === 'released') {
            if (txn.stripe_transfer_id) {
              statusDisplay = 'Paid Out';
              statusColor = 'green';
            } else {
              statusDisplay = 'Available';
              statusColor = 'blue';
            }
          } else if (txn.escrow_status === 'disputed') {
            statusDisplay = 'Disputed';
            statusColor = 'red';
          }
        } else if (txn.status === 'pending') {
          statusDisplay = 'Pending Payment';
          statusColor = 'gray';
        } else if (txn.status === 'refunded') {
          statusDisplay = 'Refunded';
          statusColor = 'red';
        }

        // Calculate payout date
        let payoutDate = null;
        if (txn.escrow_status === 'held' && txn.escrow_hold_until) {
          payoutDate = txn.escrow_hold_until;
        } else if (txn.escrow_released_at) {
          // Add 1-2 days for Stripe payout
          const releaseDate = new Date(txn.escrow_released_at);
          releaseDate.setDate(releaseDate.getDate() + 2);
          payoutDate = releaseDate.toISOString();
        }

        return {
          id: txn.id,
          eventName: ticket?.event_name || 'Unknown Event',
          eventDate: ticket?.event_date,
          eventLocation: ticket?.event_location,
          buyerUsername: buyer?.username || 'Unknown',
          buyerProfileUrl: buyer?.profile_picture_url,
          salePrice: parseFloat(txn.ticket_price || '0'),
          platformFee: parseFloat(txn.platform_fee || '0'),
          yourEarnings: parseFloat(txn.seller_amount || '0'),
          soldAt: txn.payment_completed_at,
          status: statusDisplay,
          statusColor: statusColor,
          payoutDate: payoutDate,
          escrowStatus: txn.escrow_status,
          transferId: txn.stripe_transfer_id
        };
      })
    );

    // Get total count for pagination
    const { count } = await supabase
      .from('transactions')
      .select('id', { count: 'exact', head: true })
      .eq('seller_id', sellerId);

    const response = {
      transactions: enrichedTransactions,
      total: count || 0,
      page,
      perPage: limit,
      hasMore: (count || 0) > (offset + limit)
    };

    console.log(`✅ Returning ${enrichedTransactions.length} transactions`);

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('❌ Error in get-seller-transactions:', error);
    return new Response(JSON.stringify({
      error: error.message || 'Failed to fetch transactions'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});
