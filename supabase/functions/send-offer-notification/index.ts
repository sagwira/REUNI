import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createSecureResponse, createSecureErrorResponse, handleCorsPreFlight } from '../_shared/security-headers.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

interface OfferNotificationRequest {
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
    const { offer_id, ticket_id, buyer_id, seller_id } = await req.json() as OfferNotificationRequest

    console.log('📧 Sending offer notification email...')
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

    // Format expiry date
    const expiryDate = new Date(offer.expires_at).toLocaleDateString('en-GB', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    })

    // Send notification to seller
    const sellerEmailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'REUNI <offers@reuniapp.com>',
        reply_to: 'info@reuniapp.com',
        to: seller.email,
        subject: `💰 New offer for ${ticket.event_name}`,
        html: generateSellerNotificationEmail({
          sellerName: seller.full_name || seller.username,
          buyerUsername: buyer.username,
          eventName: ticket.event_name,
          originalPrice: ticket.price_per_ticket,
          offerPrice: offer.offer_price,
          quantity: offer.quantity,
          expiryDate: expiryDate,
          message: offer.message
        })
      })
    })

    if (!sellerEmailResponse.ok) {
      const error = await sellerEmailResponse.text()
      console.error('❌ Failed to send seller notification:', error)
      throw new Error('Failed to send offer notification email')
    }

    console.log('✅ Offer notification email sent')

    return createSecureResponse({
      success: true,
      message: 'Offer notification sent successfully'
    })

  } catch (error) {
    console.error('❌ Error sending offer notification:', error)
    return createSecureErrorResponse(error.message || 'Failed to send offer notification', 500)
  }
})

function generateSellerNotificationEmail(data: {
  sellerName: string
  buyerUsername: string
  eventName: string
  originalPrice: number
  offerPrice: number
  quantity: number
  expiryDate: string
  message: string | null
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>New Offer Received</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%); padding: 40px 40px 30px; border-radius: 12px 12px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">💰 New Offer!</h1>
              <p style="margin: 10px 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Someone wants to buy your ticket</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 40px 40px 20px;">
              <p style="margin: 0; color: #333; font-size: 18px; line-height: 1.6;">Hi ${data.sellerName},</p>
              <p style="margin: 16px 0 0; color: #666; font-size: 16px; line-height: 1.6;">
                Great news! <strong>@${data.buyerUsername}</strong> has made an offer on your ticket for <strong style="color: #333;">${data.eventName}</strong>.
              </p>
            </td>
          </tr>

          <!-- Offer Details -->
          <tr>
            <td style="padding: 0 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 8px; border-left: 4px solid #8b5cf6;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; color: #333; font-size: 20px; font-weight: 600;">Offer Details</h2>

                    <table width="100%" cellpadding="8" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">From:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">@${data.buyerUsername}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">Your Listing Price:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">£${data.originalPrice.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 16px; padding: 12px 0 8px;">Offer Price:</td>
                        <td style="color: #8b5cf6; font-size: 20px; font-weight: 700; text-align: right; padding: 12px 0 8px;">£${data.offerPrice.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">Quantity:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.quantity}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 13px; padding: 8px 0 0;">Offer Expires:</td>
                        <td style="color: #f59e0b; font-size: 13px; font-weight: 600; text-align: right; padding: 8px 0 0;">${data.expiryDate}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          ${data.message ? `
          <!-- Buyer's Message -->
          <tr>
            <td style="padding: 24px 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #eff6ff; border-radius: 8px; border-left: 4px solid #3b82f6;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #1e40af; font-size: 15px; font-weight: 600;">💬 Message from Buyer:</h4>
                    <p style="margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;">
                      "${data.message}"
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          ` : ''}

          <!-- CTA -->
          <tr>
            <td style="padding: 0 40px 32px; text-align: center;">
              <p style="margin: 0 0 20px; color: #666; font-size: 15px;">
                Open the REUNI app to accept or decline this offer.
              </p>
              <a href="reuni://offers" style="display: inline-block; background: linear-gradient(135deg, #8b5cf6 0%, #7c3aed 100%); color: #ffffff; text-decoration: none; padding: 16px 48px; border-radius: 8px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);">
                View Offer in App
              </a>
            </td>
          </tr>

          <!-- Tips -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">💡 Quick Tips</h3>
              <ul style="margin: 0; padding-left: 20px; color: #666; font-size: 15px; line-height: 1.8;">
                <li>Offers expire after 12 hours automatically</li>
                <li>You can accept, decline, or counter the offer</li>
                <li>Accepting locks the ticket for this buyer</li>
                <li>Payment is held in escrow for your protection</li>
              </ul>
            </td>
          </tr>

          <!-- Support -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <p style="margin: 0; color: #666; font-size: 14px; text-align: center; line-height: 1.6;">
                Questions? Contact us at <a href="mailto:info@reuniapp.com" style="color: #8b5cf6; text-decoration: none;">info@reuniapp.com</a>
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
