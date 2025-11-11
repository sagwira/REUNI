// =====================================================
// REUNI Admin Authentication Edge Function
// =====================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  );

  try {
    const url = new URL(req.url);
    const path = url.pathname;

    // =====================================================
    // POST /admin-auth - Login (NO JWT REQUIRED)
    // =====================================================
    if (req.method === "POST" && path.includes("/admin-auth")) {
      console.log("🔑 Admin login attempt");

      const { email, password } = await req.json();

      if (!email || !password) {
        return new Response(
          JSON.stringify({ error: "Email and password are required" }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      console.log("📧 Login attempt for:", email);

      // Fetch admin user
      const { data: adminUser, error: fetchError } = await supabaseClient
        .from("admin_users")
        .select("*")
        .eq("email", email)
        .eq("is_active", true)
        .single();

      if (fetchError || !adminUser) {
        console.error("❌ Admin user not found:", fetchError);
        return new Response(
          JSON.stringify({ error: "Invalid credentials" }),
          {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      console.log("✅ Admin user found:", adminUser.email);

      // Verify password (TODO: Add proper bcrypt verification)
      // For now, just check if password is "admin123"
      const passwordMatch = password === "admin123";

      if (!passwordMatch) {
        console.error("❌ Password mismatch");
        return new Response(
          JSON.stringify({ error: "Invalid credentials" }),
          {
            status: 401,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      console.log("✅ Password verified");

      // Update last login time
      await supabaseClient
        .from("admin_users")
        .update({ last_login_at: new Date().toISOString() })
        .eq("id", adminUser.id);

      // Create a simple session token (just the admin user ID + timestamp)
      const sessionToken = btoa(JSON.stringify({
        admin_id: adminUser.id,
        admin_email: adminUser.email,
        admin_role: adminUser.role,
        issued_at: Date.now(),
        expires_at: Date.now() + (24 * 60 * 60 * 1000) // 24 hours
      }));

      // Log admin action
      await supabaseClient.from("admin_actions").insert({
        admin_user_id: adminUser.id,
        admin_email: adminUser.email,
        action_type: "admin_login",
        target_type: "admin_users",
        description: `Admin ${adminUser.email} logged in`,
      });

      console.log("✅ Login successful");

      // Return admin user data and token
      return new Response(
        JSON.stringify({
          success: true,
          admin: {
            id: adminUser.id,
            email: adminUser.email,
            full_name: adminUser.full_name,
            role: adminUser.role,
          },
          token: sessionToken,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Method not allowed
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("❌ Error in admin-auth function:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
