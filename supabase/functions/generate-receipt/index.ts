// generate-receipt — called by the app.
// Builds a receipt PDF for a payment, stores it in receipts/{org}/{payment}.pdf,
// and returns a short-lived signed URL.
import { userClient } from "../_shared/supabase.ts";
import { corsHeaders, preflight } from "../_shared/cors.ts";
import { json, error } from "../_shared/response.ts";
import { log, newRequestId } from "../_shared/log.ts";

interface Body {
  payment_id: string;
}

Deno.serve(async (req) => {
  const origin = req.headers.get("origin");
  const pf = preflight(req);
  if (pf) return pf;

  const request_id = newRequestId(req);
  if (req.method !== "POST") return error("method_not_allowed", 405, origin);

  try {
    const { payment_id } = (await req.json()) as Body;
    if (!payment_id) return error("invalid_input", 400, origin);

    // RLS ensures the caller can only read payments for their org/tenants.
    const supabase = userClient(req);
    const { data: pay, error: pErr } = await supabase
      .from("payments")
      .select("id, org_id, receipt_no, amount, method, paid_at, reference, tenant_id")
      .eq("id", payment_id)
      .single();
    if (pErr || !pay) return error("not_found", 404, origin);

    const receiptPath = `${pay.org_id}/${pay.id}.pdf`;
    // A minimal PDF placeholder; replace with a real PDF generator (pdf-lib).
    const pdfBytes = buildPlaceholderPdf(pay.receipt_no ?? pay.id, String(pay.amount));

    const { error: upErr } = await supabase.storage
      .from("receipts")
      .upload(receiptPath, pdfBytes, { contentType: "application/pdf", upsert: true });
    if (upErr) {
      log("warn", "receipt upload failed", { function: "generate-receipt", request_id, outcome: "upload_failed" });
      return error("upload_failed", 400, origin);
    }

    const { data: signed, error: sErr } = await supabase.storage
      .from("receipts")
      .createSignedUrl(receiptPath, 3600);
    if (sErr || !signed) return error("sign_failed", 500, origin);

    log("info", "receipt generated", {
      function: "generate-receipt",
      request_id,
      org_id: pay.org_id,
      outcome: "ok",
    });
    return json({ ok: true, path: receiptPath, url: signed.signedUrl });
  } catch {
    log("error", "generate-receipt failed", { function: "generate-receipt", request_id, outcome: "error" });
    return error("internal", 500, origin);
  }
});

// Minimal single-page PDF with the receipt number and amount.
function buildPlaceholderPdf(receiptNo: string, amount: string): Uint8Array {
  const text = `Receipt ${receiptNo}  Amount ${amount} ETB`;
  const content = `BT /F1 14 Tf 72 720 Td (${text.replace(/[()\\]/g, "")}) Tj ET`;
  const objects = [
    "1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj",
    "2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj",
    "3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >> endobj",
    "4 0 obj << /Type /Font /Subtype /Type1 /BaseFont /Helvetica >> endobj",
    `5 0 obj << /Length ${content.length} >> stream\n${content}\nendstream endobj`,
  ];
  let pdf = "%PDF-1.4\n";
  const offsets: number[] = [];
  for (const o of objects) {
    offsets.push(pdf.length);
    pdf += o + "\n";
  }
  const xrefStart = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const off of offsets) pdf += `${off.toString().padStart(10, "0")} 00000 n \n`;
  pdf += `trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefStart}\n%%EOF`;
  return new TextEncoder().encode(pdf);
}
