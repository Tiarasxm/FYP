-- =========================================================
-- Leaderboard + Health Metrics Migration SQL
-- Run this in Supabase SQL Editor
-- =========================================================

-- 1. Add steps_leaderboard_visible column to profiles
alter table public.profiles
add column if not exists steps_leaderboard_visible boolean not null default false;

comment on column public.profiles.steps_leaderboard_visible is
'If true, this user joins the steps leaderboard and can view other joined users. If false, this user is hidden and cannot view the leaderboard.';

-- 2. Helpful indexes
create index if not exists daily_health_metrics_leaderboard_idx
on public.daily_health_metrics (metric_date, profile_id);

create index if not exists profiles_steps_leaderboard_visible_idx
on public.profiles (steps_leaderboard_visible);

-- 3. RPC: user joins or hides from steps leaderboard
create or replace function public.set_steps_leaderboard_visible(
  p_visible boolean
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.profiles
  set steps_leaderboard_visible = coalesce(p_visible, false)
  where id = auth.uid();

  if not found then
    raise exception 'Profile not found';
  end if;

  return coalesce(p_visible, false);
end;
$$;

grant execute on function public.set_steps_leaderboard_visible(boolean)
to authenticated;

-- 4. RPC: weekly steps leaderboard (includes avatar_url)
create or replace function public.get_steps_leaderboard(
  p_start_date date,
  p_end_date date
)
returns table (
  profile_id uuid,
  display_name text,
  avatar_url text,
  total_steps bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_start_date is null or p_end_date is null or p_end_date < p_start_date then
    return;
  end if;

  if not exists (
    select 1
    from public.profiles caller
    where caller.id = auth.uid()
      and caller.steps_leaderboard_visible is true
      and coalesce(caller.status, 'active') <> 'deleted'
      and lower(coalesce(caller.user_type, 'free')) in ('free', 'priority')
  ) then
    return;
  end if;

  return query
  select
    p.id as profile_id,
    coalesce(
      nullif(trim(p.full_name), ''),
      'User ' || substring(p.id::text, 1, 8)
    ) as display_name,
    p.avatar_url as avatar_url,
    coalesce(sum(coalesce(d.steps, 0)), 0)::bigint as total_steps
  from public.profiles p
  left join public.daily_health_metrics d
    on d.profile_id = p.id
   and d.metric_date >= p_start_date
   and d.metric_date <= p_end_date
  where p.steps_leaderboard_visible is true
    and coalesce(p.status, 'active') <> 'deleted'
    and lower(coalesce(p.user_type, 'free')) in ('free', 'priority')
  group by p.id, p.full_name, p.avatar_url
  order by total_steps desc, display_name asc;
end;
$$;

grant execute on function public.get_steps_leaderboard(date, date)
to authenticated;

-- 5. Ensure daily_health_metrics table exists with calories_burned column
create table if not exists public.daily_health_metrics (
  metric_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  metric_date date not null,
  steps integer not null default 0,
  heart_rate integer,
  heart_rate_measured_at timestamptz,
  calories_burned numeric not null default 0,
  synced_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, metric_date)
);

alter table public.daily_health_metrics
add column if not exists heart_rate_measured_at timestamptz;

alter table public.daily_health_metrics
add column if not exists calories_burned numeric not null default 0;

create index if not exists daily_health_metrics_profile_id_idx
on public.daily_health_metrics(profile_id);

create index if not exists daily_health_metrics_profile_date_idx
on public.daily_health_metrics(profile_id, metric_date);

alter table public.daily_health_metrics enable row level security;

drop policy if exists "Users can view own daily health metrics" on public.daily_health_metrics;
drop policy if exists "Users can insert own daily health metrics" on public.daily_health_metrics;
drop policy if exists "Users can update own daily health metrics" on public.daily_health_metrics;
drop policy if exists "Users can delete own daily health metrics" on public.daily_health_metrics;

create policy "Users can view own daily health metrics"
on public.daily_health_metrics
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own daily health metrics"
on public.daily_health_metrics
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own daily health metrics"
on public.daily_health_metrics
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own daily health metrics"
on public.daily_health_metrics
for delete
to authenticated
using (profile_id = auth.uid());
