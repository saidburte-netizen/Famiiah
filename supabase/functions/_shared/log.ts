// Structured logging. Never log secrets, tokens, passwords or PII documents.
type Level = "debug" | "info" | "warn" | "error";

export interface LogFields {
  function: string;
  request_id?: string;
  org_id?: string;
  user_id?: string;
  duration_ms?: number;
  outcome?: string;
  [key: string]: unknown;
}

export function log(level: Level, message: string, fields: LogFields): void {
  const line = JSON.stringify({
    ts: new Date().toISOString(),
    level,
    message,
    ...fields,
  });
  if (level === "error") console.error(line);
  else if (level === "warn") console.warn(line);
  else console.log(line);
}

export function newRequestId(req: Request): string {
  return req.headers.get("x-request-id") ?? crypto.randomUUID();
}
