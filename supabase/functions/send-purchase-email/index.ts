import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createSecureResponse, createSecureErrorResponse, handleCorsPreFlight } from '../_shared/security-headers.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface PurchaseEmailRequest {
  transaction_id: string
  buyer_id: string
  seller_id: string
  ticket_id: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return handleCorsPreFlight()
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)
    const { transaction_id, buyer_id, seller_id, ticket_id } = await req.json() as PurchaseEmailRequest

    console.log('📧 Sending purchase confirmation emails...')
    console.log(`   Transaction: ${transaction_id}`)

    // Fetch all necessary data
    const [transactionData, buyerData, sellerData, ticketData] = await Promise.all([
      supabase.from('transactions').select('*').eq('id', transaction_id).single(),
      supabase.from('profiles').select('email, username, full_name').eq('id', buyer_id).single(),
      supabase.from('profiles').select('email, username, full_name').eq('id', seller_id).single(),
      supabase.from('user_tickets').select('event_name, event_date, event_location, ticket_type, price_per_ticket, quantity').eq('id', ticket_id).single()
    ])

    if (transactionData.error || buyerData.error || sellerData.error || ticketData.error) {
      throw new Error('Failed to fetch transaction details')
    }

    const transaction = transactionData.data
    const buyer = buyerData.data
    const seller = sellerData.data
    const ticket = ticketData.data

    // Format date
    const eventDate = new Date(ticket.event_date).toLocaleDateString('en-GB', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })

    // Send buyer confirmation email
    const buyerEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'REUNI <noreply@support.reuniapp.com>',
        reply_to: 'info@support.reuniapp.com',
        to: buyer.email,
        subject: `✅ Your ticket for ${ticket.event_name}`,
        html: generateBuyerEmail({
          buyerName: buyer.full_name || buyer.username,
          eventName: ticket.event_name,
          eventDate: eventDate,
          eventLocation: ticket.event_location,
          ticketType: ticket.ticket_type,
          quantity: ticket.quantity,
          totalPaid: transaction.buyer_total,
          transactionId: transaction_id,
          sellerUsername: seller.username,
          ticketScreenshotUrl: ticket.ticket_screenshot_url // Include ticket image
        })
      })
    })

    if (!buyerEmailResponse.ok) {
      const error = await buyerEmailResponse.text()
      console.error('❌ Resend API error (buyer):', error)
      console.error('Response status:', buyerEmailResponse.status)
      throw new Error(`Failed to send buyer email (${buyerEmailResponse.status}): ${error}`)
    }

    console.log('✅ Buyer confirmation email sent')

    // Send seller notification email
    const sellerEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'REUNI <noreply@support.reuniapp.com>',
        reply_to: 'info@support.reuniapp.com',
        to: seller.email,
        subject: `💰 Your ticket was sold: ${ticket.event_name}`,
        html: generateSellerEmail({
          sellerName: seller.full_name || seller.username,
          eventName: ticket.event_name,
          buyerUsername: buyer.username,
          saleAmount: transaction.seller_amount || transaction.ticket_price,
          quantity: ticket.quantity,
          transactionId: transaction_id
        })
      })
    })

    if (!sellerEmailResponse.ok) {
      const error = await sellerEmailResponse.text()
      console.error('❌ Resend API error (seller):', error)
      console.error('Response status:', sellerEmailResponse.status)
      // Don't throw - buyer email is more important
    } else {
      console.log('✅ Seller notification email sent')
    }

    return createSecureResponse({
      success: true,
      message: 'Purchase confirmation emails sent successfully'
    })

  } catch (error) {
    console.error('❌ Error sending purchase emails:', error)
    console.error('Error details:', JSON.stringify(error, null, 2))
    return createSecureErrorResponse(
      `Failed to send purchase emails: ${error.message || 'Unknown error'}`,
      500
    )
  }
})

// MARK: - Email Templates

