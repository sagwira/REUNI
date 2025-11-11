// Supabase Edge Function: get-seller-earnings
// Purpose: Get seller's earnings summary and metrics
// Endpoint: POST /functions/v1/get-seller-earnings

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
    console.log('📊 get-seller-earnings called');

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
    const sellerId = payload.sub.toLowerCase(); // Normalize to lowercase

    console.log('👤 Fetching earnings for seller:', sellerId);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Fetch all transactions where user is seller
    const { data: transactions, error: txnError } = await supabase
      .from('transactions')
      .select('seller_amount, escrow_status, status, payment_completed_at, escrow_released_at')
      .eq('seller_id', sellerId)
      .eq('status', 'completed'); // Only completed payments

    if (txnError) {
      console.error('❌ Error fetching transactions:', txnError);
      throw txnError;
    }

    console.log(`📦 Found ${transactions?.length || 0} transactions`);

    // Calculate earnings
    let lifetimeEarnings = 0;
    let pendingEscrow = 0;
    let availableBalance = 0;
    let totalSales = 0;

    const now = new Date();

    if (transactions) {
      totalSales = transactions.length;

      for (const txn of transactions) {
        const sellerAmount = parseFloat(txn.seller_amount || '0');
        lifetimeEarnings += sellerAmount;

        if (txn.escrow_status === 'held') {
          // Funds still in escrow
          pendingEscrow += sellerAmount;
        } else if (txn.escrow_status === 'released') {
          // Funds released, available for payout
          availableBalance += sellerAmount;
        }
      }
    }

    // Get next payout info from Stripe connected account
    // For now, we'll calculate based on pending balance
    // In production, you'd query Stripe's balance API

    const hasStripeAccount = await checkStripeAccount(supabase, sellerId);

    // Calculate next payout date (assuming daily payouts - Friday if weekend)
    const nextPayoutDate = getNextPayoutDate();

    const response = {
      lifetimeEarnings: Math.round(lifetimeEarnings * 100) / 100,
      pendingEscrow: Math.round(pendingEscrow * 100) / 100,
      availableBalance: Math.round(availableBalance * 100) / 100,
      totalSales,
      nextPayoutDate: nextPayoutDate.toISOString().split('T')[0],
      nextPayoutAmount: Math.round(availableBalance * 100) / 100,
      hasStripeAccount,
      currency: 'GBP'
    };

    console.log('✅ Earnings calculated:', response);

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('❌ Error in get-seller-earnings:', error);
    return new Response(JSON.stringify({
      error: error.message || 'Failed to fetch earnings'
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});

async function checkStripeAccount(supabase: any, userId: string): Promise<boolean> {
  const { data, error } = await supabase
    .from('stripe_connected_accounts')
    .select('onboarding_completed, charges_enabled')
    .eq('user_id', userId)
    .single();

  if (error || !data) return false;
  return data.onboarding_completed && data.charges_enabled;
}

function getNextPayoutDate(): Date {
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);

  // Skip weekends - payout on next Monday
  const dayOfWeek = tomorrow.getDay();
  if (dayOfWeek === 0) { // Sunday
    tomorrow.setDate(tomorrow.getDate() + 1);
  } else if (dayOfWeek === 6) { // Saturday
    tomorrow.setDate(tomorrow.getDate() + 2);
  }

  return tomorrow;
}
