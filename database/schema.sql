-- =========================================================
-- ShapeRush Supabase Schema
-- Matches the actual deployed database.
-- Safe to re-run (uses IF NOT EXISTS / DROP IF EXISTS).
-- =========================================================

create extension if not exists pgcrypto;

-- =========================================================
-- 1. PROFILES TABLE
-- =========================================================

create table if not exists public.profiles (
  id uuid references auth.users(id) primary key,
  full_name text,
  email text,
  gender text,
  user_type text default 'Free',
  status text default 'active',
  created_at timestamptz default now()
);

alter table public.profiles enable row level security;

-- PROFILE EXTRA FIELDS

alter table public.profiles
add column if not exists gender text;

alter table public.profiles
add column if not exists date_of_birth date;

alter table public.profiles
add column if not exists weight_kg numeric;

alter table public.profiles
add column if not exists height_cm numeric;

alter table public.profiles
add column if not exists avatar_url text;

alter table public.profiles
add column if not exists bio text default '';

alter table public.profiles
add column if not exists activity_level text;

alter table public.profiles
add column if not exists fitness_goal text;

alter table public.profiles
add column if not exists has_completed_onboarding boolean default false;

alter table public.profiles
add column if not exists is_private boolean not null default false;

-- PROFILE AVATAR STORAGE

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile-avatars',
  'profile-avatars',
  true,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can read profile avatars" on storage.objects;
drop policy if exists "Users can upload own profile avatar" on storage.objects;
drop policy if exists "Users can update own profile avatar" on storage.objects;
drop policy if exists "Users can delete own profile avatar" on storage.objects;

create policy "Anyone can read profile avatars"
on storage.objects
for select
to public
using (
  bucket_id = 'profile-avatars'
);

create policy "Users can upload own profile avatar"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own profile avatar"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own profile avatar"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Steps Leaderboard Privacy + Weekly Ranking
-- Real step data table:
--   public.daily_health_metrics(profile_id, metric_date, steps)

-- 1. Add user privacy setting
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


-- 4. RPC: weekly steps leaderboard
-- Privacy rule:
--   - Caller must have steps_leaderboard_visible = true.
--   - Result only includes users with steps_leaderboard_visible = true.
--   - If caller is hidden, this function returns empty rows.
create or replace function public.get_steps_leaderboard(
  p_start_date date,
  p_end_date date
)
returns table (
  profile_id uuid,
  display_name text,
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
    coalesce(sum(coalesce(d.steps, 0)), 0)::bigint as total_steps
  from public.profiles p
  left join public.daily_health_metrics d
    on d.profile_id = p.id
   and d.metric_date >= p_start_date
   and d.metric_date <= p_end_date
  where p.steps_leaderboard_visible is true
    and coalesce(p.status, 'active') <> 'deleted'
    and lower(coalesce(p.user_type, 'free')) in ('free', 'priority')
  group by p.id, p.full_name
  order by total_steps desc, display_name asc;
end;
$$;

grant execute on function public.get_steps_leaderboard(date, date)
to authenticated;

-- =========================================================
-- 1b. PRIORITY USER TABLE
-- =========================================================

create table if not exists public.priority_user (
  profile_id uuid primary key,
  subscribed_at timestamptz,
  expires_at timestamptz,
  constraint priority_user_profile_id_fkey foreign key (profile_id) references public.profiles(id)
);

-- =========================================================
-- 1c. FITNESS PROFESSIONAL TABLE
-- =========================================================

create table if not exists public.fitness_professional (
  profile_id uuid primary key,
  display_name text,
  bio text,
  experience text,
  specializations text,
  certificate_name text,
  certificate_path text,
  approved boolean default false,
  submitted_at timestamptz,
  constraint fitness_professional_profile_id_fkey foreign key (profile_id) references public.profiles(id)
);

-- =========================================================
-- 1d. ADMIN TABLE
-- =========================================================

create table if not exists public.admin (
  profile_id uuid primary key,
  role text default 'admin',
  constraint admin_profile_id_fkey foreign key (profile_id) references public.profiles(id)
);

-- =========================================================
-- 2. ADMIN ROLE FUNCTION
-- =========================================================

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.admin
    where profile_id = auth.uid()
  );
$$;

grant execute on function public.is_admin() to anon, authenticated;

-- =========================================================
-- 3. PROFILES POLICIES
-- =========================================================

drop policy if exists "Allow insert on profiles for new users" on public.profiles;
drop policy if exists "Allow users to read own profile" on public.profiles;
drop policy if exists "Allow users to update own profile" on public.profiles;
drop policy if exists "Allow dashboard read profiles" on public.profiles;
drop policy if exists "Allow public read profiles" on public.profiles;
drop policy if exists "Enable Public Profile Reads" on public.profiles;
drop policy if exists "Allow admin update profiles status" on public.profiles;
drop policy if exists "Allow admin users page update status" on public.profiles;
drop policy if exists "Allow admin update professionals status" on public.profiles;
drop policy if exists "Allow admin update profiles" on public.profiles;
drop policy if exists "Admins can read all profiles" on public.profiles;
drop policy if exists "Admins can update all profiles" on public.profiles;
drop policy if exists "Authenticated users can read public profiles" on public.profiles;
drop policy if exists "Users can read own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;

create policy "Allow insert on profiles for new users"
on public.profiles
for insert
to anon, authenticated
with check (true);

create policy "Users can read own profile"
on public.profiles
for select
to authenticated
using (
  auth.uid() = id
  or public.is_admin()
);

create policy "Authenticated users can read public profiles"
on public.profiles
for select
to authenticated
using (status = 'active');

create policy "Users can update own profile"
on public.profiles
for update
to authenticated
using (
  auth.uid() = id
  or public.is_admin()
)
with check (
  auth.uid() = id
  or public.is_admin()
);

-- =========================================================
-- 4. AUTO CREATE PROFILE TRIGGER
-- =========================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata_role text;
  database_user_type text;
begin
  metadata_role := NEW.raw_user_meta_data->>'role';

  database_user_type :=
    case
      when metadata_role in ('Fitness professional', 'fitness_professional') then 'Fitness professional'
      when metadata_role = 'Priority' then 'Priority'
      else 'Free'
    end;

  insert into public.profiles (
    id,
    full_name,
    email,
    user_type,
    status,
    created_at
  )
  values (
    NEW.id,
    coalesce(
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name',
      split_part(NEW.email, '@', 1)
    ),
    NEW.email,
    database_user_type,
    'active',
    NEW.created_at
  )
  on conflict (id) do nothing;

  return NEW;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_new_user();

-- =========================================================
-- 5. FREE PLANS TABLE
-- =========================================================

