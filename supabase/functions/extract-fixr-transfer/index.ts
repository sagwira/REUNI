// Supabase Edge Function: Extract Fixr Transfer Link Data
// Replaces the ngrok-dependent Python API for permanent uptime

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { DOMParser } from 'https://deno.land/x/deno_dom@v0.1.38/deno-dom-wasm.ts'

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { transfer_url } = await req.json()

    if (!transfer_url || !transfer_url.includes('fixr.co/transfer-ticket/')) {
      return new Response(
        JSON.stringify({ error: 'Invalid Fixr transfer URL' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`🔄 Extracting Fixr transfer: ${transfer_url}`)

    // Fetch the Fixr transfer page
    const response = await fetch(transfer_url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      },
    })

    if (!response.ok) {
      throw new Error(`Failed to fetch Fixr page: ${response.status}`)
    }

    const html = await response.text()
    const doc = new DOMParser().parseFromString(html, 'text/html')

    if (!doc) {
      throw new Error('Failed to parse HTML')
    }

    // Extract JSON-LD data (Fixr embeds event data as structured data)
    const jsonLdScripts = doc.querySelectorAll('script[type="application/ld+json"]')
    let eventData: any = null

    for (const script of jsonLdScripts) {
      try {
        const data = JSON.parse(script.textContent)
        if (data['@type'] === 'Event') {
          eventData = data
          break
        }
      } catch (e) {
        continue
      }
    }

    // Extract event details from meta tags and page content
    const getMetaContent = (property: string) => {
      const meta = doc.querySelector(`meta[property="${property}"]`) ||
                    doc.querySelector(`meta[name="${property}"]`)
      return meta?.getAttribute('content') || ''
    }

    const title = doc.querySelector('title')?.textContent || ''
    const eventName = eventData?.name ||
                      getMetaContent('og:title') ||
                      title.split('|')[0].trim()

    const imageUrl = eventData?.image ||
                     getMetaContent('og:image') ||
                     ''

    const description = eventData?.description ||
                       getMetaContent('og:description') ||
                       ''

    // Extract date/time info
    const startDate = eventData?.startDate || ''
    const doorTime = eventData?.doorTime || startDate
    const endDate = eventData?.endDate || ''

    // Extract venue info
    const venue = eventData?.location?.name || ''
    const address = eventData?.location?.address?.streetAddress || ''
    const city = eventData?.location?.address?.addressLocality || ''
    const postcode = eventData?.location?.address?.postalCode || ''

    // Extract organizer
    const company = eventData?.organizer?.name || ''

    // Extract transferer info (from page content)
    const transfererText = doc.querySelector('[class*="transferer"], [class*="sender"]')?.textContent || ''
    const transferer = transfererText.replace(/transferred by|from/gi, '').trim()

    // Extract ticket info
    const ticketTypeElement = doc.querySelector('[class*="ticket-type"], .ticket-name, h2')
    const ticketType = ticketTypeElement?.textContent?.trim() || 'General Admission'

    // Extract transfer code from URL
    const transferCode = transfer_url.split('/').pop() || ''

    // Build response
    const result = {
      success: true,
      event: {
        name: eventName,
        date: doorTime ? new Date(doorTime).toUTCString() : '',
        lastEntry: endDate ? new Date(endDate).toUTCString() : '',
        lastEntryType: 'before',
        lastEntryLabel: 'Last Entry',
        venue: venue,
        location: city,
        address: address,
        postcode: postcode,
        description: description,
        imageUrl: imageUrl,
        url: eventData?.url || transfer_url.replace('/transfer-ticket/', '/event/'),
        company: company,
        transferer: transferer,
        ticketType: ticketType,
        ticketDescription: `Ticket transferred by ${transferer}`,
        transferUrl: transfer_url,
        transferCode: transferCode,
        source: 'fixr',
        tickets: [
          {
            ticketType: ticketType,
            price: 0.0,
            available: true,
            lastEntry: endDate ? new Date(endDate).toUTCString() : '',
          },
        ],
      },
    }

    console.log(`✅ Successfully extracted: ${eventName}`)

    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error extracting Fixr transfer:', error)

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || 'Failed to extract transfer link data',
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
