-- ============================================================
-- TraderGuardians — Schema Supabase
-- Esegui questo in Supabase → SQL Editor → Run
-- ============================================================

-- Abilita UUID
create extension if not exists "pgcrypto";

-- ── INVITE CODES ──────────────────────────────────────────
create table if not exists invite_codes (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  plan text not null default 'base', -- 'base' | 'pro' | 'elite'
  label text,
  used boolean default false,
  used_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- Codici di test (cambia prima del lancio!)
insert into invite_codes (code, plan, label) values
  ('TG-ALPHA', 'pro',   'Accesso Alpha Trader'),
  ('TG-ELITE', 'elite', 'Accesso Elite Founder'),
  ('TG-BASE1', 'base',  'Accesso Base'),
  ('TG-PRO01', 'pro',   'Accesso Pro Trader'),
  ('TG-TEST0', 'pro',   'Account di Test')
on conflict (code) do nothing;

-- ── USERS (profilo esteso) ────────────────────────────────
create table if not exists users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  username text unique,
  plan text default 'base',
  invite_code text,
  bio text,
  location text,
  trading_style text,
  preferred_assets text[],
  avatar_url text,
  is_admin boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Auto-crea profilo utente al signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.users (id, email, full_name)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── TRADES (Journal) ──────────────────────────────────────
create table if not exists trades (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  asset text not null,
  direction text not null, -- 'long' | 'short'
  status text default 'open', -- 'open' | 'closed' | 'cancelled'
  entry_price numeric,
  stop_loss numeric,
  target_1 numeric,
  target_2 numeric,
  exit_price numeric,
  lots numeric,
  pnl numeric,
  rr_ratio numeric,
  session text, -- 'Asia' | 'Londra' | 'New York'
  timeframe text,
  setup_type text,
  pre_trade_emotion text,
  post_trade_notes text,
  rules_followed boolean default true,
  rule_violations text[],
  screenshot_url text,
  signal_id uuid, -- collegato a operative_signals
  opened_at timestamptz default now(),
  closed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── TRADE PLANS ────────────────────────────────────────────
create table if not exists trade_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null default 'Il mio Piano Operativo',
  max_risk_per_trade numeric default 2, -- percentuale
  max_daily_loss numeric default 5,
  max_trades_per_day integer default 3,
  preferred_sessions text[],
  preferred_assets text[],
  rules text[], -- regole operative in testo libero
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ── RULE VIOLATIONS ────────────────────────────────────────
create table if not exists rule_violations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  trade_id uuid references trades(id),
  rule_name text not null,
  severity text default 'medium', -- 'low' | 'medium' | 'high'
  notes text,
  created_at timestamptz default now()
);

-- ── DAILY JOURNALS ─────────────────────────────────────────
create table if not exists daily_journals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade not null,
  date date not null,
  session text,
  market_outlook text,
  pre_session_notes text,
  post_session_notes text,
  emotion_score integer, -- 1-10
  discipline_score integer, -- 1-10
  pnl_day numeric,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, date)
);

-- ── MARKET DATA SNAPSHOTS (news cron) ─────────────────────
create table if not exists market_data_snapshots (
  id uuid primary key default gen_random_uuid(),
  tab_id text unique not null, -- es. 'news_forex', 'news_crypto'
  data jsonb,
  session text,
  updated_at timestamptz default now()
);

-- ── OPERATIVE SIGNALS ──────────────────────────────────────
create table if not exists operative_signals (
  id uuid primary key default gen_random_uuid(),
  asset text not null,
  asset_category text,
  direction text not null, -- 'long' | 'short'
  status text default 'active', -- 'active' | 'watching' | 'closed'
  conviction integer, -- 1-10
  entry_price text,
  stop_loss text,
  target_1 text,
  target_1_note text,
  target_2 text,
  target_2_note text,
  condition text,
  key_levels text[],
  news_events text[],
  session_risks text[],
  analysis text,
  plan text default 'pro', -- piano minimo richiesto
  valid_for_date date default current_date,
  created_at timestamptz default now()
);