create table if not exists public.free_plans (
  free_plan_id uuid primary key default gen_random_uuid(),
  professional_id uuid,
  plan_name text,
  category text,
  status text default 'draft',
  created_at timestamptz default now(),
  tag1 varchar,
  tag2 varchar,
  tag3 varchar,
  visibility text not null default 'public',
  duration_weeks integer,
  constraint free_plans_professional_id_fkey foreign key (professional_id) references public.fitness_professional(profile_id)
);

alter table public.free_plans enable row level security;

drop policy if exists "Professionals can manage own free plans" on public.free_plans;
drop policy if exists "Users can read public free plans" on public.free_plans;
drop policy if exists "Admins can manage all free plans" on public.free_plans;

create policy "Professionals can manage own free plans"
on public.free_plans
for all
to authenticated
using (professional_id = auth.uid() or public.is_admin())
with check (professional_id = auth.uid() or public.is_admin());

create policy "Users can read public free plans"
on public.free_plans
for select
to authenticated
using (visibility = 'public' or professional_id = auth.uid() or public.is_admin());

-- =========================================================
-- 6. PERSONALIZED PLANS TABLE
-- =========================================================

create table if not exists public.personalized_plans (
  personalized_plan_id uuid primary key default gen_random_uuid(),
  professional_id uuid,
  client_id uuid,
  plan_name text,
  created_at timestamptz default now(),
  duration_weeks integer,
  status text not null default 'draft',
  constraint personalized_plans_professional_id_fkey foreign key (professional_id) references public.fitness_professional(profile_id),
  constraint personalized_plans_client_id_fkey foreign key (client_id) references public.profiles(id)
);

alter table public.personalized_plans enable row level security;

drop policy if exists "Professionals can manage own personalized plans" on public.personalized_plans;
drop policy if exists "Clients can read own personalized plans" on public.personalized_plans;
drop policy if exists "Admins can manage all personalized plans" on public.personalized_plans;

create policy "Professionals can manage own personalized plans"
on public.personalized_plans
for all
to authenticated
using (professional_id = auth.uid() or public.is_admin())
with check (professional_id = auth.uid() or public.is_admin());

create policy "Clients can read own personalized plans"
on public.personalized_plans
for select
to authenticated
using (client_id = auth.uid() or professional_id = auth.uid() or public.is_admin());

-- =========================================================
-- 7. REVIEWS TABLE
-- =========================================================

create table if not exists public.reviews (
  review_id uuid primary key default gen_random_uuid(),
  reviewer_id uuid,
  rating integer,
  feedback text,
  media_path text,
  ai_analysis text,
  featured_on_website boolean default false,
  submitted_at timestamptz default now(),
  constraint reviews_reviewer_id_fkey foreign key (reviewer_id) references public.profiles(id)
);

alter table public.reviews
add column if not exists professional_id uuid;

alter table public.reviews
drop constraint if exists reviews_professional_id_fkey;

alter table public.reviews
add constraint reviews_professional_id_fkey foreign key (professional_id) references public.profiles(id) on delete cascade;

alter table public.reviews
drop constraint if exists reviews_one_per_client_key;

alter table public.reviews
add constraint reviews_one_per_client_key unique (reviewer_id, professional_id);

alter table public.reviews enable row level security;

drop policy if exists "Users can create own reviews" on public.reviews;
drop policy if exists "Users can update own reviews" on public.reviews;
drop policy if exists "Anyone can read reviews" on public.reviews;

create policy "Users can create own reviews"
on public.reviews for insert to authenticated
with check (
  reviewer_id = auth.uid()
  and professional_id is not null
  and professional_id <> auth.uid()
);

create policy "Users can update own reviews"
on public.reviews for update to authenticated
using (reviewer_id = auth.uid())
with check (reviewer_id = auth.uid());

create policy "Anyone can read reviews"
on public.reviews for select to authenticated
using (true);

-- =========================================================
-- 8. REPORTS TABLE
-- =========================================================

create table if not exists public.reports (
  report_id uuid primary key default gen_random_uuid(),
  reporter_id uuid,
  content_type text,
  report_type text,
  reported_user_id uuid,
  post_id uuid,
  details text,
  status text default 'pending',
  submitted_at timestamptz default now(),
  constraint reports_reporter_id_fkey foreign key (reporter_id) references public.profiles(id),
  constraint reports_reported_user_id_fkey foreign key (reported_user_id) references public.profiles(id) on delete cascade
);

alter table public.reports enable row level security;

create index if not exists reports_reporter_id_idx
on public.reports(reporter_id);

create index if not exists reports_reported_user_id_idx
on public.reports(reported_user_id);

create index if not exists reports_post_id_idx
on public.reports(post_id);

create unique index if not exists reports_one_user_report_idx
on public.reports(reporter_id, reported_user_id)
where content_type = 'user' and reported_user_id is not null;

create unique index if not exists reports_one_post_report_idx
on public.reports(reporter_id, post_id)
where content_type = 'post' and post_id is not null;

drop policy if exists "Users can create social reports" on public.reports;
drop policy if exists "Users can read own social reports" on public.reports;

create policy "Users can create social reports"
on public.reports for insert to authenticated
with check (
  reporter_id = auth.uid()
  and (
    (content_type = 'post' and post_id is not null and reported_user_id is not null and reported_user_id <> auth.uid())
    or
    (content_type = 'user' and post_id is null and reported_user_id is not null and reported_user_id <> auth.uid())
  )
);

create policy "Users can read own social reports"
on public.reports for select to authenticated
using (reporter_id = auth.uid());

-- =========================================================
-- 9. AUDIT LOGS TABLE
-- =========================================================

create table if not exists public.audit_logs (
  audit_log_id uuid primary key default gen_random_uuid(),
  admin_id uuid,
  action text,
  target text,
  target_type text,
  created_at timestamptz default now(),
  admin_email text,
  constraint audit_logs_admin_id_fkey foreign key (admin_id) references public.admin(profile_id)
);

alter table public.audit_logs enable row level security;

-- =========================================================
-- 11. WEBSITE CONTENT TABLE
-- =========================================================

create table if not exists public.website_content (
  section_key text primary key,
  content jsonb,
  updated_by uuid,
  updated_at timestamptz default now(),
  constraint website_content_updated_by_fkey foreign key (updated_by) references public.profiles(id)
);

alter table public.website_content enable row level security;

-- =========================================================
-- 11. EXERCISE LIBRARY TABLE
-- =========================================================

create table if not exists public.exercise_library (
  exercise_id uuid primary key default gen_random_uuid(),
  professional_id uuid not null,
  name varchar not null,
  muscle_group varchar,
  equipment varchar,
  category varchar,
  default_rep_min integer,
  default_rep_max integer,
  default_rest_sec integer,
  instructions text,
  media_path varchar,
  status text not null default 'active',
  created_at timestamptz default now(),
  constraint exercise_library_professional_id_fkey foreign key (professional_id) references public.fitness_professional(profile_id)
);

-- =========================================================
-- 12. PLAN DAYS TABLE
-- =========================================================

