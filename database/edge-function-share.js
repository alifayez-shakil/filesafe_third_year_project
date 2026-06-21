import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!
);

// ─── CORS headers ──────────────────────────────────────
const corsHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // ── Handle preflight OPTIONS request ────────────────
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const token = url.pathname.split("/").pop();

  // ── Query share_links + join files to get file name ──
  const { data: link, error } = await supabase
    .from("share_links")
    .select(`
      shared_stored_name,
      key_encrypted,
      key_salt,
      expires_at,
      is_revoked,
      permission,
      file:files!file_id (name)
    `)
    .eq("token", token)
    .single();

  if (error || !link) {
    return new Response(
      JSON.stringify({ error: "Link not found" }),
      { status: 404, headers: corsHeaders }
    );
  }

  if (link.is_revoked) {
    return new Response(
      JSON.stringify({ error: "Link revoked" }),
      { status: 410, headers: corsHeaders }
    );
  }

  if (link.expires_at && new Date(link.expires_at) < new Date()) {
    return new Response(
      JSON.stringify({ error: "Link expired" }),
      { status: 410, headers: corsHeaders }
    );
  }

  // ── Generate signed URL for the encrypted file ──
  const { data: signedData } = await supabase.storage
    .from("shared")
    .createSignedUrl(link.shared_stored_name, 60);

  if (!signedData) {
    return new Response(
      JSON.stringify({ error: "File not found" }),
      { status: 404, headers: corsHeaders }
    );
  }

  // ── Build JSON response ──
  const jsonResponse = JSON.stringify({
    fileUrl: signedData.signedUrl,
    keyEncrypted: link.key_encrypted,
    keySalt: link.key_salt,
    permission: link.permission,
    fileName: link.file?.name ?? 'shared_file',
  });

  // ── Return JSON response with CORS headers ──
  return new Response(jsonResponse, {
    status: 200,
    headers: corsHeaders,
  });
});