-- ── CHALLENGES ─────────────────────────────────────────────
create table if not exists challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  type text, -- 'discipline' | 'winrate' | 'pf' | 'streak'
  target_value numeric,
  duration_days integer,
  reward_badge text,
  is_active boolean default true,
  created_at timestamptz default now()
);

create table if not exists challenge_participations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  challenge_id uuid references challenges(id),
  status text default 'active', -- 'active' | 'won' | 'failed'
  progress numeric default 0,
  started_at timestamptz default now(),
  completed_at timestamptz,
  unique(user_id, challenge_id)
);

-- ── LEADERBOARD ────────────────────────────────────────────
create table if not exists leaderboard_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade unique,
  rank integer,
  win_rate numeric,
  pnl_total numeric,
  discipline_score numeric,
  profit_factor numeric,
  total_trades integer,
  updated_at timestamptz default now()
);

-- ── NOTIFICATIONS ──────────────────────────────────────────
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  title text not null,
  body text,
  type text default 'info', -- 'info' | 'alert' | 'success'
  read boolean default false,
  created_at timestamptz default now()
);

-- ── SECTION VISIBILITY (Admin) ─────────────────────────────
create table if not exists section_visibility (
  id uuid primary key default gen_random_uuid(),
  section_name text unique not null,
  visible_to_plans text[] default array['base','pro','elite'],
  is_enabled boolean default true,
  updated_at timestamptz default now()
);

insert into section_visibility (section_name, visible_to_plans) values
  ('market_intel',  array['pro','elite']),
  ('signals',       array['pro','elite']),
  ('news',          array['base','pro','elite']),
  ('journal',       array['base','pro','elite']),
  ('trader_card',   array['base','pro','elite']),
  ('leaderboard',   array['base','pro','elite']),
  ('challenges',    array['pro','elite']),
  ('cot_data',      array['elite']),
  ('ai_analysis',   array['pro','elite'])
on conflict (section_name) do nothing;

-- ── ROW LEVEL SECURITY ─────────────────────────────────────
alter table users enable row level security;
alter table trades enable row level security;
alter table trade_plans enable row level security;
alter table rule_violations enable row level security;
alter table daily_journals enable row level security;
alter table notifications enable row level security;
alter table challenge_participations enable row level security;
alter table leaderboard_entries enable row level security;

-- Users: ogni utente vede solo il suo profilo (admin vede tutto)
create policy "users_own" on users for all using (auth.uid() = id);
create policy "users_admin" on users for all using (
  exists (select 1 from users where id = auth.uid() and is_admin = true)
);

-- Trades: solo il proprietario
create policy "trades_own" on trades for all using (auth.uid() = user_id);

-- Trade plans: solo il proprietario  
create policy "plans_own" on trade_plans for all using (auth.uid() = user_id);

-- Rule violations: solo il proprietario
create policy "violations_own" on rule_violations for all using (auth.uid() = user_id);

-- Daily journals: solo il proprietario
create policy "journals_own" on daily_journals for all using (auth.uid() = user_id);

-- Notifications: solo il destinatario
create policy "notif_own" on notifications for all using (auth.uid() = user_id);

-- Market data: lettura pubblica (è dati di mercato, non dati utente)
create policy "market_read" on market_data_snapshots for select using (true);

-- Signals: lettura pubblica
create policy "signals_read" on operative_signals for select using (true);

-- Challenges: lettura pubblica
create policy "challenges_read" on challenges for select using (true);

-- Challenge participations: solo il proprietario
create policy "cp_own" on challenge_participations for all using (auth.uid() = user_id);

-- Leaderboard: lettura pubblica
create policy "lb_read" on leaderboard_entries for select using (true);
create policy "lb_own" on leaderboard_entries for all using (auth.uid() = user_id);

-- Section visibility: lettura pubblica
create policy "sv_read" on section_visibility for select using (true);
