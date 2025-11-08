// Test function to debug auth issues
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

serve(async (req) => {
  // CORS headers
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  try {
    // Check all headers
    const authHeader = req.headers.get('Authorization');
    const apiKeyHeader = req.headers.get('apikey');

    console.log('=== AUTH DEBUG ===');
    console.log('Authorization header:', authHeader?.substring(0, 30) + '...');
    console.log('apikey header:', apiKeyHeader?.substring(0, 30) + '...');
    console.log('All headers:', JSON.stringify(Object.fromEntries(req.headers.entries())));

    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: 'No Authorization header' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Try to get user
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();

    console.log('User error:', userError);
    console.log('User ID:', user?.id);
    console.log('User email:', user?.email);

    if (userError || !user) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Auth failed',
          details: userError?.message
        }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id: user.id,
        email: user.email,
        message: 'Auth successful!'
      }),
      { status: 200, headers: { 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
