-- ================================================================
--  FileSafe – Production Schema (Active Tables Only)
--  Safe to re‑run – idempotent (IF NOT EXISTS, DROP IF EXISTS)
-- ================================================================

-- Extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ================================================================
--  TABLES
-- ================================================================

-- 1. Profiles (merged with auth.users)
create table if not exists public.profiles (
    id              uuid primary key references auth.users(id) on delete cascade,
    full_name       text,
    avatar_url      text,
    storage_used    bigint      not null default 0,
    quota_bytes     bigint      not null default 1073741824,
    role            text        not null default 'user'
                                check (role in ('user','admin','moderator')),
    is_active       boolean     not null default true,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- 2. Folders
create table if not exists public.folders (
    id          uuid        primary key default uuid_generate_v4(),
    user_id     uuid        not null references auth.users(id) on delete cascade,
    parent_id   uuid        references public.folders(id) on delete set null,
    name        text        not null,
    is_locked   boolean     not null default false,
    lock_pin    text,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now()
);

-- 3. Files
create table if not exists public.files (
    id              uuid        primary key default uuid_generate_v4(),
    user_id         uuid        not null references auth.users(id) on delete cascade,
    folder_id       uuid        references public.folders(id) on delete set null,
    name            text        not null,
    stored_name     text        not null,
    size            bigint      not null default 0,
    type            text,
    file_category   text        default 'other',
    encrypted       boolean     not null default false,
    is_locked       boolean     not null default false,
    lock_pin        text,
    starred         boolean     not null default false,
    is_deleted      boolean     not null default false,
    deleted_at      timestamptz,
    download_count  int         not null default 0,
    ai_summary      text,
    tags            text[],
    uploaded_at     timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

-- 4. Share Links (password‑protected sharing)
create table if not exists public.share_links (
    id                  uuid        primary key default uuid_generate_v4(),
    file_id             uuid        not null references public.files(id) on delete cascade,
    created_by          uuid        not null references auth.users(id) on delete cascade,
    token               text        not null unique default encode(gen_random_bytes(16), 'hex'),
    permission          text        not null default 'VIEW'
                            check (permission in ('VIEW','DOWNLOAD','EDIT')),
    expires_at          timestamptz,
    is_revoked          boolean     not null default false,
    view_count          int         not null default 0,
    created_at          timestamptz not null default now(),
    key_encrypted       text,
    key_salt            text,
    shared_stored_name  text
);

-- 5. Notifications
create table if not exists public.notifications (
    id          uuid        primary key default uuid_generate_v4(),
    user_id     uuid        not null references auth.users(id) on delete cascade,
    type        text        not null
                    check (type in ('share_received','share_created','share_revoked',
                                    'upload_complete','storage_warning')),
    message     text        not null,
    metadata    jsonb,
    is_read     boolean     not null default false,
    created_at  timestamptz not null default now()
);

-- 6. Download History
create table if not exists public.download_history (
    id              uuid        primary key default uuid_generate_v4(),
    user_id         uuid        not null references auth.users(id) on delete cascade,
    file_id         uuid        references public.files(id) on delete set null,
    file_name       text        not null,
    file_type       text,
    file_size_bytes bigint,
    downloaded_at   timestamptz not null default now()
);

-- ================================================================
--  TRIGGERS & FUNCTIONS
-- ================================================================

-- Auto‑create profile on sign‑up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Update storage_used on file changes
create or replace function public.update_storage_used()
returns trigger language plpgsql security definer as $$
begin
  update public.profiles
  set storage_used = (
    select coalesce(sum(size), 0)
    from public.files
    where user_id = coalesce(new.user_id, old.user_id)
      and is_deleted = false
  )
  where id = coalesce(new.user_id, old.user_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_update_storage_insert on public.files;
create trigger trg_update_storage_insert
  after insert or update or delete on public.files
  for each row execute function public.update_storage_used();

-- Increment view count for share links
create or replace function public.increment_view_count(link_id uuid)
returns void language plpgsql security definer as $$
begin
  update public.share_links
  set view_count = view_count + 1
  where id = link_id;
end;
$$;

-- ================================================================
--  ROW LEVEL SECURITY
-- ================================================================

-- Enable RLS on all tables
alter table public.profiles        enable row level security;
alter table public.folders         enable row level security;
alter table public.files           enable row level security;
alter table public.share_links     enable row level security;
alter table public.notifications   enable row level security;
alter table public.download_history enable row level security;

-- Profiles: owner only
drop policy if exists "profiles_owner" on public.profiles;
create policy "profiles_owner" on public.profiles
  for all using (auth.uid() = id);

-- Folders: owner only
drop policy if exists "folders_owner" on public.folders;
create policy "folders_owner" on public.folders
  for all using (auth.uid() = user_id);

-- Files: owner only
drop policy if exists "files_owner" on public.files;
create policy "files_owner" on public.files
  for all using (auth.uid() = user_id);

-- Share Links: creator only
drop policy if exists "share_links_owner" on public.share_links;
create policy "share_links_owner" on public.share_links
  for all
  using (auth.uid() = created_by)
  with check (auth.uid() = created_by);

-- Notifications: owner only
drop policy if exists "notifications_owner" on public.notifications;
create policy "notifications_owner" on public.notifications
  for all using (auth.uid() = user_id);

-- Download History: owner only
drop policy if exists "download_history_owner" on public.download_history;
create policy "download_history_owner" on public.download_history
  for all using (auth.uid() = user_id);

-- ================================================================
--  STORAGE BUCKET POLICIES
-- ================================================================

-- ── files bucket ──
drop policy if exists "storage_insert" on storage.objects;
create policy "storage_insert" on storage.objects
  for insert
  with check (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "storage_select" on storage.objects;
create policy "storage_select" on storage.objects
  for select
  using (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "storage_update" on storage.objects;
create policy "storage_update" on storage.objects
  for update
  using (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "storage_delete" on storage.objects;
create policy "storage_delete" on storage.objects
  for delete
  using (bucket_id = 'files'
    and (storage.foldername(name))[1] = auth.uid()::text);

-- ── shared bucket (for password‑protected share links) ──
drop policy if exists "shared_insert" on storage.objects;
create policy "shared_insert" on storage.objects
  for insert
  with check (bucket_id = 'shared'
    and (storage.foldername(name))[1] = 'share_links'
    and auth.uid() is not null);

drop policy if exists "shared_select" on storage.objects;
create policy "shared_select" on storage.objects
  for select
  using (bucket_id = 'shared'
    and auth.uid() is not null);

-- ================================================================
--  INDEXES
-- ================================================================

create index if not exists idx_files_user          on public.files(user_id);
create index if not exists idx_files_folder        on public.files(folder_id);
create index if not exists idx_files_deleted       on public.files(is_deleted);
create index if not exists idx_files_starred       on public.files(starred);
create index if not exists idx_files_uploaded_at   on public.files(uploaded_at desc);
create index if not exists idx_folders_user        on public.folders(user_id);
create index if not exists idx_folders_parent      on public.folders(parent_id);
create index if not exists idx_share_links_token   on public.share_links(token);
create index if not exists idx_notifications_user  on public.notifications(user_id, is_read);
create index if not exists idx_download_user       on public.download_history(user_id);

-- ================================================================
--  HELPER VIEWS (optional)
-- ================================================================

create or replace view public.files_with_folder as
select
    f.*,
    fo.name as folder_name
from public.files f
left join public.folders fo on fo.id = f.folder_id;

create or replace view public.storage_by_type as
select
    user_id,
    file_category,
    count(*)        as file_count,
    sum(size)       as total_bytes
from public.files
where is_deleted = false
group by user_id, file_category;

-- ================================================================
--  CLEANUP ORPHANED TOKENS (if any)
-- ================================================================

delete from public.share_links
where token is null or token = '';

