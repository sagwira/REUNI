// send-push-notification Edge Function
// Sends push notifications via Apple Push Notification Service (APNs)

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationPayload {
  userId: string
  type: 'ticket_purchased' | 'ticket_bought' | 'offer_received' | 'offer_accepted'
  title: string
  body: string
  data?: Record<string, any>
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Parse request body
    const payload: NotificationPayload = await req.json()
    const { userId, type, title, body, data = {} } = payload

    console.log('📨 Sending push notification:', { userId, type, title })

    // Get user's device token
    const { data: profile, error: profileError } = await supabaseClient
      .from('profiles')
      .select('device_token, notifications_enabled, username')
      .eq('id', userId)
      .single()

    if (profileError || !profile) {
      console.error('❌ Failed to fetch user profile:', profileError)
      throw new Error('User profile not found')
    }

    if (!profile.device_token) {
      console.log('⚠️  No device token for user:', userId)
      // Create notification record even if can't send push
      await createNotificationRecord(supabaseClient, userId, type, title, body, data, false)
      return new Response(
        JSON.stringify({ success: false, message: 'No device token registered' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!profile.notifications_enabled) {
      console.log('⚠️  Notifications disabled for user:', userId)
      await createNotificationRecord(supabaseClient, userId, type, title, body, data, false)
      return new Response(
        JSON.stringify({ success: false, message: 'Notifications disabled' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Send push notification via APNs
    const apnsResponse = await sendAPNsNotification(
      profile.device_token,
      title,
      body,
      type,
      data
    )

    // Create notification record in database
    await createNotificationRecord(supabaseClient, userId, type, title, body, data, apnsResponse.success)

    console.log('✅ Push notification sent successfully')

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Notification sent',
        apnsResponse
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Error sending push notification:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})

// Send notification via APNs
async function sendAPNsNotification(
  deviceToken: string,
  title: string,
  body: string,
  type: string,
  data: Record<string, any>
): Promise<{ success: boolean; message: string }> {
  try {
    // APNs configuration
    const apnsUrl = Deno.env.get('APNS_SANDBOX') === 'true'
      ? 'https://api.sandbox.push.apple.com'  // Development
      : 'https://api.push.apple.com'           // Production

    const teamId = Deno.env.get('APNS_TEAM_ID') ?? ''
    const keyId = Deno.env.get('APNS_KEY_ID') ?? ''
    const bundleId = Deno.env.get('APNS_BUNDLE_ID') ?? 'ReUni.REUNI'

    // Create APNs payload
    const payload = {
      aps: {
        alert: {
          title,
          body,
        },
        sound: 'default',
        badge: 1,
        'content-available': 1,
        'mutable-content': 1,
      },
      type,
      ...data,
    }

    // Generate JWT token for APNs authentication
    const jwt = await generateAPNsJWT(teamId, keyId)

    // Send notification to APNs
    const response = await fetch(
      `${apnsUrl}/3/device/${deviceToken}`,
      {
        method: 'POST',
        headers: {
          'authorization': `bearer ${jwt}`,
          'apns-topic': bundleId,
          'apns-priority': '10',
          'apns-push-type': 'alert',
        },
        body: JSON.stringify(payload),
      }
    )

    if (response.ok) {
      console.log('✅ APNs notification sent successfully')
      return { success: true, message: 'Notification sent' }
    } else {
      const errorText = await response.text()
      console.error('❌ APNs error:', response.status, errorText)
      return { success: false, message: `APNs error: ${errorText}` }
    }

  } catch (error) {
    console.error('❌ APNs send error:', error)
    return { success: false, message: error.message }
  }
}

// Generate JWT token for APNs authentication
async function generateAPNsJWT(teamId: string, keyId: string): Promise<string> {
  // Note: In production, you'll need to implement proper JWT signing
  // using your APNs private key (.p8 file)
  // For now, this is a placeholder that needs to be replaced with actual JWT signing

  // You'll need to:
  // 1. Store your APNs private key in Supabase secrets
  // 2. Use a JWT library (like jose) to sign the token
  // 3. Include claims: iss (teamId), iat (issued at), exp (expiry)

  console.warn('⚠️  APNs JWT generation not fully implemented - add your .p8 key')
  return 'placeholder-jwt-token'
}

// Create notification record in database
async function createNotificationRecord(
  supabaseClient: any,
  userId: string,
  type: string,
  title: string,
  body: string,
  data: Record<string, any>,
  delivered: boolean
) {
  const { error } = await supabaseClient
    .from('notifications')
    .insert({
      user_id: userId,
      type,
      title,
      body,
      data,
      delivered,
      sent_at: new Date().toISOString(),
    })

  if (error) {
    console.error('❌ Failed to create notification record:', error)
  } else {
    console.log('✅ Notification record created')
  }
}
