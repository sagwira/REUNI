// Supabase Edge Function: release-escrow-funds
// Purpose: Automatically release escrow funds to sellers after hold period
// Runs: Via cron job every hour OR manual trigger
// Endpoint: POST /functions/v1/release-escrow-funds

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
    console.log('🔄 Starting escrow release job...');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get all transactions ready for release using database function
    const { data: eligibleTransactions, error: queryError } = await supabase
      .rpc('get_transactions_ready_for_release');

    if (queryError) {
      console.error('❌ Error querying eligible transactions:', queryError);
      throw queryError;
    }

    if (!eligibleTransactions || eligibleTransactions.length === 0) {
      console.log('✅ No transactions ready for release');
      return new Response(
        JSON.stringify({
          success: true,
          message: 'No transactions ready for release',
          released_count: 0,
        }),
        {
          headers: { 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    console.log(`📦 Found ${eligibleTransactions.length} transactions ready for release`);

    let successCount = 0;
    let failCount = 0;
    const results = [];

    // Process each transaction
    for (const txn of eligibleTransactions) {
      try {
        console.log(`\n💰 Processing transaction: ${txn.transaction_id}`);
        console.log(`   Seller: ${txn.seller_id}`);
        console.log(`   Amount: £${txn.seller_amount}`);
        console.log(`   Stripe Account: ${txn.stripe_account_id}`);

        // Create Stripe transfer to seller's connected account
        const transfer = await stripe.transfers.create({
          amount: Math.round(parseFloat(txn.seller_amount) * 100), // Convert to pence
          currency: 'gbp',
          destination: txn.stripe_account_id,
          description: `REUNI Ticket Sale - Transaction ${txn.transaction_id}`,
          metadata: {
            transaction_id: txn.transaction_id,
            seller_id: txn.seller_id,
            platform: 'REUNI',
            release_type: 'auto_release',
          },
        });

        console.log(`   ✅ Transfer created: ${transfer.id}`);

        // Update transaction in database
        const { error: updateError } = await supabase
          .from('transactions')
          .update({
            escrow_status: 'released',
            escrow_released_at: new Date().toISOString(),
            stripe_transfer_id: transfer.id,
          })
          .eq('id', txn.transaction_id);

        if (updateError) {
          console.error(`   ❌ Failed to update transaction:`, updateError);
          failCount++;
          results.push({
            transaction_id: txn.transaction_id,
            success: false,
            error: updateError.message,
          });
          continue;
        }

        // Update seller reputation (successful sale)
        await supabase.rpc('update_seller_reputation_on_success', {
          p_seller_id: txn.seller_id,
        });

        // Send notification to seller
        await supabase.from('notifications').insert({
          user_id: txn.seller_id,
          type: 'payout_released',
          title: 'Payment Released! 💰',
          message: `£${txn.seller_amount} has been transferred to your account.`,
          is_read: false,
        });

        successCount++;
        results.push({
          transaction_id: txn.transaction_id,
          success: true,
          transfer_id: transfer.id,
          amount: txn.seller_amount,
        });

        console.log(`   ✅ Transaction ${txn.transaction_id} released successfully`);
      } catch (error) {
        console.error(`   ❌ Failed to release transaction ${txn.transaction_id}:`, error);
        failCount++;
        results.push({
          transaction_id: txn.transaction_id,
          success: false,
          error: error.message,
        });

        // Mark transaction as failed (manual review needed)
        await supabase
          .from('transactions')
          .update({
            auto_release_eligible: false,
            // Keep escrow_status as 'held' - requires manual intervention
          })
          .eq('id', txn.transaction_id);
      }
    }

    console.log(`\n📊 Escrow release job completed`);
    console.log(`   ✅ Success: ${successCount}`);
    console.log(`   ❌ Failed: ${failCount}`);

    return new Response(
      JSON.stringify({
        success: true,
        message: `Released ${successCount} transactions, ${failCount} failed`,
        released_count: successCount,
        failed_count: failCount,
        results: results,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    );
  } catch (error) {
    console.error('❌ Escrow release job error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});
