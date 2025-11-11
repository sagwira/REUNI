import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createSecureResponse, createSecureErrorResponse, handleCorsPreFlight } from '../_shared/security-headers.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

interface PayoutConfirmationRequest {
  transaction_id: string
  seller_id: string
  payout_amount: number
  stripe_transfer_id: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return handleCorsPreFlight()
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
    const { transaction_id, seller_id, payout_amount, stripe_transfer_id } = await req.json() as PayoutConfirmationRequest

    console.log('📧 Sending payout confirmation email...')
    console.log(`   Transaction: ${transaction_id}`)

    // Fetch seller and transaction data
    const [sellerData, transactionData] = await Promise.all([
      supabase.from('profiles').select('email, username, full_name').eq('id', seller_id).single(),
      supabase.from('transactions').select('*, user_tickets(event_name, event_date)').eq('id', transaction_id).single()
    ])

    if (sellerData.error || transactionData.error) {
      throw new Error('Failed to fetch payout details')
    }

    const seller = sellerData.data
    const transaction = transactionData.data

    // Format payout date
    const payoutDate = new Date().toLocaleDateString('en-GB', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })

    // Send payout confirmation to seller
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'REUNI <payouts@reuniapp.com>',
        reply_to: 'info@reuniapp.com',
        to: seller.email,
        subject: `💸 Payout sent: £${payout_amount.toFixed(2)}`,
        html: generatePayoutConfirmationEmail({
          sellerName: seller.full_name || seller.username,
          eventName: transaction.user_tickets.event_name,
          payoutAmount: payout_amount,
          originalAmount: transaction.amount,
          transactionId: transaction_id,
          stripeTransferId: stripe_transfer_id,
          payoutDate: payoutDate
        })
      })
    })

    if (!emailResponse.ok) {
      const error = await emailResponse.text()
      console.error('❌ Failed to send payout confirmation:', error)
      throw new Error('Failed to send payout confirmation email')
    }

    console.log('✅ Payout confirmation email sent')

    return createSecureResponse({
      success: true,
      message: 'Payout confirmation sent successfully'
    })

  } catch (error) {
    console.error('❌ Error sending payout confirmation:', error)
    return createSecureErrorResponse(error.message || 'Failed to send payout confirmation', 500)
  }
})

function generatePayoutConfirmationEmail(data: {
  sellerName: string
  eventName: string
  payoutAmount: number
  originalAmount: number
  transactionId: string
  stripeTransferId: string
  payoutDate: string
}): string {
  const platformFee = data.originalAmount - data.payoutAmount

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Payout Sent</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #22c55e 0%, #10b981 100%); padding: 40px 40px 30px; border-radius: 12px 12px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">💸 Payout Sent!</h1>
              <p style="margin: 10px 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Your funds are on the way</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 40px 40px 20px;">
              <p style="margin: 0; color: #333; font-size: 18px; line-height: 1.6;">Hi ${data.sellerName},</p>
              <p style="margin: 16px 0 0; color: #666; font-size: 16px; line-height: 1.6;">
                Great news! Your payout for <strong style="color: #333;">${data.eventName}</strong> has been processed and sent to your Stripe account.
              </p>
            </td>
          </tr>

          <!-- Payout Details -->
          <tr>
            <td style="padding: 0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f0fdf4; border-radius: 8px; border-left: 4px solid #22c55e;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; color: #333; font-size: 20px; font-weight: 600;">Payout Summary</h2>

                    <table width="100%" cellpadding="8" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">Sale Amount:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">£${data.originalAmount.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">Platform Fee:</td>
                        <td style="color: #666; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">- £${platformFee.toFixed(2)}</td>
                      </tr>
                      <tr style="border-top: 2px solid #e5e7eb;">
                        <td style="color: #666; font-size: 16px; padding: 12px 0 8px; font-weight: 600;">Your Payout:</td>
                        <td style="color: #22c55e; font-size: 24px; font-weight: 700; text-align: right; padding: 12px 0 8px;">£${data.payoutAmount.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 13px; padding: 8px 0 0;">Payout Date:</td>
                        <td style="color: #666; font-size: 13px; text-align: right; padding: 8px 0 0;">${data.payoutDate}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 13px; padding: 4px 0;">Transaction ID:</td>
                        <td style="color: #666; font-size: 13px; text-align: right; font-family: monospace; padding: 4px 0;">${data.transactionId.substring(0, 16)}...</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 13px; padding: 4px 0;">Stripe Transfer ID:</td>
                        <td style="color: #666; font-size: 13px; text-align: right; font-family: monospace; padding: 4px 0;">${data.stripeTransferId.substring(0, 16)}...</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Timeline -->
          <tr>
            <td style="padding: 24px 40px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">⏱️ What Happens Next</h3>
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 8px;">
                <tr>
                  <td style="padding: 24px;">
                    <ol style="margin: 0; padding-left: 20px; color: #666; font-size: 15px; line-height: 1.8;">
                      <li>Funds are now in your Stripe balance</li>
                      <li>Stripe will transfer to your bank account automatically</li>
                      <li>Bank transfers typically take 2-3 business days</li>
                      <li>Check your Stripe dashboard for details</li>
                    </ol>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td style="padding: 0 40px 32px; text-align: center;">
              <a href="https://dashboard.stripe.com/transfers" style="display: inline-block; background: linear-gradient(135deg, #635bff 0%, #5548d9 100%); color: #ffffff; text-decoration: none; padding: 16px 48px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(99, 91, 255, 0.3);">
                View in Stripe Dashboard
              </a>
            </td>
          </tr>

          <!-- Info Box -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #eff6ff; border-radius: 8px; border-left: 4px solid #3b82f6;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #1e40af; font-size: 15px; font-weight: 600;">💡 About Payouts</h4>
                    <p style="margin: 0; color: #1e40af; font-size: 13px; line-height: 1.6;">
                      REUNI uses Stripe Connect for secure payouts. Your funds are transferred directly from our platform to your Stripe account, then to your bank. You can track all transactions in your Stripe dashboard.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Celebrate -->
          <tr>
            <td style="padding: 0 40px 32px; text-align: center;">
              <p style="margin: 0; color: #22c55e; font-size: 48px; line-height: 1;">🎉</p>
              <p style="margin: 12px 0 0; color: #666; font-size: 16px; font-weight: 600;">
                Thanks for using REUNI!
              </p>
              <p style="margin: 8px 0 0; color: #999; font-size: 14px;">
                Keep listing tickets to earn more
              </p>
            </td>
          </tr>

          <!-- Support -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <p style="margin: 0; color: #666; font-size: 14px; text-align: center; line-height: 1.6;">
                Questions about your payout? Contact us at <a href="mailto:payouts@reuniapp.com" style="color: #22c55e; text-decoration: none;">payouts@reuniapp.com</a>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding: 24px 40px; background-color: #f8f9fa; border-radius: 0 0 12px 12px; text-align: center;">
              <p style="margin: 0; color: #999; font-size: 12px;">
                © 2025 REUNI. All rights reserved.<br>
                Secure student ticket marketplace.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>
  `.trim()
}
