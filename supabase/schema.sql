create table creators (
  wallet text primary key check (wallet ~ '^0x[a-f0-9]{40}$'),
  display_name text, platform text, handle_hash text unique, email text,
  consent_at timestamptz not null, created_at timestamptz default now()
);
create table proofs (
  id uuid primary key default gen_random_uuid(),
  wallet text references creators on delete cascade,
  storage_path text not null, sha256 text not null, created_at timestamptz default now()
);
create table passports (            -- miroir on-chain, reconstruit par le cron
  token_id numeric primary key, wallet text not null, level smallint not null,
  status text not null, issued_at timestamptz, updated_at timestamptz
);
create table passport_events (
  id text primary key, creator text, token_id numeric, kind smallint, level smallint, at bigint
);
create table evaluations (
  application_id numeric, juror text, score smallint, revealed boolean default false,
  primary key (application_id, juror)
);
create table contests (
  id numeric primary key, token_id numeric, challenger text, evidence_sha256 text,
  phase text, outcome smallint, commit_end timestamptz, reveal_end timestamptz
);
create table votes (
  contest_id numeric references contests, juror text, vote smallint,
  primary key (contest_id, juror)
);
create table advertisers (
  id uuid primary key default gen_random_uuid(),
  company text not null, contact_email text not null, website text,
  consent_at timestamptz not null, created_at timestamptz default now()
);
create table social_links (network text primary key, url text not null, position smallint);
create table allocations (label text primary key, percent numeric, tokens numeric, holder text, lockup text);
create table vesting_schedules (
  beneficiary text primary key, contract text, total numeric, start_at timestamptz, duration_days int
);
-- Vides tant qu'aucune structure ne peut émettre de titres (voir §13 et §16)
create table investors (id uuid primary key default gen_random_uuid(), legal_name text, jurisdiction text, kyc_status text);
create table cap_table (investor_id uuid references investors, instrument text, amount_eur numeric, signed_at timestamptz);
create table sync_state (id int primary key, last_block numeric);

alter table creators enable row level security;
alter table proofs enable row level security;
create policy own_profile on creators for all using (wallet = auth.jwt() ->> 'wallet');
create policy own_proofs on proofs for all using (wallet = auth.jwt() ->> 'wallet');
-- passports, passport_events, contests, votes, social_links, allocations : lecture publique, écriture service_role
