import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createSecureResponse, createSecureErrorResponse, handleCorsPreFlight } from '../_shared/security-headers.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!

interface ListingConfirmationRequest {
  ticket_id: string
  user_id: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return handleCorsPreFlight()
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
    const { ticket_id, user_id } = await req.json() as ListingConfirmationRequest

    console.log('📧 Sending listing confirmation email...')
    console.log(`   Ticket ID: ${ticket_id}`)
    console.log(`   User ID: ${user_id}`)

    // Fetch ticket and user data
    const [ticketData, userData] = await Promise.all([
      supabase
        .from('user_tickets')
        .select('*')
        .eq('id', ticket_id)
        .single(),
      supabase
        .from('profiles')
        .select('email, username, full_name')
        .eq('id', user_id)
        .single()
    ])

    if (ticketData.error) {
      console.error('❌ Ticket not found:', ticketData.error)
      throw new Error('Ticket not found')
    }

    if (userData.error) {
      console.error('❌ User not found:', userData.error)
      throw new Error('User not found')
    }

    const ticket = ticketData.data
    const user = userData.data

    console.log('📋 Ticket details:', {
      event: ticket.event_name,
      type: ticket.ticket_type,
      quantity: ticket.quantity,
      price: ticket.price_per_ticket || ticket.total_price
    })

    console.log('👤 User details:', {
      email: user.email,
      username: user.username
    })

