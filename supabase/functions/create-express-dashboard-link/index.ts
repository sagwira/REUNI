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

    console.log('🔐 Creating Express Dashboard login link for user:', user.id);

    // Get request body
    const { account_id } = await req.json();

    if (!account_id) {
      throw new Error('Missing account_id');
    }

    console.log('📊 Generating login link for account:', account_id);

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

    console.log('✅ Account verified, creating login link...');

    // Create an Express Dashboard login link
    // These links are single-use and expire after a short time for security
    const loginLink = await stripe.accounts.createLoginLink(account_id);

    console.log('✅ Login link created successfully');
    console.log('🔗 URL:', loginLink.url);

    return new Response(
      JSON.stringify({
        loginUrl: loginLink.url,
        expiresAt: Math.floor(Date.now() / 1000) + 300, // Links expire after ~5 minutes
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      }
    );
  } catch (error) {
    console.error('❌ Error creating login link:', error);

    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to create login link',
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