create table if not exists public.plan_days (
  plan_day_id uuid primary key default gen_random_uuid(),
  free_plan_id uuid not null,
  week_number integer not null default 1,
  day_number integer not null,
  day_name varchar,
  is_rest_day boolean not null default false,
  constraint plan_days_free_plan_id_fkey foreign key (free_plan_id) references public.free_plans(free_plan_id)
);

-- =========================================================
-- 13. PLAN EXERCISES TABLE
-- =========================================================

create table if not exists public.plan_exercises (
  plan_exercise_id uuid primary key default gen_random_uuid(),
  plan_day_id uuid not null,
  exercise_id uuid not null,
  order_index integer not null default 0,
  sets integer,
  rep_min integer,
  rep_max integer,
  rest_sec integer,
  constraint plan_exercises_plan_day_id_fkey foreign key (plan_day_id) references public.plan_days(plan_day_id),
  constraint plan_exercises_exercise_id_fkey foreign key (exercise_id) references public.exercise_library(exercise_id)
);

-- =========================================================
-- 14. PERSONALIZED PLAN DAYS TABLE
-- =========================================================

create table if not exists public.personalized_plan_days (
  personalized_plan_day_id uuid primary key default gen_random_uuid(),
  personalized_plan_id uuid not null,
  week_number integer not null default 1,
  day_number integer not null,
  day_name varchar,
  is_rest_day boolean not null default false,
  constraint personalized_plan_days_personalized_plan_id_fkey foreign key (personalized_plan_id) references public.personalized_plans(personalized_plan_id)
);

alter table public.personalized_plan_days enable row level security;

drop policy if exists "Professionals can manage own personalized plan days" on public.personalized_plan_days;
drop policy if exists "Clients can read own personalized plan days" on public.personalized_plan_days;

create policy "Professionals can manage own personalized plan days"
on public.personalized_plan_days
for all
to authenticated
using (
  exists (
    select 1 from public.personalized_plans
    where personalized_plan_id = personalized_plan_days.personalized_plan_id
      and (professional_id = auth.uid() or public.is_admin())
  )
)
with check (
  exists (
    select 1 from public.personalized_plans
    where personalized_plan_id = personalized_plan_days.personalized_plan_id
      and (professional_id = auth.uid() or public.is_admin())
  )
);

create policy "Clients can read own personalized plan days"
on public.personalized_plan_days
for select
to authenticated
using (
  exists (
    select 1 from public.personalized_plans
    where personalized_plan_id = personalized_plan_days.personalized_plan_id
      and (client_id = auth.uid() or professional_id = auth.uid() or public.is_admin())
  )
);

-- =========================================================
-- 15. PERSONALIZED PLAN EXERCISES TABLE
-- =========================================================

create table if not exists public.personalized_plan_exercises (
  personalized_plan_exercise_id uuid primary key default gen_random_uuid(),
  personalized_plan_day_id uuid not null,
  exercise_id uuid not null,
  order_index integer not null default 0,
  sets integer,
  rep_min integer,
  rep_max integer,
  rest_sec integer,
  constraint personalized_plan_exercises_personalized_plan_day_id_fkey foreign key (personalized_plan_day_id) references public.personalized_plan_days(personalized_plan_day_id),
  constraint personalized_plan_exercises_exercise_id_fkey foreign key (exercise_id) references public.exercise_library(exercise_id)
);

alter table public.personalized_plan_exercises enable row level security;

drop policy if exists "Professionals can manage own personalized plan exercises" on public.personalized_plan_exercises;
drop policy if exists "Clients can read own personalized plan exercises" on public.personalized_plan_exercises;

create policy "Professionals can manage own personalized plan exercises"
on public.personalized_plan_exercises
for all
to authenticated
using (
  exists (
    select 1
    from public.personalized_plan_days ppd
    join public.personalized_plans pp on pp.personalized_plan_id = ppd.personalized_plan_id
    where ppd.personalized_plan_day_id = personalized_plan_exercises.personalized_plan_day_id
      and (pp.professional_id = auth.uid() or public.is_admin())
  )
)
with check (
  exists (
    select 1
    from public.personalized_plan_days ppd
    join public.personalized_plans pp on pp.personalized_plan_id = ppd.personalized_plan_id
    where ppd.personalized_plan_day_id = personalized_plan_exercises.personalized_plan_day_id
      and (pp.professional_id = auth.uid() or public.is_admin())
  )
);

create policy "Clients can read own personalized plan exercises"
on public.personalized_plan_exercises
for select
to authenticated
using (
  exists (
    select 1
    from public.personalized_plan_days ppd
    join public.personalized_plans pp on pp.personalized_plan_id = ppd.personalized_plan_id
    where ppd.personalized_plan_day_id = personalized_plan_exercises.personalized_plan_day_id
      and (pp.client_id = auth.uid() or pp.professional_id = auth.uid() or public.is_admin())
  )
);

-- =========================================================
-- 16. SAVED PLANS TABLE
-- =========================================================
-- saved_plans now separates two concepts:
--   is_saved  = shown in Saved Workout Plans
--   is_active = current plan used by Home / Fitness Plan / Active Workout
--
-- This supports:
--   Free users: max 5 saved plans
--   Priority users: unlimited saved plans
--   One active plan per user
--   A plan can be active without being saved

create table if not exists public.saved_plans (
  saved_plan_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  free_plan_id uuid,
  personalized_plan_id uuid,
  is_saved boolean not null default true,
  is_active boolean not null default false,
  saved_at timestamptz not null default now(),
  constraint saved_plans_profile_id_fkey foreign key (profile_id) references public.profiles(id),
  constraint saved_plans_free_plan_id_fkey foreign key (free_plan_id) references public.free_plans(free_plan_id),
  constraint saved_plans_personalized_plan_id_fkey foreign key (personalized_plan_id) references public.personalized_plans(personalized_plan_id)
);

-- Safe migration for databases where saved_plans already existed before
-- is_saved / is_active were added.
alter table public.saved_plans
add column if not exists is_saved boolean not null default true;

alter table public.saved_plans
add column if not exists is_active boolean not null default false;

alter table public.saved_plans
alter column saved_at set default now();

update public.saved_plans
set saved_at = now()
where saved_at is null;

alter table public.saved_plans
alter column saved_at set not null;

-- Treat old existing saved_plans rows as saved rows.
update public.saved_plans
set is_saved = true
where is_saved is null;

update public.saved_plans
set is_active = false
where is_active is null;

-- If the database had old saved rows but no active row yet,
-- keep the previous behavior by making the latest saved row active.
with users_without_active as (
  select distinct sp.profile_id
  from public.saved_plans sp
  where not exists (
    select 1
    from public.saved_plans active_sp
    where active_sp.profile_id = sp.profile_id
      and active_sp.is_active = true
  )
),
latest_saved as (
  select distinct on (sp.profile_id)
    sp.saved_plan_id
  from public.saved_plans sp
  join users_without_active uwa on uwa.profile_id = sp.profile_id
  where sp.is_saved = true
  order by sp.profile_id, sp.saved_at desc, sp.saved_plan_id
)
update public.saved_plans sp
set is_active = true
where sp.saved_plan_id in (
  select saved_plan_id from latest_saved
);