    // Format event date
    const eventDate = new Date(ticket.event_date).toLocaleDateString('en-GB', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })

    const pricePerTicket = ticket.price_per_ticket || (ticket.total_price / ticket.quantity)

    // Send listing confirmation email
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`
      },
      body: JSON.stringify({
        from: 'REUNI <noreply@support.reuniapp.com>',
        reply_to: 'info@support.reuniapp.com',
        to: user.email,
        subject: `✅ Your ticket is now listed: ${ticket.event_name}`,
        html: generateListingConfirmationEmail({
          sellerName: user.full_name || user.username,
          eventName: ticket.event_name,
          eventDate: eventDate,
          eventLocation: ticket.event_location,
          ticketType: ticket.ticket_type,
          quantity: ticket.quantity,
          pricePerTicket: pricePerTicket,
          totalPrice: ticket.total_price,
          ticketId: ticket_id,
          ticketSource: ticket.ticket_source || 'fatsoma'
        })
      })
    })

    if (!emailResponse.ok) {
      const error = await emailResponse.text()
      console.error('❌ Resend API error:', error)
      console.error('Response status:', emailResponse.status)
      console.error('Response status text:', emailResponse.statusText)
      throw new Error(`Resend API error (${emailResponse.status}): ${error}`)
    }

    const emailResult = await emailResponse.json()
    console.log('✅ Listing confirmation email sent successfully')
    console.log('   Email ID:', emailResult.id)

    return createSecureResponse({
      success: true,
      message: 'Listing confirmation email sent successfully',
      email_id: emailResult.id
    })

  } catch (error) {
    console.error('❌ Error sending listing confirmation:', error)
    console.error('Error details:', JSON.stringify(error, null, 2))
    return createSecureErrorResponse(
      `Failed to send listing confirmation: ${error.message || 'Unknown error'}`,
      500
    )
  }
})

// MARK: - Email Template

function generateListingConfirmationEmail(data: {
  sellerName: string
  eventName: string
  eventDate: string
  eventLocation: string
  ticketType: string
  quantity: number
  pricePerTicket: number
  totalPrice: number
  ticketId: string
  ticketSource: string
}): string {
  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Listing Confirmation</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f5f5;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f5f5; padding: 40px 20px;">
    <tr>
      <td align="center">
        <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">

          <!-- Header -->
          <tr>
            <td style="background: linear-gradient(135deg, #FF3B30 0%, #FF6B6B 100%); padding: 40px 40px 30px; border-radius: 12px 12px 0 0; text-align: center;">
              <h1 style="margin: 0; color: #ffffff; font-size: 32px; font-weight: 700;">🎉 Ticket Listed!</h1>
              <p style="margin: 10px 0 0; color: rgba(255,255,255,0.9); font-size: 16px;">Your ticket is now live on REUNI</p>
            </td>
          </tr>

          <!-- Greeting -->
          <tr>
            <td style="padding: 40px 40px 20px;">
              <p style="margin: 0; color: #333; font-size: 18px; line-height: 1.6;">Hi ${data.sellerName},</p>
              <p style="margin: 16px 0 0; color: #666; font-size: 16px; line-height: 1.6;">
                Your ticket for <strong style="color: #333;">${data.eventName}</strong> has been successfully listed on REUNI! 🎫
              </p>
            </td>
          </tr>

          <!-- Listing Details Card -->
          <tr>
            <td style="padding: 0 40px 24px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; border-radius: 8px; border-left: 4px solid #FF3B30;">
                <tr>
                  <td style="padding: 24px;">
                    <h2 style="margin: 0 0 16px; color: #333; font-size: 20px; font-weight: 600;">Listing Details</h2>

                    <table width="100%" cellpadding="8" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">🎭 Event:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventName}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">📅 Date:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventDate}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">📍 Location:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.eventLocation}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 14px; padding: 8px 0;">🎫 Ticket Type:</td>
                        <td style="color: #333; font-size: 14px; font-weight: 600; text-align: right; padding: 8px 0;">${data.ticketType}</td>
                      </tr>
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

          <!-- Pricing Details -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f0fdf4; border-radius: 8px; border-left: 4px solid #22c55e;">
                <tr>
                  <td style="padding: 24px;">
                    <h3 style="margin: 0 0 12px; color: #333; font-size: 18px; font-weight: 600;">💰 Pricing</h3>
                    <table width="100%" cellpadding="6" cellspacing="0">
                      <tr>
                        <td style="color: #666; font-size: 16px;">Price per ticket:</td>
                        <td style="color: #333; font-size: 18px; font-weight: 600; text-align: right;">£${data.pricePerTicket.toFixed(2)}</td>
                      </tr>
                      <tr>
                        <td style="color: #666; font-size: 16px; padding-top: 8px;">Total listing value:</td>
                        <td style="color: #22c55e; font-size: 20px; font-weight: 700; text-align: right; padding-top: 8px;">£${data.totalPrice.toFixed(2)}</td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- What Happens Next -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <h3 style="margin: 0 0 16px; color: #333; font-size: 18px; font-weight: 600;">📱 What Happens Next</h3>
              <ol style="margin: 0; padding-left: 20px; color: #666; font-size: 15px; line-height: 1.8;">
                <li>Your ticket is now visible to buyers on REUNI</li>
                <li>You'll receive notifications when someone views or makes an offer</li>
                <li>Once sold, funds will be held in escrow for 7 days</li>
                <li>After the escrow period, you'll receive payment to your Stripe account</li>
              </ol>
            </td>
          </tr>

          <!-- Seller Protection -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #eff6ff; border-radius: 8px; border-left: 4px solid #3b82f6;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 8px; color: #1e40af; font-size: 15px; font-weight: 600;">🛡️ Seller Protection</h4>
                    <p style="margin: 0; color: #1e40af; font-size: 13px; line-height: 1.6;">
                      Your payment is protected by our secure escrow system. Funds are held for 7 days after sale to protect both you and the buyer. Your Stripe account must remain active to receive payouts.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Tips for Sellers -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #fef3c7; border-radius: 8px; border-left: 4px solid #f59e0b;">
                <tr>
                  <td style="padding: 20px;">
                    <h4 style="margin: 0 0 12px; color: #92400e; font-size: 15px; font-weight: 600;">💡 Tips for Quick Sales</h4>
                    <ul style="margin: 0; padding-left: 20px; color: #92400e; font-size: 13px; line-height: 1.6;">
                      <li>Price competitively - check similar listings</li>
                      <li>Respond quickly to offers and messages</li>
                      <li>Keep your Stripe account verified and active</li>
                      <li>Be honest about ticket details and restrictions</li>
                    </ul>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Manage Listing -->
          <tr>
            <td style="padding: 0 40px 32px; text-align: center;">
              <p style="margin: 0 0 16px; color: #666; font-size: 14px;">
                Manage your listing anytime in the REUNI app
              </p>
              <table cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                <tr>
                  <td style="background: linear-gradient(135deg, #FF3B30 0%, #FF6B6B 100%); border-radius: 8px; padding: 14px 28px;">
                    <a href="reuni://tickets/my" style="color: #ffffff; text-decoration: none; font-size: 15px; font-weight: 600; display: inline-block;">
                      View My Listings
                    </a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Listing ID -->
          <tr>
            <td style="padding: 0 40px 32px;">
              <p style="margin: 0; color: #999; font-size: 12px; text-align: center;">
                Listing ID: <span style="font-family: monospace;">${data.ticketId}</span>
              </p>
            </td>
          </tr>

          <!-- Support -->
          <tr>
            <td style="padding: 0 40px 40px;">
              <p style="margin: 0; color: #666; font-size: 14px; text-align: center; line-height: 1.6;">
                Questions about your listing? Reply to this email for support.
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
