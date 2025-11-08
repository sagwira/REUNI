import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2024-11-20.acacia',
  httpClient: Stripe.createFetchHttpClient(),
});

const supabase = createClient(
  Deno.env.get('SUPABASE_URL') || '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '',
);

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: { 'Access-Control-Allow-Origin': '*' } });
  }

  try {
    // Get authenticated user from request
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );

    if (authError || !user) {
      throw new Error('Not authenticated');
    }

    console.log('🔄 Refreshing onboarding link for user:', user.id);

    // Get request body
    const body = await req.json();
    console.log('📥 Request body:', JSON.stringify(body));

    const { account_id, return_url, refresh_url } = body;

    if (!account_id) {
      console.error('❌ Missing account_id in request');
      throw new Error('Missing account_id');
    }

    console.log('📊 Refreshing link for account:', account_id);
    console.log('🔗 Return URL:', return_url);
    console.log('🔗 Refresh URL:', refresh_url);

    // Verify this account belongs to the authenticated user
    const { data: accountData, error: dbError } = await supabase
      .from('stripe_connected_accounts')
      .select('stripe_account_id')
      .eq('stripe_account_id', account_id)
      .eq('user_id', user.id.toString())
      .single();

    if (dbError || !accountData) {
      console.error('❌ Account verification failed:', dbError);
      throw new Error('Account not found or unauthorized');
    }

    console.log('✅ Account verified, creating new account link...');

    // Use example.com since Stripe requires HTTPS (not deep links)
    const finalReturnUrl = return_url || 'https://example.com';
    const finalRefreshUrl = refresh_url || 'https://example.com';

    // Create a new account link (onboarding/dashboard access)
    const accountLink = await stripe.accountLinks.create({
      account: account_id,
      refresh_url: finalRefreshUrl,
      return_url: finalReturnUrl,
      type: 'account_onboarding',
    });

    console.log('✅ Account link created successfully');
    console.log('🔗 URL:', accountLink.url);

    return new Response(
      JSON.stringify({
        onboardingUrl: accountLink.url,
        expiresAt: accountLink.expires_at,
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    console.error('❌ Error refreshing onboarding link:', error);

    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to refresh onboarding link',
      }),
      {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  }
});
