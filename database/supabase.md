# FileSafe – Supabase Implementation

## Overview

FileSafe uses [Supabase](https://supabase.com) as its backend – an open‑source Firebase alternative built on PostgreSQL.
This document covers the complete Supabase setup: tables, Row Level Security (RLS), Storage buckets, and the Edge Function that powers password‑protected share links.

---

## Database Schema

### 1. `profiles` – User metadata

Stores user‑facing profile data. Automatically populated via a trigger when a new user signs up.

```sql
create table public.profiles (
    id              uuid primary key references auth.users(id) on delete cascade,
    full_name       text,
    avatar_url      text,
    storage_used    bigint not null default 0,
    quota_bytes     bigint not null default 1073741824,
    role            text not null default 'user' check (role in ('user','admin','moderator')),
    is_active       boolean not null default true,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);
```

### 2. `folders` – Organise files

```sql
create table public.folders (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    parent_id   uuid references public.folders(id) on delete set null,
    name        text not null,
    is_locked   boolean not null default false,
    lock_pin    text,                        -- hashed pin for folder lock
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);
```

### 3. `files` – Encrypted file metadata

Each file is encrypted **client‑side** before upload. The database stores metadata; the encrypted blob is in the `files` Storage bucket.

```sql
create table public.files (
    id              uuid primary key default uuid_generate_v4(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    folder_id       uuid references public.folders(id) on delete set null,
    name            text not null,
    stored_name     text not null,               -- path in storage bucket
    size            bigint not null default 0,
    type            text,                        -- mime type / extension
    file_category   text default 'other',
    encrypted       boolean not null default false,
    is_locked       boolean not null default false,
    lock_pin        text,                        -- hashed pin for file lock
    starred         boolean not null default false,
    is_deleted      boolean not null default false,
    deleted_at      timestamptz,
    download_count  int not null default 0,
    ai_summary      text,
    tags            text[],
    uploaded_at     timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);
```

### 4. `share_links` – Password‑protected share links

This is the **core of the sharing feature**.

Each link has a random `token` and stores the encrypted file key (`key_encrypted`) and salt (`key_salt`). The file itself is stored **encrypted** in the `shared` Storage bucket.

```sql
create table public.share_links (
    id                  uuid primary key default uuid_generate_v4(),
    file_id             uuid not null references public.files(id) on delete cascade,
    created_by          uuid not null references auth.users(id) on delete cascade,
    token               text not null unique default encode(gen_random_bytes(16), 'hex'),
    permission          text not null default 'VIEW' check (permission in ('VIEW','DOWNLOAD','EDIT')),
    expires_at          timestamptz,
    is_revoked          boolean not null default false,
    view_count          int not null default 0,
    created_at          timestamptz not null default now(),

    -- Password‑protected sharing columns
    key_encrypted       text,    -- iv:encryptedKey (base64)
    key_salt            text,    -- salt for PBKDF2
    shared_stored_name  text     -- path in 'shared' bucket
);
```

### 5. `notifications` – In‑app notifications

```sql
create table public.notifications (
    id          uuid primary key default uuid_generate_v4(),
    user_id     uuid not null references auth.users(id) on delete cascade,
    type        text not null
                    check (type in ('share_received','share_created','share_revoked',
                                    'upload_complete','storage_warning')),
    message     text not null,
    metadata    jsonb,
    is_read     boolean not null default false,
    created_at  timestamptz not null default now()
);
```

### 6. `download_history` – Download logs

```sql
create table public.download_history (
    id              uuid primary key default uuid_generate_v4(),
    user_id         uuid not null references auth.users(id) on delete cascade,
    file_id         uuid references public.files(id) on delete set null,
    file_name       text not null,
    file_type       text,
    file_size_bytes bigint,
    downloaded_at   timestamptz not null default now()
);
```

---

## Row Level Security (RLS)

RLS ensures users can only access their own data.

### Profiles – owner only

```sql
create policy "profiles_owner" on public.profiles
  for all using (auth.uid() = id);
```

### Folders – owner only

```sql
create policy "folders_owner" on public.folders
  for all using (auth.uid() = user_id);
```

### Files – owner only

```sql
create policy "files_owner" on public.files
  for all using (auth.uid() = user_id);
```

### Share Links – creator only

```sql
create policy "share_links_owner" on public.share_links
  for all
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);
```

> **Note:** The share link itself is publicly accessible (the Edge Function bypasses RLS using the service role key), but only the creator can revoke or list their links.

### Notifications – owner only

```sql
create policy "notifications_owner" on public.notifications
  for all using (auth.uid() = user_id);
```

### Download History – owner only

```sql
create policy "download_history_owner" on public.download_history
  for all using (auth.uid() = user_id);
```

---

## Storage Buckets

### 1. `files` – private bucket for user files

- All files are stored under `{user_id}/{filename}`.
- RLS ensures users can only read/write their own files.

**Policies:**

```sql
create policy "storage_insert" on storage.objects
  for insert
  with check (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "storage_select" on storage.objects
  for select
  using (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "storage_update" on storage.objects
  for update
  using (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

create policy "storage_delete" on storage.objects
  for delete
  using (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);
```

### 2. `shared` – bucket for encrypted share files

- Contains encrypted copies of files shared via password‑protected links.
- Files are stored under `share_links/{token}`.
- The Edge Function generates signed URLs for downloading these encrypted files.

**Policies:**

```sql
create policy "shared_insert" on storage.objects
  for insert
  with check (bucket_id = 'shared'
    and (storage.foldername(name))[1] = 'share_links'
    and auth.uid() is not null);

create policy "shared_select" on storage.objects
  for select
  using (bucket_id = 'shared'
    and auth.uid() is not null);
```

---

## Edge Function: `share`

This function is the **backend for password‑protected share links**.

### URL format

```
https://<project-ref>.supabase.co/functions/v1/share/<token>
```

### Behaviour

1. **Lookup** the token in `share_links` (joins with `files` to get the file name).
2. **Validate** – check expiry and revocation.
3. **Generate** a signed URL for the encrypted file in the `shared` bucket (valid for 60 seconds).
4. **Return JSON** with `fileUrl`, `keyEncrypted`, `keySalt`, `permission`, and `fileName` to the app.
5. **For browsers** (`Accept: text/html`), returns a simple landing page.

### Deployment

- **Function name:** `share`
- **Secret:** `SERVICE_ROLE_KEY` (must be set) – value is the Supabase service role key.
- **Function type:** Public (no authentication required).

### Code

```typescript
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SERVICE_ROLE_KEY")!
);

serve(async (req) => {
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
    return new Response(JSON.stringify({ error: "Link not found" }), { status: 404 });
  }

  if (link.is_revoked) {
    return new Response(JSON.stringify({ error: "Link revoked" }), { status: 410 });
  }

  if (link.expires_at && new Date(link.expires_at) < new Date()) {
    return new Response(JSON.stringify({ error: "Link expired" }), { status: 410 });
  }

  const { data: signedData } = await supabase.storage
    .from("shared")
    .createSignedUrl(link.shared_stored_name, 60);

  if (!signedData) {
    return new Response(JSON.stringify({ error: "File not found" }), { status: 404 });
  }

  // ── Build the JSON response with permission and fileName ──
  const jsonResponse = JSON.stringify({
    fileUrl: signedData.signedUrl,
    keyEncrypted: link.key_encrypted,
    keySalt: link.key_salt,
    permission: link.permission,
    fileName: link.file?.name ?? 'shared_file',
  });

  // ── Browser fallback ──
  if (req.headers.get("accept")?.includes("text/html")) {
    const html = `<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>FileSafe Share</title></head>
<body style="background:#0F1115;color:#fff;font-family:sans-serif;display:flex;justify-content:center;align-items:center;height:100vh;margin:0;">
  <div style="text-align:center;max-width:400px;">
    <h1>🔐 Shared File</h1>
    <p style="color:#9CA3AF;">Open this link in the FileSafe app to view the file.</p>
    <p style="font-size:12px;color:#6B7280;">Token: ${token}</p>
  </div>
</body>
</html>`;
    return new Response(html, {
      status: 200,
      headers: { "Content-Type": "text/html; charset=UTF-8" },
    });
  }

  return new Response(jsonResponse, {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

---

## Sharing Flow (End‑to‑End)

### 1. Creator (in the app)

- Selects a file → taps **Share**.
- Sets a **password** (min 4 chars) and optional expiry.
- The app:
  - Downloads and decrypts the file (owner's key).
  - Generates a random **share key** and encrypts the file with it.
  - Uploads the encrypted file to the `shared` bucket.
  - Derives a key from the password using **PBKDF2** (100k iterations, SHA‑256) and encrypts the share key.
  - Inserts a row into `share_links` with the token, encrypted key, and salt.
- Returns a link: `https://<project>.supabase.co/functions/v1/share/<token>`.

### 2. Recipient

- Opens the link (in the app or browser).
- App asks for the password.
- App calls the Edge Function to get `fileUrl`, `keyEncrypted`, `keySalt`, `permission`, and `fileName`.
- Derives the share key from the password, decrypts the share key, then decrypts the file.
- Opens the file in the appropriate viewer (PDF, image, text, etc.) based on the permission.

---

## Security Highlights

- **Client‑side encryption** – files are encrypted before leaving the device.
- **PBKDF2** with 100,000 iterations and random salt for password‑derived keys.
- **AES‑CBC** with a random IV for each file (prepended to the ciphertext).
- **Share key** is unique per share link, never stored in plaintext.
- **Service role key** is used only in the trusted Edge Function – never exposed to the client.
- **Signed URLs** are short‑lived (60 seconds).
- **Permissions** (VIEW, DOWNLOAD, EDIT) are enforced at the app level.

---

## Development & Deployment Notes

### Environment Variables

| Variable | Purpose | Where to set |
|---|---|---|
| `SUPABASE_URL` | Project URL | Injected automatically by Supabase |
| `SERVICE_ROLE_KEY` | Service role key for the Edge Function | Edge Function **Secrets** |

### Storage Buckets

- Both `files` and `shared` buckets must exist.
- `files` is private; `shared` can be public (or private with signed URLs).

### Table Migration

All SQL is available in the production schema. Run it once in the Supabase SQL Editor.

### Edge Function Deployment

Via Dashboard or CLI:

```bash
supabase functions deploy share
supabase secrets set SERVICE_ROLE_KEY=<your-key>
```

---

## Limitations (Known)

- **Direct sharing (by email)** is not implemented – recipient decryption is impossible without a separate key exchange. All sharing uses password‑protected links.
- **File preview on the web** is limited to basic types (PDF, images, text) – other files show a download link.
- The **web landing page** is minimal – it guides the user to open the link in the app.

These will be addressed in future versions.

---

## Conclusion

FileSafe's Supabase backend provides a secure, scalable foundation for encrypted file storage and sharing. The combination of RLS, client‑side encryption, and password‑protected share links ensures that files remain private end‑to‑end.

---

*Documented for FileSafe project defense – June 2026.*