-- If older data accidentally has multiple active plans for a user,
-- keep only the newest one active.
with ranked_active as (
  select
    saved_plan_id,
    row_number() over (
      partition by profile_id
      order by saved_at desc, saved_plan_id
    ) as rn
  from public.saved_plans
  where is_active = true
)
update public.saved_plans
set is_active = false
where saved_plan_id in (
  select saved_plan_id
  from ranked_active
  where rn > 1
);

-- Merge duplicate saved free-plan rows before adding the unique index.
with ranked_free as (
  select
    saved_plan_id,
    bool_or(is_saved) over (
      partition by profile_id, free_plan_id
    ) as merged_is_saved,
    bool_or(is_active) over (
      partition by profile_id, free_plan_id
    ) as merged_is_active,
    row_number() over (
      partition by profile_id, free_plan_id
      order by is_active desc, is_saved desc, saved_at desc, saved_plan_id
    ) as rn
  from public.saved_plans
  where free_plan_id is not null
)
update public.saved_plans sp
set
  is_saved = ranked_free.merged_is_saved,
  is_active = ranked_free.merged_is_active
from ranked_free
where sp.saved_plan_id = ranked_free.saved_plan_id
  and ranked_free.rn = 1;

with ranked_free as (
  select
    saved_plan_id,
    row_number() over (
      partition by profile_id, free_plan_id
      order by is_active desc, is_saved desc, saved_at desc, saved_plan_id
    ) as rn
  from public.saved_plans
  where free_plan_id is not null
)
delete from public.saved_plans sp
using ranked_free
where sp.saved_plan_id = ranked_free.saved_plan_id
  and ranked_free.rn > 1;

-- Merge duplicate saved personalized-plan rows before adding the unique index.
with ranked_personalized as (
  select
    saved_plan_id,
    bool_or(is_saved) over (
      partition by profile_id, personalized_plan_id
    ) as merged_is_saved,
    bool_or(is_active) over (
      partition by profile_id, personalized_plan_id
    ) as merged_is_active,
    row_number() over (
      partition by profile_id, personalized_plan_id
      order by is_active desc, is_saved desc, saved_at desc, saved_plan_id
    ) as rn
  from public.saved_plans
  where personalized_plan_id is not null
)
update public.saved_plans sp
set
  is_saved = ranked_personalized.merged_is_saved,
  is_active = ranked_personalized.merged_is_active
from ranked_personalized
where sp.saved_plan_id = ranked_personalized.saved_plan_id
  and ranked_personalized.rn = 1;

with ranked_personalized as (
  select
    saved_plan_id,
    row_number() over (
      partition by profile_id, personalized_plan_id
      order by is_active desc, is_saved desc, saved_at desc, saved_plan_id
    ) as rn
  from public.saved_plans
  where personalized_plan_id is not null
)
delete from public.saved_plans sp
using ranked_personalized
where sp.saved_plan_id = ranked_personalized.saved_plan_id
  and ranked_personalized.rn > 1;

-- After duplicate merge, ensure only one active row per user again.
with ranked_active as (
  select
    saved_plan_id,
    row_number() over (
      partition by profile_id
      order by saved_at desc, saved_plan_id
    ) as rn
  from public.saved_plans
  where is_active = true
)
update public.saved_plans
set is_active = false
where saved_plan_id in (
  select saved_plan_id
  from ranked_active
  where rn > 1
);

create index if not exists saved_plans_profile_id_idx
on public.saved_plans(profile_id);

drop index if exists saved_plans_one_active_per_user;

create unique index saved_plans_one_active_per_user
on public.saved_plans(profile_id)
where is_active = true;

drop index if exists saved_plans_unique_free_plan_per_user;

create unique index saved_plans_unique_free_plan_per_user
on public.saved_plans(profile_id, free_plan_id)
where free_plan_id is not null;

drop index if exists saved_plans_unique_personalized_plan_per_user;

create unique index saved_plans_unique_personalized_plan_per_user
on public.saved_plans(profile_id, personalized_plan_id)
where personalized_plan_id is not null;

create index if not exists saved_plans_saved_list_idx
on public.saved_plans(profile_id, saved_at desc)
where is_saved = true;

-- Enforce the Free-plan saved limit at database level.
-- Priority users are unlimited.
create or replace function public.enforce_saved_plan_limit()
returns trigger as $$
declare
  user_type_value text;
  existing_saved_count integer;
begin
  if new.is_saved = true then
    select lower(coalesce(user_type, 'free'))
    into user_type_value
    from public.profiles
    where id = new.profile_id;

    if coalesce(user_type_value, 'free') <> 'priority' then
      select count(*)
      into existing_saved_count
      from public.saved_plans
      where profile_id = new.profile_id
        and is_saved = true
        and saved_plan_id is distinct from new.saved_plan_id;

      if existing_saved_count >= 5 then
        raise exception 'Free users can save at most 5 workout plans. Delete a saved plan or upgrade to Priority.';
      end if;
    end if;
  end if;

  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists saved_plans_limit_trigger on public.saved_plans;

create trigger saved_plans_limit_trigger
before insert or update of profile_id, is_saved
on public.saved_plans
for each row
execute function public.enforce_saved_plan_limit();

alter table public.saved_plans enable row level security;

drop policy if exists "Users can manage own saved plans" on public.saved_plans;

create policy "Users can manage own saved plans"
on public.saved_plans
for all
to authenticated
using (profile_id = auth.uid() or public.is_admin())
with check (profile_id = auth.uid() or public.is_admin());


-- =========================================================
-- 17. WORKOUT LOGS TABLE
-- =========================================================

create table if not exists public.workout_logs (
  workout_log_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  free_plan_id uuid,
  personalized_plan_id uuid,
  performed_at timestamptz default now(),
  duration_min integer,
  source text,
  constraint workout_logs_profile_id_fkey foreign key (profile_id) references public.profiles(id),
  constraint workout_logs_free_plan_id_fkey foreign key (free_plan_id) references public.free_plans(free_plan_id),
  constraint workout_logs_personalized_plan_id_fkey foreign key (personalized_plan_id) references public.personalized_plans(personalized_plan_id)
);

-- Tracks which specific plan day (free_plans -> plan_days, or personalized_plans ->
-- personalized_plan_days) a workout log corresponds to, so the app can determine
-- day-by-day progression through a plan.
alter table public.workout_logs
add column if not exists plan_day_id uuid;

-- =========================================================
-- 18. WORKOUT EXERCISES TABLE
-- =========================================================

