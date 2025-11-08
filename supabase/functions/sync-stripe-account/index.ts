// Supabase Edge Function: sync-stripe-account
// Purpose: Sync Stripe account status from Stripe API to database
// Endpoint: POST /functions/v1/sync-stripe-account

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
  console.log('📍 sync-stripe-account function called');

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
    const authHeader = req.headers.get('Authorization');
    console.log('🔑 Auth header present:', !!authHeader);

    if (!authHeader) {
      console.error('❌ No Authorization header provided');
      return new Response(
        JSON.stringify({ success: false, error: 'No authorization header' }),
        {
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          status: 401,
        }
      );
    }

    // Create Supabase client with service role AND auth header (same pattern as create-stripe-account)
    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    });

    // Get current user - NO TOKEN PARAMETER
    const { data: { user }, error: userError } = await supabase.auth.getUser();

    console.log('👤 User from auth:', user?.id, user?.email);
    if (userError) {
      console.error('❌ User error:', JSON.stringify(userError, null, 2));
    }

    if (!user) {
      console.warn('⚠️ No user authenticated after getUser call');
      return new Response(
        JSON.stringify({ success: false, error: 'User not authenticated' }),
        {
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          status: 401,
        }
      );
    }

    console.log('✅ User authenticated:', user.id, user.email);

    // Get Stripe account from database
    const { data: accounts, error: dbError } = await supabase
      .from('stripe_connected_accounts')
      .select('stripe_account_id')
      .eq('user_id', user.id.toString())
      .limit(1);

    if (dbError || !accounts || accounts.length === 0) {
      console.log('❌ No Stripe account found in database');
      return new Response(
        JSON.stringify({
          success: false,
          error: 'No Stripe account found',
          needsOnboarding: true
        }),
        {
          headers: {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
          },
          status: 404,
        }
      );
    }

    const stripeAccountId = accounts[0].stripe_account_id;
    console.log('🔍 Fetching Stripe account:', stripeAccountId);

    // Fetch account from Stripe API
    const account = await stripe.accounts.retrieve(stripeAccountId);

    console.log('📊 Stripe account status:', {
      charges_enabled: account.charges_enabled,
      payouts_enabled: account.payouts_enabled,
      details_submitted: account.details_submitted,
    });

    // Update database with current status
    const { error: updateError } = await supabase
      .from('stripe_connected_accounts')
      .update({
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        details_submitted: account.details_submitted,
        onboarding_completed: account.details_submitted && account.charges_enabled,
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', user.id.toString());

    if (updateError) {
      console.error('❌ Failed to update database:', updateError);
      throw updateError;
    }

    console.log('✅ Database updated successfully');

    // Determine status
    let status = 'pending';
    if (account.charges_enabled && account.payouts_enabled) {
      status = 'active';
    } else if (!account.details_submitted) {
      status = 'not_created';
    }

    return new Response(
      JSON.stringify({
        success: true,
        accountId: stripeAccountId,
        status: status,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        details_submitted: account.details_submitted,
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
    console.error('💥 Error syncing Stripe account:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error occurred',
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: 500,
      }
    );
  }
});
