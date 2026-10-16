import { corsHeaders } from "./cors.ts";

export function json(body: unknown, status = 200, origin: string | null = null): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

export function error(message: string, status = 400, origin: string | null = null): Response {
  return json({ error: message }, status, origin);
}

export function methodNotAllowed(origin: string | null = null): Response {
  return error("method_not_allowed", 405, origin);
}