create table if not exists public.workout_exercises (
  workout_exercise_id uuid primary key default gen_random_uuid(),
  workout_log_id uuid not null,
  exercise_id uuid not null,
  sets integer,
  reps integer,
  weight_kg numeric,
  constraint workout_exercises_workout_log_id_fkey foreign key (workout_log_id) references public.workout_logs(workout_log_id),
  constraint workout_exercises_exercise_id_fkey foreign key (exercise_id) references public.exercise_library(exercise_id)
);

-- =========================================================
-- 19. MEAL LOGS TABLE
-- =========================================================

create table if not exists public.meal_logs (
  meal_log_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  meal_type text not null,
  food_name text not null,
  ingredients text,
  calories integer not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  image_url text,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint meal_logs_profile_id_fkey foreign key (profile_id) references public.profiles(id) on delete cascade,
  constraint meal_logs_meal_type_check check (meal_type in ('Breakfast', 'Lunch', 'Dinner', 'Snack')),
  constraint meal_logs_calories_check check (calories >= 0),
  constraint meal_logs_protein_g_check check (protein_g >= 0),
  constraint meal_logs_carbs_g_check check (carbs_g >= 0),
  constraint meal_logs_fat_g_check check (fat_g >= 0)
);

alter table public.meal_logs enable row level security;

drop policy if exists "Users can read own meal logs" on public.meal_logs;
drop policy if exists "Users can insert own meal logs" on public.meal_logs;
drop policy if exists "Users can update own meal logs" on public.meal_logs;
drop policy if exists "Users can delete own meal logs" on public.meal_logs;
drop policy if exists "Admins can manage all meal logs" on public.meal_logs;

create policy "Users can read own meal logs"
on public.meal_logs
for select
to authenticated
using (profile_id = auth.uid() or public.is_admin());

create policy "Users can insert own meal logs"
on public.meal_logs
for insert
to authenticated
with check (profile_id = auth.uid() or public.is_admin());

create policy "Users can update own meal logs"
on public.meal_logs
for update
to authenticated
using (profile_id = auth.uid() or public.is_admin())
with check (profile_id = auth.uid() or public.is_admin());

create policy "Users can delete own meal logs"
on public.meal_logs
for delete
to authenticated
using (profile_id = auth.uid() or public.is_admin());

create policy "Admins can manage all meal logs"
on public.meal_logs
for all
to authenticated
using (public.is_admin())
with check (public.is_admin());

create index if not exists idx_meal_logs_profile_id on public.meal_logs(profile_id);
create index if not exists idx_meal_logs_logged_at on public.meal_logs(logged_at desc);
create index if not exists idx_meal_logs_profile_logged_at on public.meal_logs(profile_id, logged_at desc);
create index if not exists idx_meal_logs_profile_meal_type on public.meal_logs(profile_id, meal_type);

-- =========================================================
-- 20. MEAL IMAGE STORAGE
-- =========================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'meal-images',
  'meal-images',
  true,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can read meal images" on storage.objects;
drop policy if exists "Users can upload own meal images" on storage.objects;
drop policy if exists "Users can update own meal images" on storage.objects;
drop policy if exists "Users can delete own meal images" on storage.objects;

create policy "Anyone can read meal images"
on storage.objects
for select
to public
using (
  bucket_id = 'meal-images'
);

create policy "Users can upload own meal images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'meal-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own meal images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'meal-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'meal-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own meal images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'meal-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- =========================================================
-- 21. CHAT ROOMS TABLE
-- =========================================================

create table if not exists public.chat_rooms (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null,
  professional_id uuid not null,
  status text default 'active',
  last_message_id uuid,
  last_message_at timestamptz,
  created_at timestamptz default now(),
  constraint chat_rooms_client_id_fkey foreign key (client_id) references public.profiles(id),
  constraint chat_rooms_professional_id_fkey foreign key (professional_id) references public.fitness_professional(profile_id),
  constraint chat_rooms_client_professional_unique unique (client_id, professional_id)
);

alter table public.chat_rooms enable row level security;

-- =========================================================
-- 22. CHAT MESSAGES TABLE
-- =========================================================

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null,
  sender_id uuid not null,
  content text,
  message_type text default 'text',
  plan_id uuid,
  is_read boolean default false,
  created_at timestamptz default now(),
  constraint chat_messages_room_id_fkey foreign key (room_id) references public.chat_rooms(id),
  constraint chat_messages_sender_id_fkey foreign key (sender_id) references public.profiles(id)
  -- NOTE: plan_id intentionally has no FK — it can reference free_plans or personalized_plans
);

alter table public.chat_messages enable row level security;

-- Add FK from chat_rooms.last_message_id -> chat_messages.id (deferred because of circular ref)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'chat_rooms_last_message_id_fkey'
  ) then
    alter table public.chat_rooms
    add constraint chat_rooms_last_message_id_fkey
    foreign key (last_message_id) references public.chat_messages(id) on delete set null;
  end if;
end;
$$;

-- =========================================================
-- 23. CHAT TAGS TABLE
-- =========================================================

create table if not exists public.chat_tags (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null,
  professional_id uuid not null,
  tag text not null,
  created_at timestamptz default now(),
  constraint chat_tags_room_id_fkey foreign key (room_id) references public.chat_rooms(id) on delete cascade,
  constraint chat_tags_professional_id_fkey foreign key (professional_id) references public.fitness_professional(profile_id),
  constraint chat_tags_room_professional_tag_unique unique (room_id, professional_id, tag)
);

alter table public.chat_tags enable row level security;

-- =========================================================
-- 24. RLS POLICIES - chat_rooms
-- =========================================================

drop policy if exists "Chat rooms select participants" on public.chat_rooms;
drop policy if exists "Priority users can create chat rooms" on public.chat_rooms;
drop policy if exists "Participants can update chat rooms" on public.chat_rooms;

create policy "Chat rooms select participants"
on public.chat_rooms
for select
to authenticated
using (
  auth.uid() = client_id
  or auth.uid() = professional_id
  or public.is_admin()
);

create policy "Priority users can create chat rooms"
on public.chat_rooms
for insert
to authenticated
with check (
  auth.uid() = client_id
  and exists (
    select 1 from public.priority_user where profile_id = auth.uid()
  )
  and exists (
    select 1 from public.fitness_professional
    where profile_id = chat_rooms.professional_id and approved = true
  )
);

create policy "Participants can update chat rooms"
on public.chat_rooms
for update
to authenticated
using (
  auth.uid() = client_id or auth.uid() = professional_id or public.is_admin()
)
with check (
  auth.uid() = client_id or auth.uid() = professional_id or public.is_admin()
);

-- =========================================================
-- 25. RLS POLICIES - chat_messages
-- =========================================================

