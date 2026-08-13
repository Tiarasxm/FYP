-- =========================================================
-- Follow Requests + Leaderboard Migration SQL
-- Run this in Supabase SQL Editor
-- =========================================================

-- 1. Add status and updated_at columns to follows table
alter table public.follows
add column if not exists status text not null default 'accepted';

alter table public.follows
add column if not exists updated_at timestamptz not null default now();

-- Add check constraint for valid status values
alter table public.follows
drop constraint if exists follows_status_check;

alter table public.follows
add constraint follows_status_check
check (status in ('pending', 'accepted', 'declined'));

-- Update existing follows to accepted (they were instant follows before)
update public.follows set status = 'accepted' where status is null or status = '';

-- 2. RLS: Users can see pending requests where they are the following_id (target)
drop policy if exists "Authenticated users can read follows" on public.follows;

create policy "Authenticated users can read follows"
on public.follows
for select
to authenticated
using (
  follower_id = auth.uid()
  or following_id = auth.uid()
);

-- 3. RPC: Request to follow a user
-- If target is private, creates a pending request. If public, follows immediately.
create or replace function public.request_follow(p_target_uuid uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_private boolean;
  v_existing text;
  v_status text;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_target_uuid = auth.uid() then
    raise exception 'Cannot follow yourself';
  end if;

  -- Check if already following or pending
  select status into v_existing
  from public.follows
  where follower_id = auth.uid() and following_id = p_target_uuid;

  if v_existing is not null then
    return v_existing;
  end if;

  -- Check if target is private
  select is_private into v_is_private
  from public.profiles
  where id = p_target_uuid;

  if v_is_private then
    v_status := 'pending';
  else
    v_status := 'accepted';
  end if;

  insert into public.follows (follower_id, following_id, status, updated_at)
  values (auth.uid(), p_target_uuid, v_status, now())
  on conflict (follower_id, following_id)
  do update set status = excluded.status, updated_at = now();

  return v_status;
end;
$$;

grant execute on function public.request_follow(uuid)
to authenticated;

-- 4. RPC: Respond to a follow request (accept or decline)
create or replace function public.respond_follow_request(
  p_follower_uuid uuid,
  p_accept boolean
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

  -- Only the target user (following_id) can respond
  update public.follows
  set status = case when p_accept then 'accepted' else 'declined' end,
      updated_at = now()
  where follower_id = p_follower_uuid
    and following_id = auth.uid()
    and status = 'pending';

  if not found then
    raise exception 'No pending follow request found';
  end if;

  return true;
end;
$$;

grant execute on function public.respond_follow_request(uuid, boolean)
to authenticated;

-- 5. RPC: Unfollow (cancel request or remove follow)
create or replace function public.unfollow(p_target_uuid uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.follows
  where follower_id = auth.uid()
    and following_id = p_target_uuid;

  return true;
end;
$$;

grant execute on function public.unfollow(uuid)
to authenticated;

-- 6. Updated leaderboard RPC: only shows users the caller follows (accepted) + self
drop function if exists public.get_steps_leaderboard(date, date);

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
    and (
      p.id = auth.uid()
      or exists (
        select 1
        from public.follows f
        where f.follower_id = auth.uid()
          and f.following_id = p.id
          and f.status = 'accepted'
      )
    )
  group by p.id, p.full_name, p.avatar_url
  order by total_steps desc, display_name asc;
end;
$$;

grant execute on function public.get_steps_leaderboard(date, date)
to authenticated;

-- 7. Ensure steps_leaderboard_visible column exists
alter table public.profiles
add column if not exists steps_leaderboard_visible boolean not null default false;

-- 8. Ensure daily_health_metrics table exists
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

create index if not exists daily_health_metrics_leaderboard_idx
on public.daily_health_metrics (metric_date, profile_id);

create index if not exists daily_health_metrics_profile_date_idx
on public.daily_health_metrics(profile_id, metric_date);

alter table public.daily_health_metrics enable row level security;

-- 9. Ensure realtime publication includes tables used by app subscriptions
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'chat_messages'
  ) then
    alter publication supabase_realtime add table public.chat_messages;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'chat_rooms'
  ) then
    alter publication supabase_realtime add table public.chat_rooms;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'chat_tags'
  ) then
    alter publication supabase_realtime add table public.chat_tags;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'free_plans'
  ) then
    alter publication supabase_realtime add table public.free_plans;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'saved_plans'
  ) then
    alter publication supabase_realtime add table public.saved_plans;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'workout_logs'
  ) then
    alter publication supabase_realtime add table public.workout_logs;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'workout_exercises'
  ) then
    alter publication supabase_realtime add table public.workout_exercises;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'daily_health_metrics'
  ) then
    alter publication supabase_realtime add table public.daily_health_metrics;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'follows'
  ) then
    alter publication supabase_realtime add table public.follows;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end;
$$;

-- 10. Ensure daily_health_metrics RLS policies
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
