// Supabase Edge Function: get-seller-payouts
// Purpose: Get seller's payout history from Stripe
// Endpoint: POST /functions/v1/get-seller-payouts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Stripe from "https://esm.sh/stripe@14.0.0?target=deno";

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

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
    console.log('💸 get-seller-payouts called');

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

    console.log('👤 Fetching payouts for seller:', sellerId);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Get seller's Stripe account
    const { data: sellerAccount, error: accountError } = await supabase
      .from('stripe_connected_accounts')
      .select('stripe_account_id, onboarding_completed')
      .eq('user_id', sellerId)
      .single();

    if (accountError || !sellerAccount) {
      console.log('⚠️ No Stripe account found for seller');
      return new Response(JSON.stringify({
        payouts: [],
        total: 0,
        hasStripeAccount: false,
        message: 'No Stripe account connected'
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    if (!sellerAccount.onboarding_completed) {
      return new Response(JSON.stringify({
        payouts: [],
        total: 0,
        hasStripeAccount: true,
        onboardingComplete: false,
        message: 'Stripe onboarding not completed'
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    const stripeAccountId = sellerAccount.stripe_account_id;

    console.log(`💰 Fetching payouts from Stripe for account: ${stripeAccountId}`);

    // Fetch payouts from Stripe
    // Note: For connected accounts, we need to specify the account
    const payouts = await stripe.payouts.list(
      {
        limit: 20, // Get last 20 payouts
      },
      {
        stripeAccount: stripeAccountId
      }
    );

    console.log(`📦 Found ${payouts.data.length} payouts from Stripe`);

    // Transform Stripe payout data
    const formattedPayouts = payouts.data.map((payout) => {
      // Status mapping
      let statusDisplay = '';
      let statusColor = '';

      switch (payout.status) {
        case 'paid':
          statusDisplay = 'Paid';
          statusColor = 'green';
          break;
        case 'pending':
          statusDisplay = 'Pending';
          statusColor = 'orange';
          break;
        case 'in_transit':
          statusDisplay = 'In Transit';
          statusColor = 'blue';
          break;
        case 'canceled':
          statusDisplay = 'Canceled';
          statusColor = 'gray';
          break;
        case 'failed':
          statusDisplay = 'Failed';
          statusColor = 'red';
          break;
        default:
          statusDisplay = payout.status;
          statusColor = 'gray';
      }

      // Bank account info (last 4 digits)
      const bankAccount = payout.destination ? `****${payout.destination.toString().slice(-4)}` : 'N/A';

      return {
        id: payout.id,
        amount: payout.amount / 100, // Convert from pence to pounds
        currency: payout.currency.toUpperCase(),
        status: statusDisplay,
        statusColor: statusColor,
        arrivalDate: payout.arrival_date ? new Date(payout.arrival_date * 1000).toISOString() : null,
        createdAt: new Date(payout.created * 1000).toISOString(),
        bankAccount: bankAccount,
        description: payout.description || 'Payout',
        failureMessage: payout.failure_message || null
      };
    });

    // Count transactions related to each payout (optional - more complex)
    // For now, we'll just return payout data without transaction count

    const response = {
      payouts: formattedPayouts,
      total: payouts.data.length,
      hasStripeAccount: true,
      onboardingComplete: true,
      hasMore: payouts.has_more
    };

    console.log(`✅ Returning ${formattedPayouts.length} payouts`);

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });

  } catch (error) {
    console.error('❌ Error in get-seller-payouts:', error);

    // Check if it's a Stripe API error
    if (error.type === 'StripePermissionError') {
      return new Response(JSON.stringify({
        error: 'Unable to access payout data. Please ensure your Stripe account is properly connected.',
        payouts: [],
        total: 0
      }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*'
        }
      });
    }

    return new Response(JSON.stringify({
      error: error.message || 'Failed to fetch payouts',
      payouts: [],
      total: 0
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
});
