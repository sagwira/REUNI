// Send email receipt to buyer after successful ticket purchase
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface PurchaseReceiptRequest {
  transaction_id: string;
  buyer_id: string;
  ticket_id: string;
}

serve(async (req) => {
  try {
    const { transaction_id, buyer_id, ticket_id }: PurchaseReceiptRequest = await req.json();

    console.log(`📧 Sending purchase receipt for transaction ${transaction_id}`);

    // Create Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // 1. Fetch buyer email from auth.users
    const { data: { user: buyer }, error: buyerError } = await supabase.auth.admin.getUserById(buyer_id);

    if (buyerError || !buyer?.email) {
      console.error("Failed to fetch buyer email:", buyerError);
      return new Response(JSON.stringify({ error: "Buyer email not found" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const buyerEmail = buyer.email;
    console.log(`📬 Buyer email: ${buyerEmail}`);

    // 2. Fetch ticket details
    const { data: ticket, error: ticketError } = await supabase
      .from("user_tickets")
      .select("*")
      .eq("id", ticket_id)
      .single();

    if (ticketError || !ticket) {
      console.error("Failed to fetch ticket:", ticketError);
      return new Response(JSON.stringify({ error: "Ticket not found" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 2b. Fetch seller email
    const sellerId = ticket.purchased_from_seller_id;
    if (!sellerId) {
      console.error("No seller ID found on ticket");
      return new Response(JSON.stringify({ error: "Seller not found" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: { user: seller }, error: sellerError } = await supabase.auth.admin.getUserById(sellerId);

    if (sellerError || !seller?.email) {
      console.error("Failed to fetch seller email:", sellerError);
      // Don't fail the whole function - buyer email is more important
    }

    const sellerEmail = seller?.email;
    console.log(`📬 Seller email: ${sellerEmail || "N/A"}`);

    // 3. Fetch transaction details
    const { data: transaction, error: transactionError } = await supabase
      .from("transactions")
      .select("*")
      .eq("id", transaction_id)
      .single();

    if (transactionError || !transaction) {
      console.error("Failed to fetch transaction:", transactionError);
      return new Response(JSON.stringify({ error: "Transaction not found" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 4. Format data for email
    const eventName = ticket.event_name || "Event";
    const eventLocation = ticket.event_location || "TBA";
    const eventDate = ticket.event_date ? new Date(ticket.event_date).toLocaleDateString("en-GB", {
      weekday: "long",
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }) : "TBA";
    const ticketType = ticket.ticket_type || "General Admission";
    const sellerUsername = ticket.seller_username || "Unknown Seller";
    const sellerUniversity = ticket.seller_university || "";

    const ticketPrice = transaction.ticket_price || 0;
    const platformFee = transaction.platform_fee || 0;
    const totalPaid = transaction.buyer_total || (ticketPrice + platformFee);

    // 5. Generate HTML email
    const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      max-width: 600px;
      margin: 0 auto;
      background-color: #f5f5f5;
    }
    .container {
      background-color: #ffffff;
      margin: 20px 0;
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .header {
      background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%);
      color: white;
      padding: 32px 24px;
      text-align: center;
    }
    .header h1 {
      margin: 0 0 8px 0;
      font-size: 28px;
      font-weight: 600;
    }
    .header p {
      margin: 0;
      opacity: 0.9;
      font-size: 14px;
    }
    .content {
      padding: 32px 24px;
    }
    .section {
      margin-bottom: 32px;
    }
    .section h2 {
      font-size: 18px;
      font-weight: 600;
      margin: 0 0 16px 0;
      color: #111;
    }
    .event-details {
      background-color: #f8f9fa;
      border: 1px solid #e9ecef;
      border-radius: 8px;
      padding: 20px;
      margin-bottom: 16px;
    }
    .event-details h3 {
      margin: 0 0 12px 0;
      font-size: 20px;
      color: #111;
    }
    .detail-row {
      display: flex;
      align-items: center;
      margin-bottom: 8px;
      font-size: 14px;
    }
    .detail-row:last-child {
      margin-bottom: 0;
    }
    .detail-icon {
      width: 20px;
      margin-right: 8px;
      color: #6366f1;
    }
    .price-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 14px;
    }
    .price-table tr {
      border-bottom: 1px solid #e9ecef;
    }
    .price-table tr:last-child {
      border-bottom: none;
    }
    .price-table td {
      padding: 12px 0;
    }
    .price-table td:last-child {
      text-align: right;
    }
    .total-row {
      font-weight: 600;
      font-size: 18px;
      color: #111;
    }
    .seller-info {
      background-color: #f8f9fa;
      border-radius: 8px;
      padding: 16px;
      font-size: 14px;
    }
    .cta-button {
      display: inline-block;
      background-color: #6366f1;
      color: white;
      text-decoration: none;
      padding: 14px 28px;
      border-radius: 8px;
      font-weight: 600;
      text-align: center;
      margin: 24px 0;
    }
    .notice {
      background-color: #eff6ff;
      border-left: 4px solid #3b82f6;
      padding: 16px;
      border-radius: 4px;
      margin: 24px 0;
    }
    .notice p {
      margin: 0;
      font-size: 14px;
      color: #1e40af;
    }
    .notice strong {
      display: block;
      margin-bottom: 4px;
      font-size: 15px;
    }
    .footer {
      background-color: #f8f9fa;
      padding: 24px;
      text-align: center;
      font-size: 12px;
      color: #6c757d;
      border-top: 1px solid #e9ecef;
    }
    .footer p {
      margin: 8px 0;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>🎉 Your Ticket is Ready!</h1>
      <p>Order #${transaction_id.substring(0, 8)}</p>
    </div>

    <div class="content">
      <div class="section">
        <h2>Event Details</h2>
        <div class="event-details">
          <h3>${eventName}</h3>
          <div class="detail-row">
            <span class="detail-icon">📍</span>
            <span>${eventLocation}</span>
          </div>
          <div class="detail-row">
            <span class="detail-icon">📅</span>
            <span>${eventDate}</span>
          </div>
          <div class="detail-row">
            <span class="detail-icon">🎫</span>
            <span>${ticketType}</span>
          </div>
        </div>
      </div>

      <div class="section">
        <h2>Purchase Summary</h2>
        <table class="price-table">
          <tr>
            <td>Ticket Price:</td>
            <td>£${ticketPrice.toFixed(2)}</td>
          </tr>
          <tr>
            <td>Service Fee (10%):</td>
            <td>£${platformFee.toFixed(2)}</td>
          </tr>
          <tr class="total-row">
            <td>Total Paid:</td>
            <td>£${totalPaid.toFixed(2)}</td>
          </tr>
        </table>
      </div>

      <div class="section">
        <h2>Seller Information</h2>
        <div class="seller-info">
          <p><strong>Purchased from:</strong> @${sellerUsername}</p>
          ${sellerUniversity ? `<p><strong>University:</strong> ${sellerUniversity}</p>` : ""}
        </div>
      </div>

      <div class="notice">
        <strong>⚠️ Important</strong>
        <p>Your ticket is now available in the REUNI app under "My Purchases". Present the ticket barcode at the event entrance for entry.</p>
      </div>

      <center>
        <a href="reuni://ticket/${ticket_id}" class="cta-button">View Ticket in REUNI App</a>
      </center>

      <div class="footer">
        <p><strong>Questions or issues?</strong></p>
        <p>Contact support at support@reuni.com</p>
        <p style="margin-top: 16px;">This is an automated receipt from REUNI marketplace.</p>
        <p>© 2025 REUNI. All rights reserved.</p>
      </div>
    </div>
  </div>
</body>
</html>
    `;

    // 6. Send email via Resend
    if (!RESEND_API_KEY) {
      console.warn("⚠️ RESEND_API_KEY not set - skipping email send");
      return new Response(JSON.stringify({
        success: true,
        message: "Email send skipped (no API key)",
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "REUNI <receipts@reuni.com>",
        to: [buyerEmail],
        subject: `Your ticket for ${eventName} - Order #${transaction_id.substring(0, 8)}`,
        html: emailHtml,
        tags: [
          { name: "category", value: "purchase_receipt" },
          { name: "transaction_id", value: transaction_id },
        ],
      }),
    });

    const emailResult = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error("Failed to send email via Resend:", emailResult);
      return new Response(JSON.stringify({ error: "Failed to send email", details: emailResult }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`✅ Email sent successfully! Email ID: ${emailResult.id}`);

    // 7. Log email in database
    const { error: logError } = await supabase
      .from("purchase_emails")
      .insert({
        transaction_id: transaction_id,
        buyer_id: buyer_id,
        buyer_email: buyerEmail,
        email_provider: "resend",
        email_status: "sent",
        email_id: emailResult.id,
      });

    if (logError) {
      console.error("Failed to log email:", logError);
    }

    return new Response(JSON.stringify({
      success: true,
      email_id: emailResult.id,
      sent_to: buyerEmail,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Error in send-purchase-receipt:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
