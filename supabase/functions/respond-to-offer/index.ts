// Seller responds to a ticket offer (accept or decline)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface RespondToOfferRequest {
  offer_id: string;
  action: "accept" | "decline";
}

serve(async (req) => {
  try {
    // Get authenticated user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), { status: 401 });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Verify JWT and get user
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }

    const sellerId = user.id;

    // Parse request body
    const { offer_id, action }: RespondToOfferRequest = await req.json();

    if (!["accept", "decline"].includes(action)) {
      return new Response(JSON.stringify({ error: "Invalid action. Must be 'accept' or 'decline'" }), { status: 400 });
    }

    console.log(`📝 Seller ${sellerId} ${action}ing offer ${offer_id}`);

    // 1. Fetch offer details
    const { data: offer, error: offerError } = await supabase
      .from("ticket_offers")
      .select("*")
      .eq("id", offer_id)
      .single();

    if (offerError || !offer) {
      console.error("Offer not found:", offerError);
      return new Response(JSON.stringify({ error: "Offer not found" }), { status: 404 });
    }

    // 2. Verify seller owns this offer
    if (offer.seller_id.toUpperCase() !== sellerId.toUpperCase()) {
      return new Response(JSON.stringify({ error: "You are not authorized to respond to this offer" }), { status: 403 });
    }

    // 3. Check if offer is still pending
    if (offer.status !== "pending") {
      return new Response(JSON.stringify({
        error: `This offer has already been ${offer.status}`,
      }), { status: 400 });
    }

    // 4. Check if offer has expired
    if (new Date(offer.expires_at) < new Date()) {
      // Mark as expired
      await supabase
        .from("ticket_offers")
        .update({ status: "expired" })
        .eq("id", offer_id);

      return new Response(JSON.stringify({ error: "This offer has expired" }), { status: 400 });
    }

    // 5. Fetch ticket to verify it's still available
    const { data: ticket, error: ticketError } = await supabase
      .from("user_tickets")
      .select("*")
      .eq("id", offer.ticket_id)
      .single();

    if (ticketError || !ticket) {
      return new Response(JSON.stringify({ error: "Ticket not found" }), { status: 404 });
    }

    if (ticket.sale_status !== "available") {
      return new Response(JSON.stringify({ error: "Ticket is no longer available" }), { status: 400 });
    }

    // 6. Handle ACCEPT
    if (action === "accept") {
      console.log(`✅ Accepting offer ${offer_id} for £${offer.offer_amount}`);

      // Update offer status
      const { error: updateOfferError } = await supabase
        .from("ticket_offers")
        .update({
          status: "accepted",
          accepted_at: new Date().toISOString(),
        })
        .eq("id", offer_id);

      if (updateOfferError) {
        console.error("Failed to update offer:", updateOfferError);
        return new Response(JSON.stringify({ error: "Failed to accept offer" }), { status: 500 });
      }

      // Reserve ticket for buyer (24 hours to pay)
      console.log(`🔄 Attempting to reserve ticket ${offer.ticket_id} for buyer ${offer.buyer_id}`);

      const { data: updatedTicket, error: updateTicketError } = await supabase
        .from("user_tickets")
        .update({
          sale_status: "pending_payment",
          buyer_id: offer.buyer_id,
          // Store the offer ID and buyer ID for payment processing
        })
        .eq("id", offer.ticket_id)
        .select()
        .single();

      if (updateTicketError) {
        console.error("Failed to reserve ticket - Error details:", JSON.stringify(updateTicketError));
        console.error("Ticket ID:", offer.ticket_id);
        console.error("Buyer ID:", offer.buyer_id);

        // Rollback offer acceptance
        await supabase
          .from("ticket_offers")
          .update({ status: "pending" })
          .eq("id", offer_id);

        return new Response(JSON.stringify({
          error: "Failed to reserve ticket",
          details: updateTicketError.message,
          hint: updateTicketError.hint,
        }), { status: 500 });
      }

      console.log(`✅ Ticket reserved successfully:`, updatedTicket);

      // Decline all other pending offers on this ticket
      await supabase
        .from("ticket_offers")
        .update({ status: "declined", declined_at: new Date().toISOString() })
        .eq("ticket_id", offer.ticket_id)
        .eq("status", "pending")
        .neq("id", offer_id);

      // TODO: Send push notification to buyer
      // await sendPushNotification(offer.buyer_id, {
      //   type: "offer_accepted",
      //   title: "✅ Your Offer Was Accepted!",
      //   body: `Pay £${offer.offer_amount} within 24 hours to secure your ticket`,
      //   data: { offer_id, ticket_id: offer.ticket_id },
      // });

      console.log(`✅ Offer accepted successfully! Buyer has 24 hours to pay.`);

      return new Response(JSON.stringify({
        success: true,
        message: "Offer accepted! The buyer has 24 hours to complete payment.",
        offer: {
          ...offer,
          status: "accepted",
          accepted_at: new Date().toISOString(),
        },
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // 7. Handle DECLINE
    if (action === "decline") {
      console.log(`❌ Declining offer ${offer_id}`);

      const { error: updateError } = await supabase
        .from("ticket_offers")
        .update({
          status: "declined",
          declined_at: new Date().toISOString(),
        })
        .eq("id", offer_id);

      if (updateError) {
        console.error("Failed to decline offer:", updateError);
        return new Response(JSON.stringify({ error: "Failed to decline offer" }), { status: 500 });
      }

      // TODO: Send push notification to buyer
      // await sendPushNotification(offer.buyer_id, {
      //   type: "offer_declined",
      //   title: "Offer Declined",
      //   body: `Your £${offer.offer_amount} offer for ${ticket.event_name} was declined`,
      // });

      console.log(`✅ Offer declined successfully`);

      return new Response(JSON.stringify({
        success: true,
        message: "Offer declined.",
        offer: {
          ...offer,
          status: "declined",
          declined_at: new Date().toISOString(),
        },
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

  } catch (error) {
    console.error("Error in respond-to-offer:", error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
});
