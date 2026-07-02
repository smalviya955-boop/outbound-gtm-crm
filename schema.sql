-- Outbound GTM CRM — Supabase schema
-- Paste this whole file into Supabase SQL Editor and click Run.
-- Internal-tool tradeoff: no auth, RLS policies are open (anon key can read/write everything).
-- This is fine for a small trusted internal team behind a private link, not for a public app.

create extension if not exists "pgcrypto";

-- Reps (the name picker reads/writes this)
create table reps (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  created_at timestamptz not null default now()
);

-- ICP scoring config, editable from the Settings panel (single row, key/value)
create table icp_weights (
  key text primary key,
  value jsonb not null,
  updated_at timestamptz not null default now()
);

-- Sequence templates, editable from the Settings panel
create table sequence_templates (
  id uuid primary key default gen_random_uuid(),
  persona text not null check (persona in ('CFO','Head of Sales')),
  day int not null,
  channel text not null,
  subject text not null,
  active boolean not null default true,
  sort_order int not null default 0
);

create table companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  domain text,
  industry text,
  state text,
  revenue_cr numeric,
  gst_states int,
  revenue_score int,
  industry_score int,
  complexity_score int,
  icp_score int,
  status text not null default 'Cut' check (status in ('Qualified','Cut')),
  owner_id uuid references reps(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index companies_domain_idx on companies (lower(domain)) where domain is not null;

create table contacts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references companies(id) on delete cascade,
  persona text not null check (persona in ('CFO','Head of Sales')),
  name text not null,
  title text,
  email text,
  phone text,
  linkedin_url text,
  notes text default '',
  replied boolean not null default false,
  reply_date timestamptz,
  meeting boolean not null default false,
  meeting_date timestamptz,
  unqualified boolean not null default false,
  deal_stage text not null default 'Outbound'
    check (deal_stage in ('Outbound','Replied','Meeting Booked','Meeting Held','Proposal','Closed Won','Closed Lost','Unqualified')),
  created_at timestamptz not null default now()
);

create table touches (
  id uuid primary key default gen_random_uuid(),
  contact_id uuid not null references contacts(id) on delete cascade,
  num int not null,
  touch_date timestamptz not null default now(),
  channel text,
  subject text,
  created_at timestamptz not null default now()
);

create table activity_log (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('company','contact')),
  entity_id uuid not null,
  rep_id uuid references reps(id) on delete set null,
  action text not null,
  detail text,
  created_at timestamptz not null default now()
);

-- Open RLS (no auth) — internal tool, trusted small team only.
alter table reps enable row level security;
alter table icp_weights enable row level security;
alter table sequence_templates enable row level security;
alter table companies enable row level security;
alter table contacts enable row level security;
alter table touches enable row level security;
alter table activity_log enable row level security;

create policy "anon full access" on reps for all using (true) with check (true);
create policy "anon full access" on icp_weights for all using (true) with check (true);
create policy "anon full access" on sequence_templates for all using (true) with check (true);
create policy "anon full access" on companies for all using (true) with check (true);
create policy "anon full access" on contacts for all using (true) with check (true);
create policy "anon full access" on touches for all using (true) with check (true);
create policy "anon full access" on activity_log for all using (true) with check (true);

-- Seed: default ICP weights (matches current hardcoded model)
insert into icp_weights (key, value) values (
  'default',
  '{
    "qualifyThreshold": 60,
    "revenue": {"minCr": 60, "maxCr": 300, "minScore": 20, "maxScore": 40},
    "industryTiers": {
      "Textiles & Apparel": 30, "Auto Components": 30, "Steel & Metals": 30, "Construction & Infra": 30,
      "FMCG & Foods": 20, "Electronics & Electricals": 20, "Chemicals": 20, "Packaging": 20, "Agro & Agri-inputs": 20,
      "Logistics & Warehousing": 10, "Retail & Distribution": 10, "Pharma & Life Sciences": 10,
      "IT & ITES": 5
    },
    "complexity": {"perStateScore": 4, "maxScore": 30}
  }'::jsonb
);

-- Seed: default sequence templates (matches current hardcoded copy)
insert into sequence_templates (persona, day, channel, subject, sort_order) values
('CFO', 0, 'Email', 'Cutting working capital risk at {{company}}', 1),
('CFO', 4, 'LinkedIn + Email', 'Quick one on {{company}}''s cash conversion cycle', 2),
('CFO', 9, 'Email', 'How a peer in {{industry}} freed up ₹2.3 Cr in working capital', 3),
('CFO', 14, 'Email (breakup)', 'Closing the loop — {{company}} cash flow', 4),
('Head of Sales', 0, 'Email', 'Faster deal cycles for {{company}}''s sales team', 1),
('Head of Sales', 4, 'LinkedIn + Email', 'What''s slowing down {{company}}''s pipeline?', 2),
('Head of Sales', 9, 'Email', 'How a peer in {{industry}} cut sales cycle by 11 days', 3),
('Head of Sales', 14, 'Email (breakup)', 'Last note — {{company}} pipeline speed', 4);
