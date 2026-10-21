-- Bluecoins backend: one private copy of each user's data, protected by Row Level Security.
-- Every table mirrors the phone's drift table plus user_id and server_updated_at.
-- Money is bigint minor units; dates are 'YYYY-MM-DD' text; booleans are real booleans
-- (the app converts from SQLite's 0/1).

create table public.settings (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (id = 'settings'),
  currency text not null default 'BDT' check (char_length(currency) between 1 and 8),
  lakh boolean not null default true,
  payday integer check (payday between 1 and 31),
  every_days integer check (every_days between 1 and 366),
  budget bigint not null default 0 check (budget between 0 and 100000000000000),
  base_salary bigint not null default 0 check (base_salary between 0 and 100000000000000),
  tracking text not null default 'balance' check (tracking in ('balance', 'expenses')),
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.checkins (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (id ~ '^\d{4}-\d{2}-\d{2}$'),
  balance bigint check (balance between -100000000000000 and 100000000000000),
  note text not null default '' check (char_length(note) <= 500),
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.incomes (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  date text not null check (date ~ '^\d{4}-\d{2}-\d{2}$'),
  amount bigint not null check (amount between 0 and 100000000000000),
  source text not null default 'salary' check (char_length(source) <= 40),
  note text not null default '' check (char_length(note) <= 500),
  after_checkin boolean not null default false,
  counts_in_previous boolean not null default false,
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.expenses (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  date text not null check (date ~ '^\d{4}-\d{2}-\d{2}$'),
  amount bigint not null check (amount between 0 and 100000000000000),
  category_id text check (char_length(category_id) <= 64),
  note text not null default '' check (char_length(note) <= 500),
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.categories (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  name text not null check (char_length(name) between 1 and 60),
  color bigint not null,
  sort integer not null default 0,
  archived boolean not null default false,
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.bills (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (char_length(id) between 1 and 64),
  name text not null check (char_length(name) between 1 and 60),
  amount bigint not null check (amount between 0 and 100000000000000),
  paid_for_cycle text check (paid_for_cycle ~ '^\d{4}-\d{2}-\d{2}$'),
  archived boolean not null default false,
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

create table public.cycle_starts (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (id ~ '^\d{4}-\d{2}-\d{2}$'),
  updated_at bigint not null default 0,
  deleted_at bigint,
  server_updated_at timestamptz not null default now(),
  primary key (user_id, id)
);

-- Runs on every insert/update of every table.
--  * stamps server_updated_at so phones can pull "what changed since";
--  * caps updated_at one minute ahead of the server clock, so a phone with a wrong clock
--    cannot win every conflict;
--  * on update, ignores a write that is not newer than the stored row, so an old offline edit
--    can never overwrite a newer one and retries are harmless.
create function public.bc_touch() returns trigger
language plpgsql
set search_path = ''
as $$
declare
  ceiling bigint := (extract(epoch from now()) * 1000)::bigint + 60000;
begin
  new.server_updated_at := now();
  if new.updated_at > ceiling then
    new.updated_at := ceiling;
  end if;
  if tg_op = 'UPDATE' and new.updated_at <= old.updated_at then
    return null;
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array['settings','checkins','incomes','expenses','categories','bills','cycle_starts'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create index %I on public.%I (user_id, server_updated_at, id)', t || '_pull_idx', t);
    execute format('create trigger %I before insert or update on public.%I for each row execute function public.bc_touch()', t || '_touch', t);
    -- Rows are never hard-deleted by the app (deletes are soft), so there is no delete policy.
    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t || '_select', t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t || '_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t || '_update', t);
    -- Supabase no longer exposes new tables to the API automatically: grant explicitly, and only
    -- to signed-in users.
    execute format('revoke all on public.%I from anon, authenticated', t);
    execute format('grant select, insert, update on public.%I to authenticated', t);
    execute format('grant select, insert, update, delete on public.%I to service_role', t);
  end loop;
end;
$$;

-- "Delete my account": removes the caller's auth user; every table above cascades.
create function public.delete_my_account() returns void
language sql
security definer
set search_path = ''
as $$
  delete from auth.users where id = (select auth.uid());
$$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
