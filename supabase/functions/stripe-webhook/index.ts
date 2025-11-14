// Supabase Edge Function: stripe-webhook
// Purpose: Handle Stripe webhook events
// Endpoint: POST /functions/v1/stripe-webhook

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";
import Stripe from "https://esm.sh/stripe@14.0.0?target=deno";

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') || '', {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') || '';
const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req) => {
  // Don't handle OPTIONS - Supabase handles CORS automatically with --no-verify-jwt
  // if (req.method === 'OPTIONS') {
  //   return new Response('ok', {
  //     headers: {
  //       'Access-Control-Allow-Origin': '*',
  //       'Access-Control-Allow-Methods': 'POST, OPTIONS',
  //       'Access-Control-Allow-Headers': 'stripe-signature, content-type',
  //     },
  //   });
  // }

  console.log('🔵 Webhook received');
  console.log('   Method:', req.method);
  console.log('   URL:', req.url);

  // Log all headers to debug
  const headers = Object.fromEntries(req.headers.entries());
  console.log('   All headers received:', headers);

  // Try different header name variations
  const signature = req.headers.get('stripe-signature')
    || req.headers.get('Stripe-Signature')
    || req.headers.get('STRIPE-SIGNATURE');

  console.log('   Signature value:', signature ? 'PRESENT' : 'MISSING');

  if (!signature) {
    console.error('❌ No stripe-signature header found');
    console.error('   Available headers:', Object.keys(headers));
    return new Response(JSON.stringify({
      error: 'No signature',
      headers: Object.keys(headers)
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  console.log('✅ Signature present');

  try {
    const body = await req.text();
    console.log('📦 Body length:', body.length);
    console.log('🔑 Webhook secret set:', !!webhookSecret);

    // Verify webhook signature
    console.log('🔐 Verifying signature...');
    const event = await stripe.webhooks.constructEventAsync(body, signature, webhookSecret);
    console.log('✅ Signature verified, event type:', event.type);

    console.log(`Processing webhook event: ${event.type}`);

    // Handle different event types
    switch (event.type) {
      case 'payment_intent.succeeded': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentSucceeded(paymentIntent);
        break;
      }

      case 'payment_intent.payment_failed': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentFailed(paymentIntent);
        break;
      }

      case 'payment_intent.canceled': {
        const paymentIntent = event.data.object as Stripe.PaymentIntent;
        await handlePaymentCanceled(paymentIntent);
        break;
      }

      case 'transfer.created': {
        const transfer = event.data.object as Stripe.Transfer;
        await handleTransferCreated(transfer);
        break;
      }

      case 'transfer.failed': {
        const transfer = event.data.object as Stripe.Transfer;
        await handleTransferFailed(transfer);
        break;
      }

      case 'account.updated': {
        const account = event.data.object as Stripe.Account;
        await handleAccountUpdated(account);
        break;
      }

      case 'charge.refunded': {
        const charge = event.data.object as Stripe.Charge;
        await handleChargeRefunded(charge);
        break;
      }

      case 'payout.paid': {
        const payout = event.data.object as Stripe.Payout;
        await handlePayoutPaid(payout);
        break;
      }

      case 'payout.failed': {
        const payout = event.data.object as Stripe.Payout;
        await handlePayoutFailed(payout);
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    console.error('Webhook error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});

// Handle successful payment
async function handlePaymentSucceeded(paymentIntent: Stripe.PaymentIntent) {
  console.log('🎯 handlePaymentSucceeded called');
  console.log('📋 Payment Intent metadata:', JSON.stringify(paymentIntent.metadata));

  const ticketId = paymentIntent.metadata.ticket_id;
  const buyerId = paymentIntent.metadata.buyer_id;
  const sellerId = paymentIntent.metadata.seller_id;

  console.log(`💰 Payment succeeded for ticket ${ticketId}`);
  console.log(`👤 Buyer ID: ${buyerId}, Seller ID: ${sellerId}`);

  // Update transaction status
  const { error: transactionError } = await supabase
    .from('transactions')
    .update({
      status: 'succeeded',
      payment_completed_at: new Date().toISOString(),
    })
    .eq('stripe_payment_intent_id', paymentIntent.id);

  if (transactionError) {
    console.error('❌ Transaction update error:', transactionError);
    return; // Don't continue if we can't update the transaction
  } else {
    console.log('✅ Transaction status updated to succeeded');
  }

  // Get transaction to get buyer info
  console.log('🔍 Looking for transaction with payment_intent_id:', paymentIntent.id);
  const { data: transaction, error: transactionFetchError } = await supabase
    .from('transactions')
    .select('id')
    .eq('stripe_payment_intent_id', paymentIntent.id)
    .single();

  if (transactionFetchError) {
    console.error('❌ Failed to fetch transaction:', transactionFetchError);
  }

  if (!transaction) {
    console.error('❌ No transaction found for payment_intent_id:', paymentIntent.id);
    console.error('   This means the transaction record is missing or has a different payment_intent_id');
    return;
  }

  console.log('✅ Found transaction:', transaction.id);

  // Get the original ticket data before transferring
  console.log('🎫 Fetching original ticket:', ticketId);
  const { data: originalTicket, error: fetchError } = await supabase
    .from('user_tickets')
    .select('*')
    .eq('id', ticketId)
    .single();

  if (fetchError) {
    console.error('❌ Failed to fetch original ticket:', fetchError);
    return;
  }

  if (!originalTicket) {
    console.error('❌ Original ticket not found for id:', ticketId);
    return;
  }

  console.log('✅ Found original ticket:', originalTicket.event_name);

  // Mark seller's ticket as sold (keeps in their history as "sold")
  console.log('📝 Marking seller ticket as sold...');
  const { error: sellerTicketError } = await supabase
    .from('user_tickets')
    .update({
      sale_status: 'sold',
      is_listed: false,
      sold_at: new Date().toISOString(),
      buyer_id: buyerId,
      transaction_id: transaction?.id,
    })
    .eq('id', ticketId);

  if (sellerTicketError) {
    console.error('❌ Seller ticket update error:', sellerTicketError);
    return;
  }

  console.log('✅ Seller ticket marked as sold');

  // Create a new ticket for the buyer (ownership transfer)
  console.log('🎁 Creating new ticket for buyer:', buyerId);

  // Use RPC to call a database function that copies the ticket exactly
  // This avoids type casting issues with the Supabase JS client
  const { error: buyerTicketError, data: newTicket } = await supabase.rpc(
    'create_buyer_ticket_from_seller',
    {
      p_buyer_id: buyerId,
      p_seller_id: sellerId,
      p_transaction_id: transaction?.id,
      p_original_ticket_id: originalTicket.id,
    }
  );

  if (buyerTicketError) {
    console.error('❌ Buyer ticket creation error:', buyerTicketError);
    console.error('   Error details:', JSON.stringify(buyerTicketError));
  } else {
    console.log('✅ Ticket transferred to buyer successfully');
    console.log('   New ticket ID:', newTicket?.[0]?.new_ticket_id);

    // Send purchase receipt email to buyer
    console.log('📧 Sending purchase receipt email to buyer...');
    try {
      const emailResponse = await supabase.functions.invoke('send-purchase-email', {
        body: {
          transaction_id: transaction?.id,
          buyer_id: buyerId,
          seller_id: sellerId,
          ticket_id: newTicket?.[0]?.new_ticket_id,
        },
      });

      if (emailResponse.error) {
        console.error('⚠️ Failed to send purchase receipt email:', emailResponse.error);
      } else {
        console.log('✅ Purchase receipt email sent successfully');
      }
    } catch (emailError) {
      console.error('⚠️ Error sending purchase receipt email:', emailError);
      // Don't fail the entire webhook if email fails
    }
  }

  // Send push notification to seller
  console.log('📲 Sending push notification to seller...');
  try {
    await supabase.functions.invoke('send-push-notification', {
      body: {
        userId: sellerId,
        type: 'ticket_purchased',
        title: 'Ticket Sold! 🎉',
        body: `Your ticket for "${originalTicket.event_name}" has been purchased.`,
        data: {
          ticket_id: ticketId,
          event_name: originalTicket.event_name,
        },
      },
    });
    console.log('✅ Seller push notification sent');
  } catch (notifError) {
    console.error('⚠️  Failed to send push notification to seller:', notifError);
    // Don't fail the webhook if notification fails
  }

  // Send push notification to buyer
  console.log('📲 Sending push notification to buyer...');
  try {
    await supabase.functions.invoke('send-push-notification', {
      body: {
        userId: buyerId,
        type: 'ticket_bought',
        title: 'Purchase Successful! 🎟️',
        body: `You've successfully purchased a ticket for "${originalTicket.event_name}". Check "My Purchases" to view details.`,
        data: {
          ticket_id: newTicket?.[0]?.new_ticket_id,
          event_name: originalTicket.event_name,
        },
      },
    });
    console.log('✅ Buyer push notification sent');
  } catch (notifError) {
    console.error('⚠️  Failed to send push notification to buyer:', notifError);
    // Don't fail the webhook if notification fails
  }
}

// Handle failed payment
async function handlePaymentFailed(paymentIntent: Stripe.PaymentIntent) {
  const ticketId = paymentIntent.metadata.ticket_id;
  const buyerId = paymentIntent.metadata.buyer_id;

  console.log(`Payment failed for ticket ${ticketId}`);

  // Update transaction status
  await supabase
    .from('transactions')
    .update({
      status: 'failed',
      failure_code: paymentIntent.last_payment_error?.code || 'unknown',
      failure_message: paymentIntent.last_payment_error?.message || 'Payment failed',
    })
    .eq('stripe_payment_intent_id', paymentIntent.id);

  // Reset ticket status to available
  await supabase
    .from('user_tickets')
    .update({ sale_status: 'available' })
    .eq('id', ticketId);

  // Notify buyer
  await supabase.from('notifications').insert({
    user_id: buyerId,
    type: 'system_message',
    title: 'Payment Failed',
    message: 'Your payment was unsuccessful. Please try again or use a different payment method.',
    is_read: false,
  });
}

// Handle canceled payment
async function handlePaymentCanceled(paymentIntent: Stripe.PaymentIntent) {
  const ticketId = paymentIntent.metadata.ticket_id;

  console.log(`Payment canceled for ticket ${ticketId}`);

  // Update transaction status
  await supabase
    .from('transactions')
    .update({ status: 'cancelled' })
    .eq('stripe_payment_intent_id', paymentIntent.id);

  // Reset ticket status to available
  await supabase
    .from('user_tickets')
    .update({ sale_status: 'available' })
    .eq('id', ticketId);
}

// Handle transfer created (funds sent to seller)
async function handleTransferCreated(transfer: Stripe.Transfer) {
  console.log(`✅ Transfer created: ${transfer.id}`);
  console.log(`   Amount: ${transfer.amount / 100} ${transfer.currency}`);
  console.log(`   Destination: ${transfer.destination}`);

  // Note: We store stripe_payment_intent_id in transactions, but transfer.source_transaction
  // is the charge ID. We'd need to add a stripe_charge_id column to link them.
  // For now, just log the transfer - the main payment flow still works.
}

// Handle transfer failed
async function handleTransferFailed(transfer: Stripe.Transfer) {
  console.error('Transfer failed:', transfer.id, transfer.failure_message);

  // Update transaction status
  await supabase
    .from('transactions')
    .update({
      failure_code: 'transfer_failed',
      failure_message: transfer.failure_message || 'Transfer to seller failed',
    })
    .eq('stripe_transfer_id', transfer.id);
}

// Handle Stripe Connect account updates
async function handleAccountUpdated(account: Stripe.Account) {
  console.log(`Account updated: ${account.id}`);

  // Update connected account status
  await supabase
    .from('stripe_connected_accounts')
    .update({
      charges_enabled: account.charges_enabled,
      payouts_enabled: account.payouts_enabled,
      details_submitted: account.details_submitted,
      onboarding_completed: account.details_submitted && account.charges_enabled,
      currently_due: account.requirements?.currently_due || null,
    })
    .eq('stripe_account_id', account.id);
}

// Handle refund
async function handleChargeRefunded(charge: Stripe.Charge) {
  console.log(`Charge refunded: ${charge.id}`);

  // Note: We can't find transactions by charge ID since we only store payment_intent_id
  // For refunds, we'd need to add a stripe_charge_id column or use payment_intent
  console.log('⚠️ Refund handler needs stripe_charge_id column to link transactions');
  console.log(`   Charge ID: ${charge.id}`);
  console.log(`   Payment Intent: ${charge.payment_intent}`);

  // Try to find by payment intent instead
  const { data: transaction } = await supabase
    .from('transactions')
    .select('id, ticket_id, buyer_id, seller_id')
    .eq('stripe_payment_intent_id', charge.payment_intent as string)
    .single();

  if (!transaction) {
    console.error('❌ Transaction not found for payment intent:', charge.payment_intent);
    return;
  }

  console.log('✅ Found transaction for refund:', transaction.id);

  // Update transaction status
  await supabase
    .from('transactions')
    .update({
      status: 'refunded',
      refunded_at: new Date().toISOString(),
    })
    .eq('id', transaction.id);

  // Update ticket status
  await supabase
    .from('user_tickets')
    .update({
      sale_status: 'refunded',
      is_listed: true, // Make available again
      buyer_id: null,
      transaction_id: null,
    })
    .eq('id', transaction.ticket_id);

  // Notify both parties
  await supabase.from('notifications').insert([
    {
      user_id: transaction.buyer_id,
      type: 'system_message',
      title: 'Refund Processed',
      message: 'Your payment has been refunded.',
      is_read: false,
    },
    {
      user_id: transaction.seller_id,
      type: 'system_message',
      title: 'Sale Refunded',
      message: 'A ticket sale has been refunded. Your ticket is now available again.',
      is_read: false,
    },
  ]);
}

// Handle payout paid (sent to seller's bank account)
async function handlePayoutPaid(payout: Stripe.Payout) {
  console.log(`💸 Payout paid: ${payout.id}`);
  console.log(`   Amount: ${payout.amount / 100} ${payout.currency.toUpperCase()}`);
  console.log(`   Destination: ${payout.destination}`);

  // Get the seller's user_id from their Stripe account ID
  const { data: sellerAccount } = await supabase
    .from('seller_accounts')
    .select('user_id')
    .eq('stripe_account_id', payout.destination as string)
    .single();

  if (!sellerAccount) {
    console.error('❌ Seller account not found for Stripe account:', payout.destination);
    return;
  }

  const sellerId = sellerAccount.user_id;
  const amountFormatted = (payout.amount / 100).toFixed(2);

  console.log(`✅ Found seller: ${sellerId}`);

  // Send push notification to seller
  console.log('📲 Sending payout notification to seller...');
  try {
    await supabase.functions.invoke('send-push-notification', {
      body: {
        userId: sellerId,
        type: 'payout_received',
        title: 'Payout Received! 💸',
        body: `£${amountFormatted} has been sent to your bank account.`,
        data: {
          payout_id: payout.id,
          amount: amountFormatted,
          currency: payout.currency.toUpperCase(),
        },
      },
    });
    console.log('✅ Payout notification sent');
  } catch (notifError) {
    console.error('⚠️  Failed to send payout notification:', notifError);
  }
}

// Handle payout failed
async function handlePayoutFailed(payout: Stripe.Payout) {
  console.log(`❌ Payout failed: ${payout.id}`);
  console.log(`   Failure message: ${payout.failure_message}`);

  // Get the seller's user_id
  const { data: sellerAccount } = await supabase
    .from('seller_accounts')
    .select('user_id')
    .eq('stripe_account_id', payout.destination as string)
    .single();

  if (!sellerAccount) {
    console.error('❌ Seller account not found for Stripe account:', payout.destination);
    return;
  }

  const sellerId = sellerAccount.user_id;
  const amountFormatted = (payout.amount / 100).toFixed(2);

  console.log(`✅ Found seller: ${sellerId}`);

  // Send push notification to seller
  console.log('📲 Sending payout failure notification to seller...');
  try {
    await supabase.functions.invoke('send-push-notification', {
      body: {
        userId: sellerId,
        type: 'payout_failed',
        title: 'Payout Failed ⚠️',
        body: `Your payout of £${amountFormatted} failed. Please check your bank details in Stripe.`,
        data: {
          payout_id: payout.id,
          amount: amountFormatted,
          failure_message: payout.failure_message,
        },
      },
    });
    console.log('✅ Payout failure notification sent');
  } catch (notifError) {
    console.error('⚠️  Failed to send payout failure notification:', notifError);
  }
}
