// Supabase Edge Function: stripe-onboarding-refresh
// Purpose: Handle redirect when Stripe onboarding link expires
// Endpoint: GET /functions/v1/stripe-onboarding-refresh
// NOTE: This is called by Stripe, not by authenticated users

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  console.log('⚠️ Stripe onboarding refresh redirect received (link expired)');
  console.log('   URL:', req.url);
  console.log('   Method:', req.method);

  // CORS headers for all responses
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  };

  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  // Return HTML asking user to return to app and try again
  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Link Expired</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: center;
          min-height: 100vh;
          margin: 0;
          background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
          color: white;
          text-align: center;
          padding: 20px;
        }
        .container {
          max-width: 400px;
        }
        h1 {
          font-size: 48px;
          margin-bottom: 16px;
        }
        p {
          font-size: 18px;
          opacity: 0.9;
          line-height: 1.6;
        }
        .icon {
          font-size: 72px;
          margin-bottom: 24px;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="icon">⏱️</div>
        <h1>Link Expired</h1>
        <p>The onboarding link has expired.</p>
        <p>Please return to the REUNI app and try again.</p>
        <p style="font-size: 14px; margin-top: 24px;">You can close this page now.</p>
      </div>
      <script>
        // Try to close the window after 3 seconds
        setTimeout(() => {
          window.close();
        }, 3000);
      </script>
    </body>
    </html>
  `;

  return new Response(html, {
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      ...corsHeaders,
    },
  });
});
