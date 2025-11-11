import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createSecureResponse, createSecureErrorResponse, handleCorsPreFlight } from '../_shared/security-headers.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

interface OfferAcceptanceRequest {
  offer_id: string
  ticket_id: string
  buyer_id: string
  seller_id: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return handleCorsPreFlight()
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
    const { offer_id, ticket_id, buyer_id, seller_id } = await req.json() as OfferAcceptanceRequest

    console.log('📧 Sending offer acceptance email...')
    console.log(`   Offer: ${offer_id}`)

    // Fetch all necessary data
    const [offerData, buyerData, sellerData, ticketData] = await Promise.all([
      supabase.from('ticket_offers').select('*').eq('id', offer_id).single(),
      supabase.from('profiles').select('email, username, full_name').eq('id', buyer_id).single(),
      supabase.from('profiles').select('email, username, full_name').eq('id', seller_id).single(),
      supabase.from('user_tickets').select('event_name, event_date, event_location, ticket_type, price_per_ticket, quantity').eq('id', ticket_id).single()
    ])

    if (offerData.error || buyerData.error || sellerData.error || ticketData.error) {
      throw new Error('Failed to fetch offer details')
    }

    const offer = offerData.data
    const buyer = buyerData.data
    const seller = sellerData.data
    const ticket = ticketData.data

    // Format event date
    const eventDate = new Date(ticket.event_date).toLocaleDateString('en-GB', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })

    // Send notification to buyer
    const buyerEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'REUNI <offers@reuniapp.com>',
        reply_to: 'info@reuniapp.com',
        to: buyer.email,
        subject: `✅ Your offer was accepted for ${ticket.event_name}`,
        html: generateBuyerAcceptanceEmail({
          buyerName: buyer.full_name || buyer.username,
          sellerUsername: seller.username,
          eventName: ticket.event_name,
          eventDate: eventDate,
          eventLocation: ticket.event_location,
          offerPrice: offer.offer_price,
          quantity: offer.quantity
        })
      })
    })

    if (!buyerEmailResponse.ok) {
      const error = await buyerEmailResponse.text()
      console.error('❌ Failed to send buyer acceptance email:', error)
      throw new Error('Failed to send offer acceptance email')
    }

    console.log('✅ Offer acceptance email sent')

    return createSecureResponse({
      success: true,
      message: 'Offer acceptance notification sent successfully'
    })

  } catch (error) {
    console.error('❌ Error sending offer acceptance:', error)
    return createSecureErrorResponse(error.message || 'Failed to send offer acceptance', 500)
  }
})

function generateBuyerAcceptanceEmail(data: {
  buyerName: string
  sellerUsername: string
  eventName: string
  eventDate: string
  eventLocation: string | null
  offerPrice: number
  quantity: number
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Offer Accepted!</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #22c55e 0%, #10b981 100%); padding: 40px 40px 30px; border-radius: 12px 12px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">🎉 Offer Accepted!</h1>
              <p style="margin: 10px 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Time to complete your purchase</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 40px 40px 20px;">
              <p style="margin: 0; color: #333; font-size: 18px; line-height: 1.6;">Hi ${data.buyerName},</p>
              <p style="margin: 16px 0 0; color: #666; font-size: 16px; line-height: 1.6;">
                Great news! <strong>@${data.sellerUsername}</strong> has accepted your offer for <strong style="color: #333;">${data.eventName}</strong>.
              </p>
            </td>
          </tr>

          <!-- Offer Details -->
          <tr>
            <td style="padding: 0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f0fdf4; border-radius: 8px; border-left: 4px solid #22c55e;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; color: #333; font-size: 20px; font-weight: 600;">Purchase Details</h2>

                    <table width="100%" cellpadding="8" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">📅 Event Date:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventDate}</td>
                      </tr>
                      ${data.eventLocation ? `
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">📍 Location:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventLocation}</td>
                      </tr>
                      ` : ''}
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">🔢 Quantity:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.quantity}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 16px; padding: 12px 0 8px;">💰 Agreed Price:</td>
                        <td style="color: #22c55e; font-size: 20px; font-weight: 700; text-align: right; padding: 12px 0 8px;">£${data.offerPrice.toFixed(2)}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Next Steps -->
          <tr>
            <td style="padding: 24px 40px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">📱 Next Steps</h3>
              <ol style="margin: 0; padding-left: 20px; color: #666; font-size: 15px; line-height: 1.8;">
                <li>Complete payment in the REUNI app within 24 hours</li>
                <li>Your payment will be held securely in escrow</li>
                <li>Receive your ticket instantly after payment</li>
                <li>Funds released to seller after 7 days (if no issues)</li>
              </ol>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td style="padding: 0 40px 32px; text-align: center;">
              <a href="reuni://payment/${data.quantity}" style="display: inline-block; background: linear-gradient(135deg, #22c55e 0%, #10b981 100%); color: #ffffff; text-decoration: none; padding: 16px 48px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(34, 197, 94, 0.3);">
                Complete Payment
              </a>
            </td>
          </tr>

          <!-- Important Notice -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #fff7ed; border-radius: 8px; border-left: 4px solid #f59e0b;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #92400e; font-size: 15px; font-weight: 600;">⏰ Payment Required Within 24 Hours</h4>
                    <p style="margin: 0; color: #92400e; font-size: 13px; line-height: 1.6;">
                      This ticket is now reserved for you, but you must complete payment within 24 hours or the offer will expire and the ticket will become available again.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Buyer Protection -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #eff6ff; border-radius: 8px; border-left: 4px solid #3b82f6;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #1e40af; font-size: 15px; font-weight: 600;">🛡️ You're Protected</h4>
                    <p style="margin: 0; color: #1e40af; font-size: 13px; line-height: 1.6;">
                      Your payment is held in escrow for 7 days. If there's any issue with your ticket, you can report it and request a full refund during this period.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Support -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <p style="margin: 0; color: #666; font-size: 14px; text-align: center; line-height: 1.6;">
                Questions? Contact us at <a href="mailto:info@reuniapp.com" style="color: #22c55e; text-decoration: none;">info@reuniapp.com</a>
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
