-- ============ Swing Lab — Supabase schema & security ============
-- Run in Supabase Dashboard -> SQL Editor. Idempotent (safe to re-run).
--
-- Model: profiles (one per user), allowlist (invite-only access),
-- swings (AI analyses — metrics + thumbnails; videos stay on each device),
-- notes (practice log). Row-Level Security isolates each user's data;
-- admins can manage everyone.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  role text not null default 'user' check (role in ('user','admin')),
  approved boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.allowlist (
  email text primary key,
  created_at timestamptz not null default now()
);

create table if not exists public.swings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  date text, pro text, metrics jsonb, thumbs jsonb, trim jsonb
);

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  club text, rating int, note text, date text
);

-- helper functions (security definer avoids RLS recursion)
create or replace function public.is_admin(uid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles where id = uid and role = 'admin');
$$;
create or replace function public.is_approved(uid uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles where id = uid and approved = true);
$$;

-- auto-create a profile on signup; auto-approve if the email is on the allowlist
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, name, approved)
  values (
    new.id, new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', split_part(new.email,'@',1)),
    exists(select 1 from public.allowlist where lower(email) = lower(new.email))
  )
  on conflict (id) do nothing;
  return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

-- enable Row-Level Security
alter table public.profiles  enable row level security;
alter table public.allowlist enable row level security;
alter table public.swings    enable row level security;
alter table public.notes     enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = auth.uid() or public.is_admin(auth.uid()));
drop policy if exists profiles_insert on public.profiles;
create policy profiles_insert on public.profiles for insert with check (id = auth.uid());
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));
drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles for delete using (public.is_admin(auth.uid()));

-- allowlist (admins only)
drop policy if exists allowlist_all on public.allowlist;
create policy allowlist_all on public.allowlist for all
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- swings
drop policy if exists swings_select on public.swings;
create policy swings_select on public.swings for select
  using (user_id = auth.uid() or public.is_admin(auth.uid()));
drop policy if exists swings_insert on public.swings;
create policy swings_insert on public.swings for insert
  with check (user_id = auth.uid() and public.is_approved(auth.uid()));
drop policy if exists swings_update on public.swings;
create policy swings_update on public.swings for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists swings_delete on public.swings;
create policy swings_delete on public.swings for delete
  using (user_id = auth.uid() or public.is_admin(auth.uid()));

-- notes
drop policy if exists notes_select on public.notes;
create policy notes_select on public.notes for select
  using (user_id = auth.uid() or public.is_admin(auth.uid()));
drop policy if exists notes_insert on public.notes;
create policy notes_insert on public.notes for insert
  with check (user_id = auth.uid() and public.is_approved(auth.uid()));
drop policy if exists notes_update on public.notes;
create policy notes_update on public.notes for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists notes_delete on public.notes;
create policy notes_delete on public.notes for delete
  using (user_id = auth.uid() or public.is_admin(auth.uid()));

-- ============ BOOTSTRAP (run ONCE, AFTER you first sign in with Google) ============
-- Makes the first signed-in account (you) the approved admin:
--   update public.profiles set role='admin', approved=true
--   where id = (select id from public.profiles order by created_at asc limit 1);
--   insert into public.allowlist (email)
--   select email from public.profiles order by created_at asc limit 1
--   on conflict do nothing;
