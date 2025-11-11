// Shared Security Headers for Edge Functions
// Purpose: Add security headers to all API responses
// Based on OWASP recommendations

export const SECURITY_HEADERS = {
  // Prevent MIME type sniffing
  'X-Content-Type-Options': 'nosniff',

  // Prevent clickjacking
  'X-Frame-Options': 'DENY',

  // Force HTTPS
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',

  // Content Security Policy (APIs don't serve HTML)
  'Content-Security-Policy': "default-src 'none'; frame-ancestors 'none'",

  // Control referrer information
  'Referrer-Policy': 'no-referrer',

  // Disable browser features that could leak data
  'Permissions-Policy': 'geolocation=(), microphone=(), camera=(), payment=()',

  // XSS Protection (legacy but still good to have)
  'X-XSS-Protection': '1; mode=block',

  // CORS headers
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',

  // Content type
  'Content-Type': 'application/json',
};

/**
 * Create a response with security headers
 */
export function createSecureResponse(
  body: unknown,
  status = 200,
  additionalHeaders: Record<string, string> = {}
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...SECURITY_HEADERS,
        ...additionalHeaders,
      },
    }
  );
}

/**
 * Create an error response with security headers
 */
export function createSecureErrorResponse(
  error: string,
  status = 400,
  additionalData?: Record<string, unknown>
): Response {
  return createSecureResponse(
    {
      success: false,
      error,
      ...additionalData,
    },
    status
  );
}

/**
 * Create a success response with security headers
 */
export function createSecureSuccessResponse(
  data: unknown,
  status = 200
): Response {
  return createSecureResponse(
    {
      success: true,
      ...data,
    },
    status
  );
}

/**
 * Handle CORS preflight requests
 */
export function handleCorsPreFlight(): Response {
  return new Response('ok', {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      'Access-Control-Allow-Methods': 'POST, GET, OPTIONS, PUT, DELETE',
      'Access-Control-Max-Age': '86400', // 24 hours
    },
  });
}
