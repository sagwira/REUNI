// Supabase Edge Function: create-stripe-account
// Purpose: Create Stripe Connect Express account for sellers
// Endpoint: POST /functions/v1/create-stripe-account

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
  console.log('📍 Function entry point reached');
  console.log('📍 Request method:', req.method);
  console.log('📍 Request URL:', req.url);

  // CORS headers
  if (req.method === 'OPTIONS') {
    console.log('📍 Handling OPTIONS request (CORS preflight)');
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    console.log('🔵 create-stripe-account function called');
    console.log('🔵 Headers received:', Object.fromEntries(req.headers.entries()));
    console.log('📋 Environment check:');
    console.log('   - SUPABASE_URL:', !!supabaseUrl);
    console.log('   - SUPABASE_SERVICE_ROLE_KEY:', !!supabaseServiceKey);
    console.log('   - STRIPE_SECRET_KEY:', !!Deno.env.get('STRIPE_SECRET_KEY'));

    // Get authorization header
    const authHeader = req.headers.get('Authorization');
    console.log('🔑 Auth header present:', !!authHeader);

    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    // Extract JWT token and manually verify (same pattern as create-payment-intent)
    const token = authHeader.replace('Bearer ', '');
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Invalid token format');
    }

    const payload = JSON.parse(atob(parts[1]));
    console.log('👤 Token payload - sub:', payload.sub);
    console.log('👤 Token payload - email:', payload.email);

    // Check if token is expired
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp && payload.exp < now) {
      throw new Error('Token expired');
    }

    // Verify issuer
    const expectedIssuer = `${supabaseUrl}/auth/v1`;
    if (payload.iss !== expectedIssuer) {
      throw new Error('Invalid token issuer');
    }

    // Get user from payload
    const user = {
      id: payload.sub,
      email: payload.email,
      role: payload.role
    };

    console.log('✅ User authenticated:', user.id, user.email);

    // Get request body with pre-filled user data
    const { email, phone, fullName, dateOfBirth, city, return_url, refresh_url } = await req.json();
    console.log('📧 Email from request:', email);
    console.log('📱 Phone from request:', phone);
    console.log('👤 Full name from request:', fullName);
    console.log('🎂 DOB from request:', dateOfBirth);
    console.log('🏙️ City from request:', city);
    console.log('🔗 Return URL from request:', return_url);
    console.log('🔗 Refresh URL from request:', refresh_url);

    // Stripe requires HTTPS URLs for return/refresh, not deep links
    // Use example.com as a placeholder - user will manually close Safari
    const returnUrl = return_url || 'https://example.com';
    const refreshUrl = refresh_url || 'https://example.com';

    console.log('🔗 Using Return URL:', returnUrl);
    console.log('🔗 Using Refresh URL:', refreshUrl);

    // Create service supabase client for database operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Check if user already has a Stripe account
    const { data: existingAccounts } = await supabase
      .from('stripe_connected_accounts')
      .select('stripe_account_id, onboarding_completed')
      .eq('user_id', user.id);

    const existingAccount = existingAccounts?.[0] || null;

    let stripeAccountId: string;

    if (existingAccount) {
      // Account already exists
      stripeAccountId = existingAccount.stripe_account_id;

      // If onboarding already completed, return existing account
      if (existingAccount.onboarding_completed) {
        return new Response(
          JSON.stringify({
            success: true,
            accountId: stripeAccountId,
            alreadyOnboarded: true,
            message: 'Account already set up',
          }),
          {
            headers: {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*',
            },
          }
        );
      }
    } else {
      // Parse full name into first and last (split on first space)
      const nameParts = fullName ? fullName.split(' ') : [];
      const firstName = nameParts[0] || '';
      const lastName = nameParts.slice(1).join(' ') || '';

      // Parse date of birth (format: YYYY-MM-DD)
      let dob = {};
      if (dateOfBirth) {
        const dobParts = dateOfBirth.split('-');
        if (dobParts.length === 3) {
          dob = {
            day: parseInt(dobParts[2]),
            month: parseInt(dobParts[1]),
            year: parseInt(dobParts[0]),
          };
        }
      }

      console.log('👤 Parsed name:', { firstName, lastName });
      console.log('🎂 Parsed DOB:', dob);

      // Create new Stripe Connect Express account with pre-filled data
      const accountData: any = {
        type: 'express',
        country: 'GB',
        email: email || user?.email || 'test@example.com',
        capabilities: {
          transfers: { requested: true },
        },
        business_type: 'individual', // Individual person, not a business
        // Explicitly set business profile to indicate this is NOT a business
        business_profile: {
          mcc: '5815', // Digital Goods - Software (appropriate for tickets)
          product_description: 'Personal event ticket resale',
          url: 'https://reuni.app',
        },
        metadata: {
          user_id: user?.id.toString() || 'test-user',
          platform: 'REUNI',
          seller_type: 'individual_student',
        },
      };

      // Add individual information (pre-filled from verified REUNI profile)
      // This is REQUIRED for individual accounts to avoid business questions
      accountData.individual = {
        email: email || user?.email || 'test@example.com',
      };

      if (firstName) {
        accountData.individual.first_name = firstName;
      }
      if (lastName) {
        accountData.individual.last_name = lastName;
      }
      if (phone) {
        accountData.individual.phone = phone;
      }
      if (Object.keys(dob).length === 3) {
        accountData.individual.dob = dob;
      }
      if (city) {
        accountData.individual.address = {
          city: city,
          country: 'GB',
        };
      }

      console.log('✅ Creating INDIVIDUAL account (not business) with pre-filled REUNI data');
      console.log('📋 Individual data:', JSON.stringify(accountData.individual, null, 2));

      const account = await stripe.accounts.create(accountData);

      stripeAccountId = account.id;

      // Store in database (only if we have a user)
      if (user) {
        console.log('💾 Storing account in database...');
        console.log('   user_id (original):', user.id);
        console.log('   user_id (type):', typeof user.id);
        console.log('   user_id (toString):', user.id.toString());
        console.log('   user_id (toLowerCase):', user.id.toString().toLowerCase());
        console.log('   stripe_account_id:', account.id);

        // Keep UUID as-is (don't normalize case - database stores it as-is)
        const userId = user.id;

        console.log('🔄 Attempting simple database insert (RLS disabled for testing):', {
          user_id: userId,
          stripe_account_id: account.id,
          email: email || user.email,
        });

        // Simple insert with RLS disabled
        const { data: insertedData, error: insertError } = await supabase
          .from('stripe_connected_accounts')
          .insert({
            user_id: userId,
            stripe_account_id: account.id,
            email: email || user.email,
            country: 'GB',
            default_currency: 'gbp',
            onboarding_completed: false,
            charges_enabled: false,
            payouts_enabled: false,
            details_submitted: false,
          })
          .select();

        console.log('📋 Insert result - data:', insertedData);
        console.log('📋 Insert result - error:', insertError);

        // Check if insert "succeeded" but returned no data (RLS silent drop)
        if (!insertError && (!insertedData || insertedData.length === 0)) {
          console.error('❌ Insert succeeded but returned no data - likely RLS policy blocking');

          // Delete the Stripe account since database insert was silently blocked
          console.log('🗑️ Rolling back - deleting Stripe account...');
          try {
            await stripe.accounts.del(account.id);
            console.log('✅ Stripe account deleted');
          } catch (deleteError) {
            console.error('❌ Failed to delete Stripe account:', deleteError);
          }

          throw new Error('Database insert was blocked by RLS policy. Please check stripe_connected_accounts table policies.');
        }

        if (insertError) {
          console.error('❌ Database insert failed:', JSON.stringify(insertError, null, 2));

          // Delete the Stripe account since we couldn't save it to database
          console.log('🗑️ Rolling back - deleting Stripe account...');
          try {
            await stripe.accounts.del(account.id);
            console.log('✅ Stripe account deleted');
          } catch (deleteError) {
            console.error('❌ Failed to delete Stripe account:', deleteError);
          }

          throw new Error(`Database error: ${insertError.message}. Stripe account rolled back.`);
        }

        console.log('✅ Account saved to database:', insertedData);
      } else {
        console.warn('⚠️ Skipping database insert - no user');
      }
    }

    // Create account link for onboarding
    const accountLink = await stripe.accountLinks.create({
      account: stripeAccountId,
      refresh_url: refreshUrl,
      return_url: returnUrl,
      type: 'account_onboarding',
    });

    return new Response(
      JSON.stringify({
        success: true,
        accountId: stripeAccountId,
        onboardingUrl: accountLink.url,
        expiresAt: accountLink.expires_at,
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
    console.error('💥 Error creating Stripe account:', error);

    // Log more details
    console.error('📋 Error details:', {
      message: error.message,
      stack: error.stack,
      name: error.name,
      toString: error.toString(),
    });

    // Determine status code based on error type
    const isAuthError = error.message?.includes('Unauthorized') || error.message?.includes('authorization');
    const statusCode = isAuthError ? 401 : 400;

    console.error(`📤 Returning ${statusCode} error response`);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Unknown error occurred',
        errorType: error.name,
        details: error.toString(),
        stack: error.stack?.split('\n').slice(0, 5),
      }),
      {
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
        status: statusCode,
      }
    );
  }
});
