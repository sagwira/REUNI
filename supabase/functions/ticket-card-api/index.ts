// ticket-card-api/index.ts
// Supabase Edge Function: ticket-card-api
// Endpoints for managing event tickets

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing required environment variables');
}

type Json = Record<string, unknown>;

// Get authenticated user from JWT token
async function getAuthUserIdFromHeader(authHeader?: string) {
  if (!authHeader) return null;
  const token = authHeader.replace('Bearer ', '');

  const resp = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: SUPABASE_ANON_KEY,
    },
  });

  if (!resp.ok) return null;
  const data = await resp.json();
  return (data as any).id as string | null;
}

// Fetch data using service role (bypasses RLS)
async function fetchWithServiceRole(path: string, opts: RequestInit = {}) {
  const headers = new Headers(opts.headers ?? {});
  headers.set('apikey', SUPABASE_SERVICE_ROLE_KEY);
  headers.set('Authorization', `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`);
  headers.set('Content-Type', headers.get('Content-Type') ?? 'application/json');

  const res = await fetch(`${SUPABASE_URL}/rest/v1${path}`, { ...opts, headers });
  return res;
}

function jsonResponse(body: Json | Json[], status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const pathname = url.pathname.replace(/\/$/, '');
  const method = req.method;
  const authHeader = req.headers.get('authorization') ?? undefined;

  // Health check endpoint
  if (pathname === '/ticket-card-api/health') {
    return jsonResponse({ status: 'ok', message: 'Ticket Card API is running' });
  }

  // Require authentication for all other endpoints
  const userId = await getAuthUserIdFromHeader(authHeader);
  if (!userId) {
    return jsonResponse({ error: 'Unauthorized', message: 'Valid JWT token required' }, 401);
  }

  try {
    // GET /ticket-card-api - Get all tickets with user info
    if (method === 'GET' && pathname === '/ticket-card-api') {
      // Fetch tickets with user information
      const ticketsRes = await fetchWithServiceRole(
        '/tickets?select=*,users!organizer_id(id,username,profile_picture_url)&order=created_at.desc'
      );

      if (!ticketsRes.ok) {
        const text = await ticketsRes.text();
        return jsonResponse({ error: 'Failed to fetch tickets', detail: text }, ticketsRes.status);
      }

      const tickets = await ticketsRes.json() as any[];

      // Transform to expected format
      const data = tickets.map(ticket => ({
        id: ticket.id,
        title: ticket.title,
        organizerId: ticket.organizer_id,
        organizerUsername: ticket.users?.username || 'Unknown',
        organizerProfileUrl: ticket.users?.profile_picture_url || null,
        organizerVerified: false,
        organizerUniversity: null,
        organizerDegree: null,
        eventDate: ticket.event_date,
        lastEntry: ticket.last_entry,
        price: ticket.price,
        availableTickets: ticket.available_tickets,
        city: ticket.city,
        ageRestriction: ticket.age_restriction,
        ticketSource: ticket.ticket_source,
        ticketImageUrl: ticket.ticket_image_url,
        createdAt: ticket.created_at,
      }));

      return jsonResponse({ data });
    }

    // POST /ticket-card-api - Create new ticket
    if (method === 'POST' && pathname === '/ticket-card-api') {
      const body = await req.json() as any;

      // Validate required fields
      const required = ['title', 'event_date', 'last_entry', 'price', 'available_tickets', 'age_restriction', 'ticket_source'];
      const missing = required.filter(field => !body[field]);
      if (missing.length > 0) {
        return jsonResponse({ error: 'Missing required fields', missing }, 400);
      }

      // Create ticket
      const ticketData = {
        title: body.title,
        organizer_id: userId,
        event_date: body.event_date,
        last_entry: body.last_entry,
        price: body.price,
        available_tickets: body.available_tickets,
        city: body.city || null,
        age_restriction: body.age_restriction,
        ticket_source: body.ticket_source,
        ticket_image_url: body.ticket_image_url || null,
      };

      const createRes = await fetchWithServiceRole('/tickets', {
        method: 'POST',
        body: JSON.stringify(ticketData),
      });

      if (!createRes.ok) {
        const text = await createRes.text();
        return jsonResponse({ error: 'Failed to create ticket', detail: text }, createRes.status);
      }

      const created = await createRes.json() as any[];

      // Fetch user info for response
      const userRes = await fetchWithServiceRole(`/users?id=eq.${userId}&select=username,profile_picture_url`);
      const [user] = userRes.ok ? await userRes.json() : [{}];

      const data = {
        ...created[0],
        organizerUsername: user.username || 'Unknown',
        organizerProfileUrl: user.profile_picture_url || null,
        organizerVerified: false,
      };

      return jsonResponse({ data }, 201);
    }

    // PUT /ticket-card-api/:id - Update ticket
    if (method === 'PUT' && pathname.startsWith('/ticket-card-api/')) {
      const parts = pathname.split('/');
      const ticketId = parts[parts.length - 1];

      if (!ticketId) {
        return jsonResponse({ error: 'Ticket ID is required' }, 400);
      }

      // Check if ticket exists and user is owner
      const checkRes = await fetchWithServiceRole(`/tickets?id=eq.${ticketId}&select=organizer_id`);
      if (!checkRes.ok) {
        return jsonResponse({ error: 'Ticket not found' }, 404);
      }

      const [ticket] = await checkRes.json() as any[];
      if (!ticket) {
        return jsonResponse({ error: 'Ticket not found' }, 404);
      }

      if (ticket.organizer_id !== userId) {
        return jsonResponse({ error: 'Forbidden', message: 'You can only update your own tickets' }, 403);
      }

      // Update ticket
      const body = await req.json() as any;
      const updateData: any = {};

      // Only update provided fields
      if (body.title !== undefined) updateData.title = body.title;
      if (body.event_date !== undefined) updateData.event_date = body.event_date;
      if (body.last_entry !== undefined) updateData.last_entry = body.last_entry;
      if (body.price !== undefined) updateData.price = body.price;
      if (body.available_tickets !== undefined) updateData.available_tickets = body.available_tickets;
      if (body.city !== undefined) updateData.city = body.city;
      if (body.age_restriction !== undefined) updateData.age_restriction = body.age_restriction;
      if (body.ticket_source !== undefined) updateData.ticket_source = body.ticket_source;
      if (body.ticket_image_url !== undefined) updateData.ticket_image_url = body.ticket_image_url;

      const updateRes = await fetchWithServiceRole(`/tickets?id=eq.${ticketId}`, {
        method: 'PATCH',
        body: JSON.stringify(updateData),
      });

      if (!updateRes.ok) {
        const text = await updateRes.text();
        return jsonResponse({ error: 'Failed to update ticket', detail: text }, updateRes.status);
      }

      const updated = await updateRes.json() as any[];
      return jsonResponse({ data: updated[0] });
    }

    // DELETE /ticket-card-api/:id - Delete ticket
    if (method === 'DELETE' && pathname.startsWith('/ticket-card-api/')) {
      const parts = pathname.split('/');
      const ticketId = parts[parts.length - 1];

      if (!ticketId) {
        return jsonResponse({ error: 'Ticket ID is required' }, 400);
      }

      // Check if ticket exists and user is owner
      const checkRes = await fetchWithServiceRole(`/tickets?id=eq.${ticketId}&select=organizer_id`);
      if (!checkRes.ok) {
        return jsonResponse({ error: 'Ticket not found' }, 404);
      }

      const [ticket] = await checkRes.json() as any[];
      if (!ticket) {
        return jsonResponse({ error: 'Ticket not found' }, 404);
      }

      if (ticket.organizer_id !== userId) {
        return jsonResponse({ error: 'Forbidden', message: 'You can only delete your own tickets' }, 403);
      }

      // Delete ticket
      const deleteRes = await fetchWithServiceRole(`/tickets?id=eq.${ticketId}`, {
        method: 'DELETE',
      });

      if (!deleteRes.ok) {
        const text = await deleteRes.text();
        return jsonResponse({ error: 'Failed to delete ticket', detail: text }, deleteRes.status);
      }

      return jsonResponse({ message: 'Ticket deleted successfully' });
    }

    // Route not found
    return jsonResponse({ error: 'Not found', message: `${method} ${pathname} is not a valid endpoint` }, 404);

  } catch (err) {
    console.error('Error:', err);
    return jsonResponse({
      error: 'Internal server error',
      message: String(err),
      detail: err instanceof Error ? err.stack : undefined
    }, 500);
  }
});