function generateBuyerEmail(data: {
  buyerName: string
  eventName: string
  eventDate: string
  eventLocation: string | null
  ticketType: string | null
  quantity: number
  totalPaid: number
  transactionId: string
  sellerUsername: string
  ticketScreenshotUrl: string | null
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Purchase Confirmation</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #FF3B30 0%, #FF6B6B 100%); padding: 40px 40px 30px; border-radius: 12px 12px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">✅ Purchase Confirmed!</h1>
              <p style="margin: 10px 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Your ticket is ready</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 40px 40px 20px;">
              <p style="margin: 0; color: #333; font-size: 18px; line-height: 1.6;">Hi ${data.buyerName},</p>
              <p style="margin: 16px 0 0; color: #666; font-size: 16px; line-height: 1.6;">
                Great news! You've successfully purchased ${data.quantity} ticket${data.quantity > 1 ? 's' : ''} for <strong style="color: #333;">${data.eventName}</strong>.
              </p>
            </td>
          </tr>

          <!-- Event Details Card -->
          <tr>
            <td style="padding: 0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 8px; border-left: 4px solid #FF3B30;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; color: #333; font-size: 20px; font-weight: 600;">Event Details</h2>

                    <table width="100%" cellpadding="8" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">📅 Date & Time:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventDate}</td>
                      </tr>
                      ${data.eventLocation ? `
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">📍 Location:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventLocation}</td>
                      </tr>
                      ` : ''}
                      ${data.ticketType ? `
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">🎫 Ticket Type:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.ticketType}</td>
                      </tr>
                      ` : ''}
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">🔢 Quantity:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.quantity}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Payment Details -->
          <tr>
            <td style="padding: 24px 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f0fdf4; border-radius: 8px; border-left: 4px solid #22c55e;">
                <tr>
                  <td style="padding: 24px;">
                    <h3 style="margin: 0 0 12px; color: #333; font-size: 18px; font-weight: 600;">Payment Summary</h3>
                    <table width="100%" cellpadding="6" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 16px;">Total Paid:</td>
                        <td style="color: #22c55e; font-size: 20px; font-weight: 700; text-align: right;">£${data.totalPaid.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 13px; padding-top: 8px;">Transaction ID:</td>
                        <td style="color: #666; font-size: 13px; text-align: right; font-family: monospace; padding-top: 8px;">${data.transactionId}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Ticket Screenshot (if available) -->
          ${data.ticketScreenshotUrl ? `
          <tr>
            <td style="padding: 0 40px 32px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">🎫 Your Ticket</h3>
              <p style="margin: 0 0 16px; color: #666; font-size: 14px;">
                Here's a copy of your ticket. We recommend saving this image or printing it as a backup.
              </p>
              <div style="background-color: #f8f9fa; border-radius: 12px; padding: 20px; text-align: center;">
                <img
                  src="${data.ticketScreenshotUrl}"
                  alt="Your ticket barcode"
                  style="max-width: 100%; height: auto; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);"
                />
                <p style="margin: 16px 0 0; color: #999; font-size: 12px;">
                  💡 Tip: Save this image to your phone for quick access at the venue
                </p>
              </div>
            </td>
          </tr>
          ` : ''}

          <!-- Next Steps -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">📱 Next Steps</h3>
              <ol style="margin: 0; padding-left: 20px; color: #666; font-size: 15px; line-height: 1.8;">
                ${data.ticketScreenshotUrl ? `
                <li>Save the ticket image above to your phone</li>
                <li>Or access it anytime in the REUNI app → "My Purchases"</li>
                ` : `
                <li>Open the REUNI app and go to "My Purchases"</li>
                <li>Your ticket with barcode will be available shortly</li>
                `}
                <li>Present the barcode at the event entrance</li>
                <li>Have a great time! 🎉</li>
              </ol>
            </td>
          </tr>

          <!-- Seller Info -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <p style="margin: 0; color: #666; font-size: 14px;">
                <strong>Purchased from:</strong> @${data.sellerUsername}
              </p>
            </td>
          </tr>

          <!-- Protection Notice -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #fff7ed; border-radius: 8px; border-left: 4px solid #f59e0b;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #92400e; font-size: 15px; font-weight: 600;">🛡️ Buyer Protection</h4>
                    <p style="margin: 0; color: #92400e; font-size: 13px; line-height: 1.6;">
                      Your payment is held securely in escrow until <strong>6:00 AM the day after the event</strong>. If there's any issue with your ticket (fake, already used, rejected at venue), you can report it before 6:00 AM and request a full refund.
                    </p>
                    ${data.ticketScreenshotUrl ? `
                    <p style="margin: 8px 0 0; color: #92400e; font-size: 13px; line-height: 1.6;">
                      <strong>✅ Backup Copy:</strong> Your ticket is saved in this email, in the REUNI app, and on our secure servers. You have multiple copies for peace of mind.
                    </p>
                    ` : ''}
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Support -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <p style="margin: 0; color: #666; font-size: 14px; text-align: center; line-height: 1.6;">
                Questions or issues? Reply to this email for support.
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

function generateSellerEmail(data: {
  sellerName: string
  eventName: string
  buyerUsername: string
  saleAmount: number
  quantity: number
  transactionId: string
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Ticket Sold!</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #22c55e 0%, #10b981 100%); padding: 40px 40px 30px; border-radius: 12px 12px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">💰 Ticket Sold!</h1>
              <p style="margin: 10px 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Congratulations on your sale</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 40px 40px 20px;">
              <p style="margin: 0; color: #333; font-size: 18px; line-height: 1.6;">Hi ${data.sellerName},</p>
              <p style="margin: 16px 0 0; color: #666; font-size: 16px; line-height: 1.6;">
                Great news! Your ticket for <strong style="color: #333;">${data.eventName}</strong> has been sold.
              </p>
            </td>
          </tr>

          <!-- Sale Details -->
          <tr>
            <td style="padding: 0 40px 24px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f0fdf4; border-radius: 8px; border-left: 4px solid #22c55e;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; color: #333; font-size: 20px; font-weight: 600;">Sale Summary</h2>

                    <table width="100%" cellpadding="8" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 14px;">Buyer:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right;">@${data.buyerUsername}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px;">Quantity Sold:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right;">${data.quantity}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 16px; padding-top: 8px;">Sale Amount:</td>
                        <td style="color: #22c55e; font-size: 20px; font-weight: 700; text-align: right; padding-top: 8px;">£${data.saleAmount.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 13px; padding-top: 4px;">Transaction ID:</td>
                        <td style="color: #666; font-size: 13px; text-align: right; font-family: monospace; padding-top: 4px;">${data.transactionId}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Escrow Notice -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #eff6ff; border-radius: 8px; border-left: 4px solid #3b82f6;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #1e40af; font-size: 15px; font-weight: 600;">💰 Fast Payout</h4>
                    <p style="margin: 0; color: #1e40af; font-size: 13px; line-height: 1.6;">
                      Your funds are held securely in escrow and will be automatically released to your Stripe account at <strong>6:00 AM the day after the event</strong>. If the buyer reports an issue before 6:00 AM, we'll investigate before releasing payment.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Next Steps -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">📱 Next Steps</h3>
              <ol style="margin: 0; padding-left: 20px; color: #666; font-size: 15px; line-height: 1.8;">
                <li>Ensure your ticket screenshot is uploaded (if not already)</li>
                <li>Buyer can now view their ticket in the app</li>
                <li>Funds will be released at 6:00 AM the day after the event</li>
                <li>If buyer reports an issue, we'll notify you immediately</li>
                <li>You'll receive payment confirmation when funds are released</li>
              </ol>
            </td>
          </tr>

          <!-- Payout Info -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <p style="margin: 0; color: #666; font-size: 14px; line-height: 1.6;">
                💳 Payouts are sent to your Stripe account. Make sure your account is fully set up in the app's Profile section to receive payments.
              </p>
            </td>
          </tr>

          <!-- Support -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <p style="margin: 0; color: #666; font-size: 14px; text-align: center; line-height: 1.6;">
                Questions? Reply to this email for support.
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
