// Send email receipts to BOTH buyer and seller after successful ticket purchase
// Buyer gets: Receipt + Ticket screenshot attachment
// Seller gets: Sale notification with payout details
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

    console.log(`📧 Sending purchase receipts for transaction ${transaction_id}`);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // 1. Fetch buyer email
    const { data: { user: buyer }, error: buyerError } = await supabase.auth.admin.getUserById(buyer_id);
    if (buyerError || !buyer?.email) {
      console.error("Failed to fetch buyer email:", buyerError);
      return new Response(JSON.stringify({ error: "Buyer email not found" }), { status: 400 });
    }
    const buyerEmail = buyer.email;

    // 2. Fetch ticket details
    const { data: ticket, error: ticketError } = await supabase
      .from("user_tickets")
      .select("*")
      .eq("id", ticket_id)
      .single();

    if (ticketError || !ticket) {
      console.error("Failed to fetch ticket:", ticketError);
      return new Response(JSON.stringify({ error: "Ticket not found" }), { status: 400 });
    }

    // 3. Fetch seller email
    const sellerId = ticket.purchased_from_seller_id;
    const { data: { user: seller }, error: sellerError } = await supabase.auth.admin.getUserById(sellerId);
    const sellerEmail = seller?.email;
    console.log(`📬 Buyer: ${buyerEmail}, Seller: ${sellerEmail || "N/A"}`);

    // 4. Fetch transaction details
    const { data: transaction, error: transactionError } = await supabase
      .from("transactions")
      .select("*")
      .eq("id", transaction_id)
      .single();

    if (transactionError || !transaction) {
      console.error("Failed to fetch transaction:", transactionError);
      return new Response(JSON.stringify({ error: "Transaction not found" }), { status: 400 });
    }

    // 5. Extract data
    const eventName = ticket.event_name || "Event";
    const eventLocation = ticket.event_location || "TBA";
    const eventDate = ticket.event_date ? new Date(ticket.event_date).toLocaleDateString("en-GB", {
      weekday: "long", year: "numeric", month: "long", day: "numeric", hour: "2-digit", minute: "2-digit",
    }) : "TBA";
    const ticketType = ticket.ticket_type || "General Admission";
    const sellerUsername = ticket.seller_username || "Unknown Seller";
    const sellerUniversity = ticket.seller_university || "";
    const buyerUsername = buyer.user_metadata?.username || "Buyer";

    const ticketPrice = transaction.ticket_price || 0;
    const platformFee = transaction.platform_fee || 0;
    const sellerPayout = transaction.seller_payout || ticketPrice;
    const buyerTotal = transaction.buyer_total || (ticketPrice + platformFee);

    // 6. Download ticket screenshot (if available) for buyer email attachment
    let ticketScreenshotBase64: string | null = null;
    if (ticket.ticket_screenshot_url) {
      try {
        const screenshotResponse = await fetch(ticket.ticket_screenshot_url);
        if (screenshotResponse.ok) {
          const arrayBuffer = await screenshotResponse.arrayBuffer();
          const uint8Array = new Uint8Array(arrayBuffer);
          // Convert to base64
          let binary = '';
          uint8Array.forEach((byte) => binary += String.fromCharCode(byte));
          ticketScreenshotBase64 = btoa(binary);
          console.log("✅ Ticket screenshot downloaded for attachment");
        }
      } catch (error) {
        console.error("⚠️ Failed to download ticket screenshot:", error);
      }
    }

    if (!RESEND_API_KEY) {
      console.warn("⚠️ RESEND_API_KEY not set - skipping email send");
      return new Response(JSON.stringify({ success: true, message: "Email send skipped (no API key)" }), { status: 200 });
    }

    // ========================================
    // 7. BUYER EMAIL (Receipt + Ticket Attachment)
    // ========================================

    const buyerEmailBody = JSON.stringify({
      from: "REUNI <receipts@reuni.com>",
      to: [buyerEmail],
      subject: `Your ticket for ${eventName} - Order #${transaction_id.substring(0, 8)}`,
      html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; background-color: #f5f5f5; }
    .container { background-color: #ffffff; margin: 20px 0; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%); color: white; padding: 32px 24px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 600; }
    .content { padding: 32px 24px; }
    .section { margin-bottom: 32px; }
    .section h2 { font-size: 18px; font-weight: 600; margin: 0 0 16px 0; }
    .event-details { background-color: #f8f9fa; border: 1px solid #e9ecef; border-radius: 8px; padding: 20px; }
    .event-details h3 { margin: 0 0 12px 0; font-size: 20px; }
    .detail-row { display: flex; align-items: center; margin-bottom: 8px; font-size: 14px; }
    .detail-icon { width: 20px; margin-right: 8px; }
    .price-table { width: 100%; border-collapse: collapse; font-size: 14px; }
    .price-table tr { border-bottom: 1px solid #e9ecef; }
    .price-table td { padding: 12px 0; }
    .price-table td:last-child { text-align: right; }
    .total-row { font-weight: 600; font-size: 18px; }
    .notice { background-color: #eff6ff; border-left: 4px solid #3b82f6; padding: 16px; border-radius: 4px; margin: 24px 0; }
    .notice strong { display: block; margin-bottom: 4px; }
    .cta-button { display: inline-block; background-color: #6366f1; color: white; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: 600; }
    .footer { background-color: #f8f9fa; padding: 24px; text-align: center; font-size: 12px; color: #6c757d; border-top: 1px solid #e9ecef; }
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
          <div class="detail-row"><span class="detail-icon">📍</span><span>${eventLocation}</span></div>
          <div class="detail-row"><span class="detail-icon">📅</span><span>${eventDate}</span></div>
          <div class="detail-row"><span class="detail-icon">🎫</span><span>${ticketType}</span></div>
        </div>
      </div>
      <div class="section">
        <h2>Purchase Summary</h2>
        <table class="price-table">
          <tr><td>Ticket Price:</td><td>£${ticketPrice.toFixed(2)}</td></tr>
          <tr><td>Service Fee:</td><td>£${platformFee.toFixed(2)}</td></tr>
          <tr class="total-row"><td>Total Paid:</td><td>£${buyerTotal.toFixed(2)}</td></tr>
        </table>
      </div>
      <div class="notice">
        <strong>⚠️ Important</strong>
        <p>Your ticket screenshot is ${ticketScreenshotBase64 ? "attached to this email" : "available in the REUNI app"}. Present the barcode at the event entrance for entry.</p>
      </div>
      <center><a href="reuni://ticket/${ticket_id}" class="cta-button">View in REUNI App</a></center>
      <div class="footer">
        <p><strong>Questions?</strong> Contact support@reuni.com</p>
        <p>© 2025 REUNI. All rights reserved.</p>
      </div>
    </div>
  </div>
</body>
</html>
      `,
      attachments: ticketScreenshotBase64 ? [{
        filename: `${eventName.replace(/[^a-z0-9]/gi, '_')}_ticket.png`,
        content: ticketScreenshotBase64,
      }] : [],
      tags: [
        { name: "category", value: "purchase_receipt" },
        { name: "transaction_id", value: transaction_id },
      ],
    });

    const buyerEmailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
      body: buyerEmailBody,
    });

    const buyerEmailResult = await buyerEmailResponse.json();
    if (!buyerEmailResponse.ok) {
      console.error("Failed to send buyer email:", buyerEmailResult);
      return new Response(JSON.stringify({ error: "Failed to send buyer email" }), { status: 500 });
    }

    console.log(`✅ Buyer email sent! ID: ${buyerEmailResult.id}`);

    // Log buyer email
    await supabase.from("purchase_emails").insert({
      transaction_id, buyer_id, buyer_email: buyerEmail,
      email_provider: "resend", email_status: "sent", email_id: buyerEmailResult.id,
    });

    // ========================================
    // 8. SELLER EMAIL (Sale Notification)
    // ========================================

    let sellerEmailResult: any = null;
    if (sellerEmail) {
      const sellerEmailBody = JSON.stringify({
        from: "REUNI <sales@reuni.com>",
        to: [sellerEmail],
        subject: `Ticket Sold! ${eventName} - £${sellerPayout.toFixed(2)} payout`,
        html: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; background-color: #f5f5f5; }
    .container { background-color: #ffffff; margin: 20px 0; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
    .header { background: linear-gradient(135deg, #10b981 0%, #059669 100%); color: white; padding: 32px 24px; text-align: center; }
    .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 600; }
    .content { padding: 32px 24px; }
    .section { margin-bottom: 32px; }
    .section h2 { font-size: 18px; font-weight: 600; margin: 0 0 16px 0; }
    .payout-box { background-color: #f0fdf4; border: 2px solid #10b981; border-radius: 8px; padding: 20px; text-align: center; margin: 24px 0; }
    .payout-box h3 { margin: 0 0 8px 0; font-size: 32px; color: #10b981; font-weight: 700; }
    .payout-box p { margin: 0; color: #059669; font-size: 14px; }
    .price-table { width: 100%; border-collapse: collapse; font-size: 14px; }
    .price-table tr { border-bottom: 1px solid #e9ecef; }
    .price-table td { padding: 12px 0; }
    .price-table td:last-child { text-align: right; }
    .notice { background-color: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; border-radius: 4px; margin: 24px 0; }
    .notice strong { display: block; margin-bottom: 4px; color: #92400e; }
    .notice p { margin: 0; font-size: 14px; color: #78350f; }
    .footer { background-color: #f8f9fa; padding: 24px; text-align: center; font-size: 12px; color: #6c757d; border-top: 1px solid #e9ecef; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>💰 Ticket Sold!</h1>
      <p>Sale #${transaction_id.substring(0, 8)}</p>
    </div>
    <div class="content">
      <div class="payout-box">
        <h3>£${sellerPayout.toFixed(2)}</h3>
        <p>Your payout (arriving in 2-7 days)</p>
      </div>
      <div class="section">
        <h2>Sale Details</h2>
        <table class="price-table">
          <tr><td><strong>Event:</strong></td><td>${eventName}</td></tr>
          <tr><td><strong>Sold to:</strong></td><td>@${buyerUsername}</td></tr>
          <tr><td><strong>Ticket Price:</strong></td><td>£${ticketPrice.toFixed(2)}</td></tr>
          <tr><td><strong>Platform Fee (10%):</strong></td><td>-£${platformFee.toFixed(2)}</td></tr>
          <tr style="font-weight: 600; border-top: 2px solid #10b981;"><td>Your Payout:</td><td style="color: #10b981;">£${sellerPayout.toFixed(2)}</td></tr>
        </table>
      </div>
      <div class="notice">
        <strong>⚠️ Important</strong>
        <p>The buyer has received your ticket screenshot. Funds will be transferred to your bank account within 2-7 business days via Stripe.</p>
      </div>
      <div class="footer">
        <p><strong>Questions?</strong> Contact support@reuni.com</p>
        <p>© 2025 REUNI. All rights reserved.</p>
      </div>
    </div>
  </div>
</body>
</html>
        `,
        tags: [
          { name: "category", value: "seller_notification" },
          { name: "transaction_id", value: transaction_id },
        ],
      });

      const sellerEmailResponse = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: { "Authorization": `Bearer ${RESEND_API_KEY}`, "Content-Type": "application/json" },
        body: sellerEmailBody,
      });

      sellerEmailResult = await sellerEmailResponse.json();
      if (!sellerEmailResponse.ok) {
        console.error("⚠️ Failed to send seller email:", sellerEmailResult);
        // Don't fail the function - buyer email is more important
      } else {
        console.log(`✅ Seller email sent! ID: ${sellerEmailResult.id}`);

        // Log seller email
        await supabase.from("purchase_emails").insert({
          transaction_id, buyer_id: sellerId, buyer_email: sellerEmail,
          email_provider: "resend", email_status: "sent", email_id: sellerEmailResult.id,
        });
      }
    }

    return new Response(JSON.stringify({
      success: true,
      buyer_email_id: buyerEmailResult.id,
      seller_email_id: sellerEmailResult?.id || null,
      ticket_attached: ticketScreenshotBase64 !== null,
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("Error in send-purchase-receipt:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
