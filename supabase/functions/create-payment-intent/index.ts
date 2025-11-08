// Supabase Edge Function: create-payment-intent
// Purpose: Create Stripe payment intent for ticket purchase
// Endpoint: POST /functions/v1/create-payment-intent

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import Stripe from "https://esm.sh/stripe@14.0.0?target=deno";

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const platformFeePercentage = parseFloat(Deno.env.get('PLATFORM_FEE_PERCENTAGE') || '10');
const flatFee = parseFloat(Deno.env.get('FLAT_FEE') || '1.00'); // £1.00 flat booking fee

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
    console.log('🔑 Auth header present:', !!authHeader);
    console.log('🔑 Auth header preview:', authHeader?.substring(0, 20) + '...');

    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    // Extract JWT token
    const token = authHeader.replace('Bearer ', '');

    // Verify JWT and extract user ID
    const parts = token.split('.');
    if (parts.length !== 3) {
      throw new Error('Invalid token format');
    }

    const payload = JSON.parse(atob(parts[1]));
    console.log('👤 Token payload:', payload);

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

    console.log('👤 Authenticated user:', user.id, user.email);

    // Create service supabase client for database operations
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get request body
    const { ticket_id } = await req.json();

    if (!ticket_id) {
      throw new Error('Missing ticket_id');
    }

    // Fetch ticket details with seller's Stripe account (using direct stripe_account_id)
    const { data: ticket, error: ticketError } = await supabase
      .from('user_tickets')
      .select('*')
      .eq('id', ticket_id)
      .eq('is_listed', true)
      .eq('sale_status', 'available')
      .single();

    if (ticketError || !ticket) {
      throw new Error('Ticket not found or not available');
    }

    // Prevent buying your own ticket
    if (ticket.user_id === user.id) {
      throw new Error('Cannot purchase your own ticket');
    }

    // Get seller's Stripe account using the direct stripe_account_id stored in ticket
    if (!ticket.stripe_account_id) {
      throw new Error('Ticket has no associated Stripe account');
    }

    const { data: sellerAccount, error: accountError } = await supabase
      .from('stripe_connected_accounts')
      .select('stripe_account_id, charges_enabled, payouts_enabled')
      .eq('stripe_account_id', ticket.stripe_account_id)
      .single();

    if (accountError || !sellerAccount) {
      throw new Error('Seller Stripe account not found');
    }

    // Check if seller can receive payments
    if (!sellerAccount.charges_enabled || !sellerAccount.payouts_enabled) {
      throw new Error('Seller account not ready to receive payments');
    }

    // Calculate fees - NEW MODEL: £1.00 flat fee + 10% platform fee
    const ticketPrice = parseFloat(ticket.total_price || ticket.price_per_ticket || '0');

    // Validate price exists
    if (!ticketPrice || isNaN(ticketPrice) || ticketPrice <= 0) {
      console.error('Invalid ticket price:', {
        total_price: ticket.total_price,
        price_per_ticket: ticket.price_per_ticket,
        calculated: ticketPrice
      });
      throw new Error('Invalid ticket price - ticket must have a valid price');
    }

    // Calculate platform fee: £1.00 flat + 10% of ticket price
    const percentageFee = Math.round((ticketPrice * platformFeePercentage) / 100 * 100) / 100;
    const platformFee = Math.round((flatFee + percentageFee) * 100) / 100;

    // Buyer total = ticket price + platform fee (flat + percentage)
    const buyerTotal = ticketPrice + platformFee;

    // Seller gets the FULL ticket price (transferred via destination charge)
    const sellerAmount = ticketPrice;

    console.log('💰 Creating payment intent:');
    console.log('   Ticket price:', ticketPrice);
    console.log('   Flat fee:', flatFee);
    console.log('   Percentage fee (10%):', percentageFee);
    console.log('   Total platform fee:', platformFee);
    console.log('   Buyer pays total:', buyerTotal);
    console.log('   Seller gets:', sellerAmount);
    console.log('   Seller account:', sellerAccount.stripe_account_id);

    // Get or create Stripe customer for buyer
    let customerId = null;
    const { data: existingCustomer } = await supabase
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', user.id)
      .single();

    if (existingCustomer) {
      customerId = existingCustomer.stripe_customer_id;
      console.log('✅ Using existing customer:', customerId);
    } else {
      // Create new Stripe customer
      const customer = await stripe.customers.create({
        email: user.email,
        metadata: {
          user_id: user.id,
          platform: 'REUNI',
        },
      });
      customerId = customer.id;

      // Store customer ID
      await supabase.from('stripe_customers').insert({
        user_id: user.id,
        stripe_customer_id: customerId,
      });

      console.log('✅ Created new customer:', customerId);
    }

    // Create ephemeral key for customer (needed for Payment Sheet)
    const ephemeralKey = await stripe.ephemeralKeys.create(
      { customer: customerId },
      { apiVersion: '2023-10-16' }
    );

    console.log('✅ Created ephemeral key');

    // Create payment intent with ESCROW (no auto-transfer)
    // IMPORTANT: Funds stay in platform account until escrow release
    // Buyer pays buyerTotal, seller receives sellerAmount AFTER escrow period
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(buyerTotal * 100), // Buyer pays: ticket price + platform fee (in pence)
      currency: 'gbp',
      customer: customerId,
      // NO application_fee_amount - we keep the fee when we manually transfer
      // NO transfer_data - funds stay in platform account (ESCROW)
      metadata: {
        ticket_id: ticket_id,
        buyer_id: user.id,
        seller_id: ticket.user_id,
        seller_stripe_account_id: sellerAccount.stripe_account_id, // Store for later transfer
        event_name: ticket.event_name || 'Unknown Event',
        platform: 'REUNI',
        ticket_price: ticketPrice.toString(),
        platform_fee: platformFee.toString(),
        buyer_total: buyerTotal.toString(),
        seller_amount: sellerAmount.toString(),
        escrow_enabled: 'true',
        release_method: 'manual',
      },
      description: `REUNI Ticket: ${ticket.event_name || 'Event Ticket'}`,
      statement_descriptor_suffix: 'REUNI',
      automatic_payment_methods: {
        enabled: true,
      },
    });

    // Create transaction record with ESCROW status
    // escrow_hold_until will be auto-calculated by database trigger
    const { error: transactionError } = await supabase.from('transactions').insert({
      buyer_id: user.id,
      seller_id: ticket.user_id,
      ticket_id: ticket_id,
      stripe_payment_intent_id: paymentIntent.id,
      ticket_price: ticketPrice,
      platform_fee: platformFee,
      seller_amount: sellerAmount, // Seller gets full ticket price (after escrow)
      buyer_total: buyerTotal, // Buyer pays ticket + platform fee
      currency: 'gbp',
      status: 'pending', // Will become 'completed' on payment success
      escrow_status: 'held', // Funds held in escrow
      auto_release_eligible: true, // Can be auto-released unless dispute filed
      payment_initiated_at: new Date().toISOString(),
    });

    if (transactionError) {
      console.error('Transaction creation error:', transactionError);
      // Cancel the payment intent if transaction creation fails
      await stripe.paymentIntents.cancel(paymentIntent.id);
      throw new Error('Failed to create transaction record');
    }

    // DON'T mark ticket as pending_payment - keep as 'available' until payment succeeds
    // Webhook will mark as 'sold' when payment completes
    // This prevents orphaned pending_payment tickets if user abandons checkout

    console.log('✅ Payment intent created successfully');
    console.log('   Payment Intent ID:', paymentIntent.id);

    return new Response(
      JSON.stringify({
        success: true,
        client_secret: paymentIntent.client_secret,
        ephemeral_key: ephemeralKey.secret,
        customer: customerId,
        paymentIntentId: paymentIntent.id,
        amount: ticketPrice,
        platformFee: platformFee,
        sellerAmount: sellerAmount,
        currency: 'gbp',
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
    console.error('Error creating payment intent:', error);
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