drop policy if exists "Chat messages select room participants" on public.chat_messages;
drop policy if exists "Room participants can send messages" on public.chat_messages;
drop policy if exists "Chat participants can insert messages" on public.chat_messages;
drop policy if exists "Recipients can mark messages read" on public.chat_messages;
drop policy if exists "Admins can delete chat messages" on public.chat_messages;

create policy "Chat messages select room participants"
on public.chat_messages
for select
to authenticated
using (
  exists (
    select 1 from public.chat_rooms
    where id = chat_messages.room_id
      and (client_id = auth.uid() or professional_id = auth.uid())
  )
  or public.is_admin()
);

create policy "Room participants can send messages"
on public.chat_messages
for insert
to authenticated
with check (
  sender_id = auth.uid()
  and exists (
    select 1 from public.chat_rooms
    where id = chat_messages.room_id
      and (client_id = auth.uid() or professional_id = auth.uid())
      and status = 'active'
  )
);

create policy "Recipients can mark messages read"
on public.chat_messages
for update
to authenticated
using (
  sender_id <> auth.uid()
  and exists (
    select 1 from public.chat_rooms
    where id = chat_messages.room_id
      and (client_id = auth.uid() or professional_id = auth.uid())
  )
)
with check (
  is_read = true
  and sender_id <> auth.uid()
);

create policy "Admins can delete chat messages"
on public.chat_messages
for delete
to authenticated
using (public.is_admin());

-- =========================================================
-- 26. RLS POLICIES - chat_tags
-- =========================================================

drop policy if exists "Chat tags select by professional" on public.chat_tags;
drop policy if exists "Professionals can manage chat tags" on public.chat_tags;

create policy "Chat tags select by professional"
on public.chat_tags
for select
to authenticated
using (professional_id = auth.uid() or public.is_admin());

create policy "Professionals can manage chat tags"
on public.chat_tags
for all
to authenticated
using (professional_id = auth.uid() or public.is_admin())
with check (professional_id = auth.uid());

-- =========================================================
-- 27. HELPER FUNCTIONS
-- =========================================================

