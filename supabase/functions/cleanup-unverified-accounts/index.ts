// Supabase Edge Function to clean up unverified accounts
// Runs periodically to delete accounts that haven't verified within 15 minutes

import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase admin client
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Calculate cutoff time (15 minutes ago)
    const fifteenMinutesAgo = new Date(Date.now() - 15 * 60 * 1000).toISOString()

    console.log('Searching for unverified accounts older than:', fifteenMinutesAgo)

    // Find unverified users created more than 15 minutes ago
    const { data: unverifiedUsers, error: listError } = await supabaseAdmin.auth.admin.listUsers()

    if (listError) {
      console.error('Error listing users:', listError)
      throw listError
    }

    // Filter unverified users older than 15 minutes
    const usersToDelete = unverifiedUsers.users.filter(user => {
      const isUnverified = !user.email_confirmed_at
      const isOld = user.created_at < fifteenMinutesAgo
      return isUnverified && isOld
    })

    console.log(`Found ${usersToDelete.length} unverified accounts to delete`)

    // Delete each unverified user
    const deletionResults = []
    for (const user of usersToDelete) {
      try {
        const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(user.id)

        if (deleteError) {
          console.error(`Failed to delete user ${user.id}:`, deleteError)
          deletionResults.push({
            userId: user.id,
            email: user.email,
            success: false,
            error: deleteError.message
          })
        } else {
          console.log(`Successfully deleted unverified user: ${user.email}`)
          deletionResults.push({
            userId: user.id,
            email: user.email,
            success: true
          })
        }
      } catch (error) {
        console.error(`Exception deleting user ${user.id}:`, error)
        deletionResults.push({
          userId: user.id,
          email: user.email,
          success: false,
          error: error.message
        })
      }
    }

    const successCount = deletionResults.filter(r => r.success).length
    const failureCount = deletionResults.filter(r => !r.success).length

    return new Response(
      JSON.stringify({
        success: true,
        message: `Cleanup completed: ${successCount} deleted, ${failureCount} failed`,
        deleted: successCount,
        failed: failureCount,
        details: deletionResults
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Cleanup function error:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
