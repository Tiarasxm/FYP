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

alter table public.reviews enable row level security;

-- =========================================================
-- 8. REPORTS TABLE
-- =========================================================

create table if not exists public.reports (
  report_id uuid primary key default gen_random_uuid(),
  reporter_id uuid,
  content_type text,
  report_type text,
  status text default 'pending',
  submitted_at timestamptz default now(),
  constraint reports_reporter_id_fkey foreign key (reporter_id) references public.profiles(id)
);

alter table public.reports enable row level security;

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

-- =========================================================
-- 16. SAVED PLANS TABLE
-- =========================================================

create table if not exists public.saved_plans (
  saved_plan_id uuid primary key default gen_random_uuid(),
  profile_id uuid not null,
  free_plan_id uuid,
  personalized_plan_id uuid,
  saved_at timestamptz default now(),
  constraint saved_plans_profile_id_fkey foreign key (profile_id) references public.profiles(id),
  constraint saved_plans_free_plan_id_fkey foreign key (free_plan_id) references public.free_plans(free_plan_id),
  constraint saved_plans_personalized_plan_id_fkey foreign key (personalized_plan_id) references public.personalized_plans(personalized_plan_id)
);

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
-- 19. CHAT ROOMS TABLE
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
-- 20. CHAT MESSAGES TABLE
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
-- 21. CHAT TAGS TABLE
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
-- 22. RLS POLICIES - chat_rooms
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
-- 23. RLS POLICIES - chat_messages
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
-- 24. RLS POLICIES - chat_tags
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
-- 25. HELPER FUNCTIONS
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
-- 26. TRIGGER: update last_message on chat_rooms
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
-- 27. INDEXES
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
-- 28. ENABLE REALTIME for chat tables
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
end;
$$;
