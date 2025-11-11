// Create a new ticket offer
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  handleCorsPreFlight,
  createSecureSuccessResponse,
  createSecureErrorResponse,
} from "../_shared/security-headers.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

interface CreateOfferRequest {
  ticket_id: string;
  offer_amount: number;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return handleCorsPreFlight();
  }

  try {
    // Get authenticated user
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Verify JWT and get user
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    const buyerId = user.id;

    // Fetch buyer username from profiles table
    const { data: buyerProfile, error: profileError } = await supabase
      .from("profiles")
      .select("username")
      .eq("id", buyerId)
      .single();

    const buyerUsername = buyerProfile?.username || "User";

    // Parse request body
    const { ticket_id, offer_amount }: CreateOfferRequest = await req.json();

    console.log(`📝 Creating offer: Buyer ${buyerId} (${buyerUsername}) offering £${offer_amount} for ticket ${ticket_id}`);

    // 1. Fetch ticket details
    const { data: ticket, error: ticketError } = await supabase
      .from("user_tickets")
      .select("*")
      .eq("id", ticket_id)
      .single();

    if (ticketError || !ticket) {
      console.error("Ticket not found:", ticketError);
      return new Response(JSON.stringify({ error: "Ticket not found" }), {
        status: 404,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 2. Validate ticket availability
    if (ticket.sale_status !== "available") {
      return new Response(JSON.stringify({ error: "Ticket is not available for offers" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    if (ticket.is_listed === false) {
      return new Response(JSON.stringify({ error: "Ticket is not listed" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 3. Check if seller allows offers
    if (ticket.allows_offers === false) {
      return new Response(JSON.stringify({ error: "Seller has disabled offers for this ticket" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 4. Validate offer amount
    // New rules: Min 50% of price, Max 110% of price (allow bids above listing)
    const ticketPrice = ticket.price_per_ticket || ticket.total_price || 0;
    const minOfferPercentage = 50;  // 50% of price (50% discount)
    const maxOfferPercentage = 110; // 110% of price (10% above listing - competitive bidding)
    const minOfferAmount = ticketPrice * (minOfferPercentage / 100);
    const maxOfferAmount = ticketPrice * (maxOfferPercentage / 100);

    if (offer_amount < minOfferAmount) {
      return new Response(JSON.stringify({
        error: `Offer too low. Minimum offer is £${minOfferAmount.toFixed(2)} (50% of listed price)`,
        min_offer: minOfferAmount,
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    if (offer_amount > maxOfferAmount) {
      return new Response(JSON.stringify({
        error: `Offer too high. Maximum offer is £${maxOfferAmount.toFixed(2)} (110% of listed price)`,
        max_offer: maxOfferAmount,
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 5. Check if buyer already has a pending offer on this ticket
    const { data: existingOffer, error: existingOfferError } = await supabase
      .from("ticket_offers")
      .select("id")
      .eq("ticket_id", ticket_id)
      .eq("buyer_id", buyerId)
      .eq("status", "pending")
      .maybeSingle();

    if (existingOffer) {
      return new Response(JSON.stringify({
        error: "You already have a pending offer on this ticket. Please wait for the seller to respond.",
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 6. Check if buyer is trying to offer on their own ticket
    if (ticket.user_id.toUpperCase() === buyerId.toUpperCase()) {
      return new Response(JSON.stringify({ error: "You cannot make an offer on your own ticket" }), {
        status: 400,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 7. Limit active offers per buyer (max 10 pending offers at once)
    const { count: activeOfferCount } = await supabase
      .from("ticket_offers")
      .select("id", { count: "exact", head: true })
      .eq("buyer_id", buyerId)
      .eq("status", "pending");

    if (activeOfferCount && activeOfferCount >= 10) {
      return new Response(JSON.stringify({
        error: "You have too many pending offers. Please wait for sellers to respond before making more offers.",
      }), {
        status: 429,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    // 8. Create the offer
    const { data: newOffer, error: offerError } = await supabase
      .from("ticket_offers")
      .insert({
        ticket_id,
        seller_id: ticket.user_id,
        buyer_id: buyerId,
        buyer_username: buyerUsername,
        offer_amount,
        original_price: ticketPrice,
        status: "pending",
        expires_at: new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString(), // 12 hours from now
      })
      .select()
      .single();

    if (offerError) {
      console.error("Error creating offer:", offerError);
      return new Response(JSON.stringify({ error: "Failed to create offer", details: offerError }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    console.log(`✅ Offer created successfully: ${newOffer.id}`);

    // 9. TODO: Send push notification to seller (implement after notification system is set up)
    // await sendPushNotification(ticket.user_id, {
    //   type: "new_offer",
    //   title: "New Offer on Your Ticket",
    //   body: `${buyerUsername} offered £${offer_amount} for ${ticket.event_name}`,
    //   data: { offer_id: newOffer.id },
    // });

    return new Response(JSON.stringify({
      success: true,
      offer: newOffer,
      message: "Offer submitted! The seller has 12 hours to respond. Your offer expires in 12 hours.",
    }), {
      status: 201,
      headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" },
    });

  } catch (error) {
    console.error("Error in create-ticket-offer:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
    });
  }
});
