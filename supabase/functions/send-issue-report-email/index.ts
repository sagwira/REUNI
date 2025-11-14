// Send Issue Report Email to support@reuniapp.com
// Deno Edge Function for Supabase

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')

interface IssueReportEmail {
  issueReportId: string
  issueType: string
  additionalInfo: string
  reportedAt: string  // ISO timestamp when report was submitted
  reportLocation?: string  // Optional: City/location of user when reporting
  buyer: {
    username: string
    email: string
    university: string
  }
  seller: {
    username: string
    email: string
    university: string
  }
  ticket: {
    eventName: string
    eventDate: string
    eventLocation: string
    ticketType: string
  }
  transaction: {
    id: string
    amount: number
    buyerTotal: number
    platformFee: number
    createdAt: string
  }
  imageUrls: string[]
}

serve(async (req) => {
  try {
    const payload: IssueReportEmail = await req.json()

    console.log('📧 Sending issue report email:', payload.issueReportId)

    // Format the email HTML
    const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; }
    .content { background: #f9fafb; padding: 30px; }
    .section { background: white; padding: 20px; margin-bottom: 20px; border-radius: 8px; border-left: 4px solid #ef4444; }
    .label { font-weight: bold; color: #6b7280; font-size: 14px; text-transform: uppercase; }
    .value { color: #111827; font-size: 16px; margin-top: 5px; }
    .alert { background: #fee2e2; border: 1px solid #fca5a5; padding: 15px; border-radius: 6px; margin: 20px 0; }
    .footer { text-align: center; padding: 20px; color: #6b7280; font-size: 12px; }
    .btn { display: inline-block; padding: 12px 24px; background: #ef4444; color: white; text-decoration: none; border-radius: 6px; margin: 10px 0; }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 10px; border-bottom: 1px solid #e5e7eb; }
    .image-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; margin-top: 15px; }
    .image-grid img { width: 100%; height: 150px; object-fit: cover; border-radius: 6px; border: 2px solid #e5e7eb; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1 style="margin: 0;">🚨 New Ticket Issue Report</h1>
      <p style="margin: 10px 0 0 0; opacity: 0.9;">Report ID: ${payload.issueReportId}</p>
      <p style="margin: 5px 0 0 0; opacity: 0.85; font-size: 14px;">
        📅 Reported: ${new Date(payload.reportedAt).toLocaleString('en-GB', {
          weekday: 'short',
          year: 'numeric',
          month: 'short',
          day: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
          hour12: true
        })}
        ${payload.reportLocation ? ` | 📍 ${payload.reportLocation}` : ''}
      </p>
    </div>

    <div class="content">
      <div class="alert">
        <strong>⚠️ Action Required:</strong> A user has reported an issue with their ticket purchase. Please review and take appropriate action.
      </div>

      <!-- Report Metadata -->
      <div class="section" style="border-left-color: #6366f1;">
        <div class="label" style="color: #6366f1;">Report Timestamp & Location</div>
        <table>
          <tr>
            <td><strong>Reported At:</strong></td>
            <td>${new Date(payload.reportedAt).toLocaleString('en-GB', {
              weekday: 'long',
              year: 'numeric',
              month: 'long',
              day: 'numeric',
              hour: '2-digit',
              minute: '2-digit',
              second: '2-digit',
              hour12: true,
              timeZone: 'Europe/London'
            })}</td>
          </tr>
          <tr>
            <td><strong>Timezone:</strong></td>
            <td>UK (GMT/BST)</td>
          </tr>
          ${payload.reportLocation ? `
          <tr>
            <td><strong>User Location:</strong></td>
            <td>📍 ${payload.reportLocation}</td>
          </tr>
          ` : ''}
          <tr>
            <td><strong>Report ID:</strong></td>
            <td><code>${payload.issueReportId}</code></td>
          </tr>
        </table>
      </div>

      <!-- Issue Type -->
      <div class="section">
        <div class="label">Issue Type</div>
        <div class="value" style="color: #dc2626; font-size: 18px; font-weight: bold;">
          ${payload.issueType === 'Ticket Already Scanned' ? '🎫' : '⚠️'} ${payload.issueType}
        </div>
      </div>

      <!-- Buyer Information -->
      <div class="section">
        <div class="label">Buyer (Reporter)</div>
        <table>
          <tr>
            <td><strong>Username:</strong></td>
            <td>@${payload.buyer.username}</td>
          </tr>
          <tr>
            <td><strong>Email:</strong></td>
            <td><a href="mailto:${payload.buyer.email}">${payload.buyer.email}</a></td>
          </tr>
          <tr>
            <td><strong>University:</strong></td>
            <td>${payload.buyer.university}</td>
          </tr>
        </table>
      </div>

      <!-- Seller Information -->
      <div class="section">
        <div class="label">Seller</div>
        <table>
          <tr>
            <td><strong>Username:</strong></td>
            <td>@${payload.seller.username}</td>
          </tr>
          <tr>
            <td><strong>Email:</strong></td>
            <td><a href="mailto:${payload.seller.email}">${payload.seller.email}</a></td>
          </tr>
          <tr>
            <td><strong>University:</strong></td>
            <td>${payload.seller.university}</td>
          </tr>
        </table>
      </div>

      <!-- Ticket Information -->
      <div class="section">
        <div class="label">Ticket Details</div>
        <table>
          <tr>
            <td><strong>Event:</strong></td>
            <td>${payload.ticket.eventName}</td>
          </tr>
          <tr>
            <td><strong>Date:</strong></td>
            <td>${payload.ticket.eventDate}</td>
          </tr>
          <tr>
            <td><strong>Location:</strong></td>
            <td>${payload.ticket.eventLocation}</td>
          </tr>
          <tr>
            <td><strong>Ticket Type:</strong></td>
            <td>${payload.ticket.ticketType}</td>
          </tr>
        </table>
      </div>

      <!-- Transaction Information -->
      <div class="section">
        <div class="label">Transaction Details</div>
        <table>
          <tr>
            <td><strong>Transaction ID:</strong></td>
            <td><code>${payload.transaction.id}</code></td>
          </tr>
          <tr>
            <td><strong>Seller Amount:</strong></td>
            <td>£${payload.transaction.amount.toFixed(2)}</td>
          </tr>
          <tr>
            <td><strong>Platform Fee:</strong></td>
            <td>£${payload.transaction.platformFee.toFixed(2)}</td>
          </tr>
          <tr>
            <td><strong>Buyer Total:</strong></td>
            <td style="font-weight: bold; font-size: 18px;">£${payload.transaction.buyerTotal.toFixed(2)}</td>
          </tr>
          <tr>
            <td><strong>Purchase Date:</strong></td>
            <td>${new Date(payload.transaction.createdAt).toLocaleString('en-GB')}</td>
          </tr>
        </table>
      </div>

      <!-- Additional Information -->
      ${payload.additionalInfo ? `
      <div class="section">
        <div class="label">Additional Information from Buyer</div>
        <div class="value" style="white-space: pre-wrap; font-style: italic; background: #f3f4f6; padding: 15px; border-radius: 6px; margin-top: 10px;">
          "${payload.additionalInfo}"
        </div>
      </div>
      ` : ''}

      <!-- Evidence Attachments -->
      ${payload.imageUrls && payload.imageUrls.length > 0 ? `
      <div class="section">
        <div class="label">Evidence Attached (${payload.imageUrls.length} ${payload.imageUrls.length === 1 ? 'image' : 'images'})</div>
        <div class="image-grid">
          ${payload.imageUrls.map(url => `
            <a href="${url}" target="_blank">
              <img src="${url}" alt="Evidence" />
            </a>
          `).join('')}
        </div>
        <p style="margin-top: 15px; font-size: 13px; color: #6b7280;">
          Click images to view full size
        </p>
      </div>
      ` : ''}

      <!-- Next Steps -->
      <div class="section" style="border-left-color: #3b82f6;">
        <div class="label" style="color: #3b82f6;">Recommended Next Steps</div>
        <ol style="margin: 15px 0; padding-left: 20px;">
          <li>Review the issue type and evidence provided</li>
          <li>Contact the buyer for additional verification if needed</li>
          <li>Contact the seller to investigate the claim</li>
          <li>Check transaction and ticket history in admin dashboard</li>
          <li>Determine if refund is warranted</li>
          <li>Update issue status in Supabase (pending → under_review → approved/rejected)</li>
        </ol>
      </div>

      <!-- Action Buttons -->
      <div style="text-align: center; margin: 30px 0;">
        <a href="https://app.supabase.com/project/${Deno.env.get('SUPABASE_PROJECT_ID')}/editor" class="btn">
          View in Supabase Dashboard
        </a>
      </div>
    </div>

    <div class="footer">
      <p>This is an automated email from REUNI Issue Report System</p>
      <p>Report ID: ${payload.issueReportId}</p>
      <p>Reported: ${new Date(payload.reportedAt).toLocaleString('en-GB', {
        dateStyle: 'full',
        timeStyle: 'long',
        timeZone: 'Europe/London'
      })}</p>
      ${payload.reportLocation ? `<p>Location: ${payload.reportLocation}</p>` : ''}
    </div>
  </div>
</body>
</html>
    `

    // Send email via Resend
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${RESEND_API_KEY}`,
      },
      body: JSON.stringify({
        from: 'REUNI Support <onboarding@resend.dev>',
        to: ['shaun.gwira@reuniapp.com'], // Using your verified email for testing
        subject: `🚨 New Issue Report: ${payload.issueType} - ${payload.ticket.eventName}`,
        html: emailHtml,
      }),
    })

    if (!res.ok) {
      const error = await res.text()
      throw new Error(`Failed to send email: ${error}`)
    }

    const data = await res.json()
    console.log('✅ Email sent successfully:', data)

    return new Response(
      JSON.stringify({ success: true, emailId: data.id }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error sending issue report email:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    )
  }
})
