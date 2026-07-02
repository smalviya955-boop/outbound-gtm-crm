-- Migration: lock down RLS to authenticated, allow-listed reps only.
-- Run this in Supabase SQL Editor after schema.sql. Also requires a manual
-- dashboard step (see instructions given alongside this file) to add the
-- deployed URL as an allowed Auth redirect.

alter table reps add column if not exists email text unique;

-- Backfill the existing "Shivangi" rep with her login email so she isn't
-- locked out once these policies go live. Adjust if this is wrong.
update reps set email = 'smalviya1105@gmail.com' where name = 'Shivangi' and email is null;

-- Helper: does the currently authenticated user's email match a row in reps?
-- security definer so it can read `reps` regardless of the caller's own RLS access.
create or replace function is_allowed_rep() returns boolean
language sql security definer stable as $$
  select exists (
    select 1 from reps where email = auth.jwt()->>'email'
  );
$$;

-- Drop the old wide-open policies.
drop policy if exists "anon full access" on reps;
drop policy if exists "anon full access" on icp_weights;
drop policy if exists "anon full access" on sequence_templates;
drop policy if exists "anon full access" on companies;
drop policy if exists "anon full access" on contacts;
drop policy if exists "anon full access" on touches;
drop policy if exists "anon full access" on activity_log;

-- Replace with allow-listed-rep-only access.
create policy "allowed reps read reps" on reps for select using (is_allowed_rep());
create policy "allowed reps invite reps" on reps for insert with check (is_allowed_rep());

create policy "allowed reps read weights" on icp_weights for select using (is_allowed_rep());
create policy "allowed reps write weights" on icp_weights for update using (is_allowed_rep());

create policy "allowed reps read templates" on sequence_templates for select using (is_allowed_rep());
create policy "allowed reps write templates" on sequence_templates for update using (is_allowed_rep());

create policy "allowed reps full access companies" on companies for all using (is_allowed_rep()) with check (is_allowed_rep());
create policy "allowed reps full access contacts" on contacts for all using (is_allowed_rep()) with check (is_allowed_rep());
create policy "allowed reps full access touches" on touches for all using (is_allowed_rep()) with check (is_allowed_rep());
create policy "allowed reps full access activity" on activity_log for all using (is_allowed_rep()) with check (is_allowed_rep());