-- Create or reuse a chat room (Priority user only)
create or replace function public.create_chat_room(
  p_client_id uuid,
  p_professional_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_room_id uuid;
begin
  -- Verify caller is a Priority user
  if not exists (select 1 from public.priority_user where profile_id = auth.uid()) then
    raise exception 'Only Priority users can start a chat.';
  end if;

  -- Verify caller matches client_id
  if auth.uid() <> p_client_id then
    raise exception 'You can only create a chat room for yourself.';
  end if;

  -- Verify professional is approved
  if not exists (
    select 1 from public.fitness_professional
    where profile_id = p_professional_id and approved = true
  ) then
    raise exception 'Professional is not available for chat.';
  end if;

  -- Return existing room or create new one
  select id into v_room_id
  from public.chat_rooms
  where client_id = p_client_id and professional_id = p_professional_id;

  if v_room_id is null then
    insert into public.chat_rooms (client_id, professional_id)
    values (p_client_id, p_professional_id)
    returning id into v_room_id;
  end if;

  return v_room_id;
end;
$$;

grant execute on function public.create_chat_room(uuid, uuid) to authenticated;

-- Duplicate a free plan for a client (used when a professional sends a plan via chat)
create or replace function public.duplicate_plan_for_client(
  p_professional_id uuid,
  p_client_id uuid,
  p_free_plan_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_plan_id uuid;
  v_day_record record;
  v_new_day_id uuid;
  v_exercise_record record;
begin
  -- Create the personalized plan from the free plan
  insert into public.personalized_plans (
    professional_id,
    client_id,
    plan_name,
    duration_weeks,
    status
  )
  select
    p_professional_id,
    p_client_id,
    plan_name,
    duration_weeks,
    'active'
  from public.free_plans
  where free_plan_id = p_free_plan_id
  returning personalized_plan_id into v_new_plan_id;

  -- Copy each day and its exercises
  for v_day_record in
    select plan_day_id, week_number, day_number, day_name, is_rest_day
    from public.plan_days
    where free_plan_id = p_free_plan_id
    order by week_number, day_number
  loop
    insert into public.personalized_plan_days (
      personalized_plan_id,
      week_number,
      day_number,
      day_name,
      is_rest_day
    ) values (
      v_new_plan_id,
      v_day_record.week_number,
      v_day_record.day_number,
      v_day_record.day_name,
      v_day_record.is_rest_day
    )
    returning personalized_plan_day_id into v_new_day_id;

    for v_exercise_record in
      select exercise_id, order_index, sets, rep_min, rep_max, rest_sec
      from public.plan_exercises
      where plan_day_id = v_day_record.plan_day_id
      order by order_index
    loop
      insert into public.personalized_plan_exercises (
        personalized_plan_day_id,
        exercise_id,
        order_index,
        sets,
        rep_min,
        rep_max,
        rest_sec
      ) values (
        v_new_day_id,
        v_exercise_record.exercise_id,
        v_exercise_record.order_index,
        v_exercise_record.sets,
        v_exercise_record.rep_min,
        v_exercise_record.rep_max,
        v_exercise_record.rest_sec
      );
    end loop;
  end loop;

  return v_new_plan_id;
end;
$$;

grant execute on function public.duplicate_plan_for_client(uuid, uuid, uuid) to authenticated;

-- Mark all messages in a room as read by the current user
create or replace function public.mark_room_messages_read(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_messages
  set is_read = true
  where room_id = p_room_id
    and sender_id <> auth.uid()
    and is_read = false
    and exists (
      select 1 from public.chat_rooms
      where id = p_room_id
        and (client_id = auth.uid() or professional_id = auth.uid())
    );
end;
$$;

grant execute on function public.mark_room_messages_read(uuid) to authenticated;

-- Get a public-safe profile for chat
create or replace function public.get_public_profile(p_user_id uuid)
returns table (
  id uuid,
  full_name text,
  user_type text,
  display_name text,
  bio text,
  specializations text,
  experience text
)
language sql
security definer
set search_path = public
stable
as $$
  select
    p.id,
    p.full_name,
    p.user_type,
    fp.display_name,
    fp.bio,
    fp.specializations,
    fp.experience
  from public.profiles p
  left join public.fitness_professional fp on fp.profile_id = p.id
  where p.id = p_user_id;
$$;

grant execute on function public.get_public_profile(uuid) to authenticated;

-- =========================================================
-- 28. TRIGGER: update last_message on chat_rooms
-- =========================================================

create or replace function public.handle_chat_message_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_rooms
  set last_message_id = NEW.id, last_message_at = NEW.created_at
  where id = NEW.room_id;
  return NEW;
end;
$$;

drop trigger if exists on_chat_message_inserted on public.chat_messages;

create trigger on_chat_message_inserted
after insert on public.chat_messages
for each row
execute function public.handle_chat_message_insert();

-- =========================================================
-- 29. INDEXES
-- =========================================================

create index if not exists idx_chat_rooms_client_id on public.chat_rooms(client_id);
create index if not exists idx_chat_rooms_professional_id on public.chat_rooms(professional_id);
create index if not exists idx_chat_rooms_last_message_at on public.chat_rooms(last_message_at);
create index if not exists idx_chat_messages_room_id on public.chat_messages(room_id);
create index if not exists idx_chat_messages_created_at on public.chat_messages(created_at);
create index if not exists idx_chat_messages_is_read on public.chat_messages(room_id, is_read) where is_read = false;
create index if not exists idx_chat_tags_room_id on public.chat_tags(room_id);
create index if not exists idx_chat_tags_professional_id on public.chat_tags(professional_id);

-- =========================================================
-- 30. ENABLE REALTIME for chat tables
-- =========================================================

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
end;
$$;

-- =========================================================
-- 31. WATER LOGS TABLE
-- =========================================================
create table if not exists public.water_logs (
  water_log_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  amount_ml int not null check (amount_ml > 0),
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists water_logs_profile_id_idx
on public.water_logs(profile_id);

create index if not exists water_logs_logged_at_idx
on public.water_logs(logged_at);

alter table public.water_logs enable row level security;

drop policy if exists "Users can view own water logs" on public.water_logs;
drop policy if exists "Users can insert own water logs" on public.water_logs;
drop policy if exists "Users can update own water logs" on public.water_logs;
drop policy if exists "Users can delete own water logs" on public.water_logs;

create policy "Users can view own water logs"
on public.water_logs
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own water logs"
on public.water_logs
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own water logs"
on public.water_logs
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own water logs"
on public.water_logs
for delete
to authenticated
using (profile_id = auth.uid());

-- =========================================================
-- 31b. WATER SETTING TABLE
-- =========================================================
create table if not exists public.water_settings (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  water_goal_ml int not null default 2000 check (water_goal_ml > 0),
  updated_at timestamptz not null default now()
);

alter table public.water_settings enable row level security;

drop policy if exists "Users can view own water settings" on public.water_settings;
drop policy if exists "Users can insert own water settings" on public.water_settings;
drop policy if exists "Users can update own water settings" on public.water_settings;
drop policy if exists "Users can delete own water settings" on public.water_settings;

create policy "Users can view own water settings"
on public.water_settings
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own water settings"
on public.water_settings
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own water settings"
on public.water_settings
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own water settings"
on public.water_settings
for delete
to authenticated
using (profile_id = auth.uid());

-- =========================================================
-- 32. SOCIAL POSTS
-- =========================================================

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  content text not null default '',
  image_url text,
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint posts_visibility_check
    check (visibility in ('public', 'followers')),
  constraint posts_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade
);

-- Post visibility is controlled by profiles.is_private and follow relationships.
-- Normalize values left by the older per-post audience implementation.
update public.posts
set visibility = 'public'
where visibility is distinct from 'public';

do $$
begin
  alter table public.reports
  add constraint reports_post_id_fkey
  foreign key (post_id) references public.posts(id) on delete cascade;
exception
  when duplicate_object then null;
end
$$;

create index if not exists posts_user_id_idx
on public.posts(user_id);

create index if not exists posts_created_at_idx
on public.posts(created_at desc);

alter table public.posts enable row level security;

drop policy if exists "Authenticated users can read posts" on public.posts;
drop policy if exists "Users can create own posts" on public.posts;
drop policy if exists "Users can update own posts" on public.posts;
drop policy if exists "Users can delete own posts" on public.posts;

create policy "Authenticated users can read posts"
on public.posts
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.profiles
    where profiles.id = posts.user_id
      and profiles.is_private = false
  )
);

create policy "Users can create own posts"
on public.posts
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own posts"
on public.posts
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own posts"
on public.posts
for delete
to authenticated
using (auth.uid() = user_id);

-- =========================================================
-- 33. SOCIAL POST LIKES
-- =========================================================

create table if not exists public.post_likes (
  post_id uuid not null,
  user_id uuid not null,
  created_at timestamptz not null default now(),
  constraint post_likes_pkey primary key (post_id, user_id),
  constraint post_likes_post_id_fkey
    foreign key (post_id) references public.posts(id) on delete cascade,
  constraint post_likes_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade
);

create index if not exists post_likes_post_id_idx
on public.post_likes(post_id);

create index if not exists post_likes_user_id_idx
on public.post_likes(user_id);

alter table public.post_likes enable row level security;

drop policy if exists "Authenticated users can read post likes" on public.post_likes;
drop policy if exists "Users can like from own account" on public.post_likes;
drop policy if exists "Users can remove own likes" on public.post_likes;

create policy "Authenticated users can read post likes"
on public.post_likes for select to authenticated
using (true);

create policy "Users can like from own account"
on public.post_likes for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users can remove own likes"
on public.post_likes for delete to authenticated
using (auth.uid() = user_id);

-- =========================================================
-- 34. SOCIAL POST COMMENTS
-- =========================================================

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null,
  user_id uuid not null,
  content text not null check (length(trim(content)) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint post_comments_post_id_fkey
    foreign key (post_id) references public.posts(id) on delete cascade,
  constraint post_comments_user_id_fkey
    foreign key (user_id) references public.profiles(id) on delete cascade
);

create index if not exists post_comments_post_id_idx
on public.post_comments(post_id, created_at);

create index if not exists post_comments_user_id_idx
on public.post_comments(user_id);

alter table public.post_comments enable row level security;

drop policy if exists "Authenticated users can read post comments" on public.post_comments;
drop policy if exists "Users can create own comments" on public.post_comments;
drop policy if exists "Users can update own comments" on public.post_comments;
drop policy if exists "Users can delete own comments" on public.post_comments;

create policy "Authenticated users can read post comments"
on public.post_comments for select to authenticated
using (true);

create policy "Users can create own comments"
on public.post_comments for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own comments"
on public.post_comments for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own comments"
on public.post_comments for delete to authenticated
using (auth.uid() = user_id);

-- =========================================================
-- 35. SOCIAL FOLLOWS
-- =========================================================

create table if not exists public.follows (
  follower_id uuid not null,
  following_id uuid not null,
  created_at timestamptz not null default now(),
  constraint follows_pkey primary key (follower_id, following_id),
  constraint follows_follower_id_fkey
    foreign key (follower_id) references public.profiles(id) on delete cascade,
  constraint follows_following_id_fkey
    foreign key (following_id) references public.profiles(id) on delete cascade,
  constraint follows_cannot_follow_self check (follower_id <> following_id)
);

create index if not exists follows_follower_id_idx
on public.follows(follower_id);

create index if not exists follows_following_id_idx
on public.follows(following_id);

alter table public.follows enable row level security;

drop policy if exists "Authenticated users can read follows" on public.follows;
drop policy if exists "Users can follow from own account" on public.follows;
drop policy if exists "Users can unfollow from own account" on public.follows;

create policy "Authenticated users can read follows"
on public.follows
for select
to authenticated
using (true);

create policy "Users can follow from own account"
on public.follows
for insert
to authenticated
with check (
  auth.uid() = follower_id
  and follower_id <> following_id
);

create policy "Users can unfollow from own account"
on public.follows
for delete
to authenticated
using (auth.uid() = follower_id);

-- Replace the temporary post-read policy now that follows exists.
drop policy if exists "Authenticated users can read posts" on public.posts;

create policy "Authenticated users can read posts"
on public.posts
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.profiles
    where profiles.id = posts.user_id
      and profiles.is_private = false
  )
  or (
    exists (
      select 1
      from public.follows
      where follows.follower_id = auth.uid()
        and follows.following_id = posts.user_id
    )
  )
);

