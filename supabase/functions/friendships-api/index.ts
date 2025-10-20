// friendships-api/index.ts
// Supabase Edge Function: friendships-api
// Routes:
//  - POST /friendships/request    { friend_id: string }
//  - POST /friendships/accept     { friendship_id: string }
//  - POST /friendships/reject     { friendship_id: string }
//  - DELETE /friendships/:id
//  - GET /friendships

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars');
}

type Json = Record<string, unknown>;

async function getAuthUserIdFromHeader(authHeader?: string) {
  if (!authHeader) return null;
  const token = authHeader.replace('Bearer ', '');
  // Use Supabase auth admin endpoint to get user info
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

async function fetchWithServiceRole(path: string, opts: RequestInit = {}) {
  const headers = new Headers(opts.headers ?? {});
  headers.set('apikey', SUPABASE_SERVICE_ROLE_KEY);
  headers.set('Authorization', `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`);
  headers.set('Content-Type', headers.get('Content-Type') ?? 'application/json');
  const res = await fetch(`${SUPABASE_URL}/rest/v1${path}`, { ...opts, headers });
  return res;
}

function jsonResponse(body: Json, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const pathname = url.pathname.replace(/\/$/, ''); // strip trailing slash
  const method = req.method;
  const authHeader = req.headers.get('authorization') ?? undefined;
  const userId = await getAuthUserIdFromHeader(authHeader);

  // require auth for all routes except health
  if (pathname === '/friendships-api/health') {
    return jsonResponse({ status: 'ok' });
  }
  if (!userId) return jsonResponse({ error: 'Unauthorized' }, 401);

  try {
    // POST /friendships/request
    if (method === 'POST' && pathname === '/friendships-api/friendships/request') {
      const body = await req.json();
      const friend_id = (body as any).friend_id as string | undefined;
      if (!friend_id) return jsonResponse({ error: 'friend_id is required' }, 400);
      if (friend_id === userId) return jsonResponse({ error: 'Cannot friend yourself' }, 400);

      // Create friendship with status 'pending', using canonical order to satisfy unique index.
      // We'll insert with user_id = userId, friend_id = friend_id
      const payload = {
        user_id: userId,
        friend_id,
        status: 'pending',
      };
      const resp = await fetchWithServiceRole('/friendships', {
        method: 'POST',
        body: JSON.stringify(payload),
      });

      if (!resp.ok) {
        const text = await resp.text();
        return jsonResponse({ error: 'Failed to create friendship', detail: text }, resp.status);
      }
      const data = await resp.json();
      return jsonResponse({ data }, 201);
    }

    // POST /friendships/accept
    if (method === 'POST' && pathname === '/friendships-api/friendships/accept') {
      const body = await req.json();
      const friendship_id = (body as any).friendship_id as string | undefined;
      if (!friendship_id) return jsonResponse({ error: 'friendship_id is required' }, 400);

      // Verify the friendship exists and that the current user is the friend_id (the recipient).
      const getRes = await fetchWithServiceRole(`/friendships?id=eq.${friendship_id}&select=*`);
      if (!getRes.ok) {
        const t = await getRes.text();
        return jsonResponse({ error: 'Failed to fetch friendship', detail: t }, 500);
      }
      const [f] = await getRes.json() as any[];
      if (!f) return jsonResponse({ error: 'Friendship not found' }, 404);
      if (f.friend_id !== userId && f.user_id !== userId) {
        return jsonResponse({ error: 'Not a participant' }, 403);
      }
      // Only allow the recipient to accept (either party can accept depending on UX). We'll allow friend_id or user_id to accept.
      const updateRes = await fetchWithServiceRole(`/friendships?id=eq.${friendship_id}`, {
        method: 'PATCH',
        body: JSON.stringify({ status: 'accepted', updated_at: new Date().toISOString() }),
      });
      if (!updateRes.ok) {
        const t = await updateRes.text();
        return jsonResponse({ error: 'Failed to accept friendship', detail: t }, updateRes.status);
      }
      const updated = await updateRes.json();
      return jsonResponse({ data: updated });
    }

    // POST /friendships/reject
    if (method === 'POST' && pathname === '/friendships-api/friendships/reject') {
      const body = await req.json();
      const friendship_id = (body as any).friendship_id as string | undefined;
      if (!friendship_id) return jsonResponse({ error: 'friendship_id is required' }, 400);

      const getRes = await fetchWithServiceRole(`/friendships?id=eq.${friendship_id}&select=*`);
      if (!getRes.ok) {
        const t = await getRes.text();
        return jsonResponse({ error: 'Failed to fetch friendship', detail: t }, 500);
      }
      const [f] = await getRes.json() as any[];
      if (!f) return jsonResponse({ error: 'Friendship not found' }, 404);
      if (f.friend_id !== userId && f.user_id !== userId) {
        return jsonResponse({ error: 'Not a participant' }, 403);
      }

      // Delete the friendship (reject)
      const delRes = await fetchWithServiceRole(`/friendships?id=eq.${friendship_id}`, { method: 'DELETE' });
      if (!delRes.ok) {
        const t = await delRes.text();
        return jsonResponse({ error: 'Failed to delete friendship', detail: t }, delRes.status);
      }
      return jsonResponse({ data: 'deleted' });
    }

    // DELETE /friendships/:id
    if (method === 'DELETE' && pathname.startsWith('/friendships-api/friendships/')) {
      const parts = pathname.split('/');
      const fid = parts[parts.length - 1];
      if (!fid) return jsonResponse({ error: 'id is required' }, 400);

      // Verify participant
      const getRes = await fetchWithServiceRole(`/friendships?id=eq.${fid}&select=*`);
      if (!getRes.ok) {
        const t = await getRes.text();
        return jsonResponse({ error: 'Failed to fetch friendship', detail: t }, 500);
      }
      const [f] = await getRes.json() as any[];
      if (!f) return jsonResponse({ error: 'Friendship not found' }, 404);
      if (f.friend_id !== userId && f.user_id !== userId) return jsonResponse({ error: 'Not a participant' }, 403);

      const delRes = await fetchWithServiceRole(`/friendships?id=eq.${fid}`, { method: 'DELETE' });
      if (!delRes.ok) {
        const t = await delRes.text();
        return jsonResponse({ error: 'Failed to delete friendship', detail: t }, delRes.status);
      }
      return jsonResponse({ data: 'deleted' });
    }

    // GET /friendships
    if (method === 'GET' && pathname === '/friendships-api/friendships') {
      // Return friendships where user is participant
      const res = await fetchWithServiceRole(`/friendships?or=(user_id.eq.${userId},friend_id.eq.${userId})&select=*,profiles:profiles(*)`);
      if (!res.ok) {
        const t = await res.text();
        return jsonResponse({ error: 'Failed to fetch friendships', detail: t }, 500);
      }
      const data = await res.json();
      return jsonResponse({ data });
    }

    return jsonResponse({ error: 'Not found' }, 404);
  } catch (err) {
    console.error(err);
    return jsonResponse({ error: 'Internal server error', detail: String(err) }, 500);
  }
});