-- =========================================================
-- 36. SOCIAL POST IMAGE STORAGE
-- =========================================================

insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "Public can view post images" on storage.objects;
drop policy if exists "Users can upload own post images" on storage.objects;
drop policy if exists "Users can update own post images" on storage.objects;
drop policy if exists "Users can delete own post images" on storage.objects;

create policy "Public can view post images"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'post-images');

create policy "Users can upload own post images"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own post images"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own post images"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- =========================================================
-- 37. NOTIFICATION SETTINGS
-- =========================================================

create table if not exists public.notification_settings (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  daily_reminder_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_settings enable row level security;

drop policy if exists "Users can view own notification settings" on public.notification_settings;
drop policy if exists "Users can insert own notification settings" on public.notification_settings;
drop policy if exists "Users can update own notification settings" on public.notification_settings;
drop policy if exists "Users can delete own notification settings" on public.notification_settings;

create policy "Users can view own notification settings"
on public.notification_settings
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own notification settings"
on public.notification_settings
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own notification settings"
on public.notification_settings
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own notification settings"
on public.notification_settings
for delete
to authenticated
using (profile_id = auth.uid());

-- =========================================================
-- 38. NOTIFICATION REMINDERS
-- =========================================================

create table if not exists public.notification_reminders (
  reminder_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  reminder_type text not null check (
    reminder_type in (
      'Exercise Reminder',
      'Hydration Reminder',
      'Rest Reminder',
      'Meal Reminder'
    )
  ),
  reminder_time text not null,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists notification_reminders_profile_id_idx
on public.notification_reminders(profile_id);

alter table public.notification_reminders enable row level security;

drop policy if exists "Users can view own notification reminders" on public.notification_reminders;
drop policy if exists "Users can insert own notification reminders" on public.notification_reminders;
drop policy if exists "Users can update own notification reminders" on public.notification_reminders;
drop policy if exists "Users can delete own notification reminders" on public.notification_reminders;

create policy "Users can view own notification reminders"
on public.notification_reminders
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own notification reminders"
on public.notification_reminders
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own notification reminders"
on public.notification_reminders
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own notification reminders"
on public.notification_reminders
for delete
to authenticated
using (profile_id = auth.uid());

-- =========================================================
-- 39. WEARABLE CONNECTIONS
-- =========================================================

create table if not exists public.wearable_connections (
  connection_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  provider text not null check (
    provider in (
      'google_fit'
    )
  ),
  is_connected boolean not null default false,
  connected_at timestamptz,
  disconnected_at timestamptz,
  last_synced_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(profile_id, provider)
);

-- Migration: drop deprecated providers (apple_health, motion_fitness, fitbit).
-- 'google_fit' is now repurposed to represent the Android Health Connect connection.
delete from public.wearable_connections
where provider not in ('google_fit');

alter table public.wearable_connections
drop constraint if exists wearable_connections_provider_check;

alter table public.wearable_connections
add constraint wearable_connections_provider_check
check (provider in ('google_fit'));

create index if not exists wearable_connections_profile_id_idx
on public.wearable_connections(profile_id);

alter table public.wearable_connections enable row level security;

drop policy if exists "Users can view own wearable connections" on public.wearable_connections;
drop policy if exists "Users can insert own wearable connections" on public.wearable_connections;
drop policy if exists "Users can update own wearable connections" on public.wearable_connections;
drop policy if exists "Users can delete own wearable connections" on public.wearable_connections;

create policy "Users can view own wearable connections"
on public.wearable_connections
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own wearable connections"
on public.wearable_connections
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own wearable connections"
on public.wearable_connections
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own wearable connections"
on public.wearable_connections
for delete
to authenticated
using (profile_id = auth.uid());

-- =========================================================
-- 39B. DAILY HEALTH METRICS (Health Connect sync)
-- =========================================================

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

-- Migration: add heart_rate_measured_at to existing daily_health_metrics tables.
alter table public.daily_health_metrics
add column if not exists heart_rate_measured_at timestamptz;

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

-- =========================================================
-- 40. APP FEEDBACK TABLE
-- =========================================================

create table if not exists public.app_feedback (
  feedback_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  feedback_text text not null,
  permission_to_publish boolean not null default false,
  media_url text,
  status text not null default 'submitted' check (
    status in ('submitted', 'reviewed', 'hidden')
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists app_feedback_profile_id_idx
on public.app_feedback(profile_id);

create index if not exists app_feedback_created_at_idx
on public.app_feedback(created_at);

alter table public.app_feedback enable row level security;

drop policy if exists "Users can view own app feedback" on public.app_feedback;
drop policy if exists "Users can insert own app feedback" on public.app_feedback;
drop policy if exists "Users can update own app feedback" on public.app_feedback;
drop policy if exists "Users can delete own app feedback" on public.app_feedback;

create policy "Users can view own app feedback"
on public.app_feedback
for select
to authenticated
using (profile_id = auth.uid());

create policy "Users can insert own app feedback"
on public.app_feedback
for insert
to authenticated
with check (profile_id = auth.uid());

create policy "Users can update own app feedback"
on public.app_feedback
for update
to authenticated
using (profile_id = auth.uid())
with check (profile_id = auth.uid());

create policy "Users can delete own app feedback"
on public.app_feedback
for delete
to authenticated
using (profile_id = auth.uid());

-- =========================================================
-- 40b. APP FEEDBACK MEDIA STORAGE
-- =========================================================

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'feedback-media',
  'feedback-media',
  true,
  5242880,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif'
  ]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Anyone can read feedback media" on storage.objects;
drop policy if exists "Users can upload own feedback media" on storage.objects;
drop policy if exists "Users can update own feedback media" on storage.objects;
drop policy if exists "Users can delete own feedback media" on storage.objects;

create policy "Anyone can read feedback media"
on storage.objects
for select
to public
using (
  bucket_id = 'feedback-media'
);

create policy "Users can upload own feedback media"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'feedback-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own feedback media"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'feedback-media'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'feedback-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own feedback media"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'feedback-media'
  and (storage.foldername(name))[1] = auth.uid()::text
);
