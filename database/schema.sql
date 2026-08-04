-- =========================================================
-- ShapeRush Updated Supabase Schema
-- Includes:
-- profiles, admin role, plans, reviews, reports,
-- audit logs, website content, storage policies
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
  user_type text,
  status text default 'active',
  approved boolean default true,
  role text default 'user',
  created_at timestamptz default now(),
  display_name text,
  bio text,
  experience int,
  specializations text,
  certificate_name text,
  certificate_path text,
  submitted_at timestamptz default now()
);

alter table public.profiles
add column if not exists full_name text,
add column if not exists email text,
add column if not exists gender text,
add column if not exists user_type text,
add column if not exists status text default 'active',
add column if not exists approved boolean default true,
add column if not exists role text default 'user',
add column if not exists created_at timestamptz default now(),
add column if not exists display_name text,
add column if not exists bio text,
add column if not exists experience int,
add column if not exists specializations text,
add column if not exists certificate_name text,
add column if not exists certificate_path text,
add column if not exists submitted_at timestamptz default now();

alter table public.profiles enable row level security;

-- Normalize old wrong user_type values
update public.profiles
set user_type = 'Free'
where user_type is null
   or trim(user_type) = ''
   or lower(user_type) = 'client';

-- Fill created_at from auth.users where possible
update public.profiles p
set created_at = u.created_at
from auth.users u
where p.id = u.id
  and p.created_at is null;

update public.profiles
set created_at = now()
where created_at is null;

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
    from public.profiles
    where id = auth.uid()
      and role = 'admin'
      and status = 'active'
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
  database_status text;
  database_approved boolean;
begin
  metadata_role := NEW.raw_user_meta_data->>'role';

  database_user_type :=
    case
      when metadata_role in ('Fitness professional', 'fitness_professional') then 'Fitness professional'
      when metadata_role = 'Priority' then 'Priority'
      when metadata_role = 'Admin' then 'Admin'
      else 'Free'
    end;

  database_status :=
    case
      when database_user_type = 'Fitness professional' then 'pending'
      else 'active'
    end;

  database_approved :=
    case
      when database_user_type = 'Fitness professional' then false
      else true
    end;

  insert into public.profiles (
    id,
    full_name,
    email,
    user_type,
    status,
    approved,
    role,
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
    database_status,
    database_approved,
    case when database_user_type = 'Admin' then 'admin' else 'user' end,
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
-- 5. MARK ADMIN PROFILE
-- Run this after creating admin@shaperush.com in Authentication Users
-- =========================================================

insert into public.profiles (
  id,
  full_name,
  email,
  user_type,
  status,
  approved,
  role,
  created_at
)
select
  id,
  'Admin',
  email,
  'Admin',
  'active',
  true,
  'admin',
  created_at
from auth.users
where email = 'admin@shaperush.com'
on conflict (id) do update
set
  full_name = 'Admin',
  user_type = 'Admin',
  status = 'active',
  approved = true,
  role = 'admin';

-- =========================================================
-- 6. FREE PLANS TABLE
-- =========================================================

create table if not exists public.free_plans (
  id uuid primary key default gen_random_uuid(),
  plan_name text not null,
  exercise_count int default 0,
  category text,
  status text default 'live',
  created_at timestamptz default now()
);

alter table public.free_plans enable row level security;

drop policy if exists "Allow read free plans" on public.free_plans;
drop policy if exists "Allow update free plans" on public.free_plans;
drop policy if exists "Admins can read free plans" on public.free_plans;
drop policy if exists "Admins can update free plans" on public.free_plans;
drop policy if exists "Users can read live free plans" on public.free_plans;

create policy "Users can read live free plans"
on public.free_plans
for select
to anon, authenticated
using (status = 'live' or public.is_admin());

create policy "Admins can update free plans"
on public.free_plans
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

insert into public.free_plans (plan_name, exercise_count, category, status)
select 'Morning Yoga', 5, 'Yoga', 'live'
where not exists (
  select 1 from public.free_plans where plan_name = 'Morning Yoga'
);

insert into public.free_plans (plan_name, exercise_count, category, status)
select '5K Run Prep', 6, 'Warm-up', 'hidden'
where not exists (
  select 1 from public.free_plans where plan_name = '5K Run Prep'
);

insert into public.free_plans (plan_name, exercise_count, category, status)
select 'Full Body', 10, 'Full Body', 'live'
where not exists (
  select 1 from public.free_plans where plan_name = 'Full Body'
);

-- =========================================================
-- 7. PERSONALIZED PLANS TABLE
-- =========================================================

create table if not exists public.personalized_plans (
  id uuid primary key default gen_random_uuid(),
  plan_name text not null,
  client_name text,
  professional_name text,
  created_at timestamptz default now()
);

alter table public.personalized_plans enable row level security;

drop policy if exists "Allow read personalized plans" on public.personalized_plans;
drop policy if exists "Admins can read personalized plans" on public.personalized_plans;

create policy "Admins can read personalized plans"
on public.personalized_plans
for select
to authenticated
using (public.is_admin());

insert into public.personalized_plans (plan_name, client_name, professional_name)
select 'Jane''s Fat Loss', 'Jane Smith', 'Alissa Chen'
where not exists (
  select 1 from public.personalized_plans where plan_name = 'Jane''s Fat Loss'
);

insert into public.personalized_plans (plan_name, client_name, professional_name)
select 'Mike''s Strength', 'Mark Heron', 'Tira Mcgee'
where not exists (
  select 1 from public.personalized_plans where plan_name = 'Mike''s Strength'
);

insert into public.personalized_plans (plan_name, client_name, professional_name)
select '30-Day Weight Loss', 'Elizabeth Tan', 'Wade Warren'
where not exists (
  select 1 from public.personalized_plans where plan_name = '30-Day Weight Loss'
);

-- =========================================================
-- 8. REVIEWS TABLE
-- =========================================================

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  reviewer_id uuid references public.profiles(id) on delete set null,
  reviewer_name text,
  reviewer_email text,
  tier text,
  rating int,
  feedback text,
  media_name text,
  media_path text,
  ai_analysis text,
  featured_on_website boolean default false,
  submitted_at timestamptz default now()
);

alter table public.reviews
add column if not exists reviewer_id uuid references public.profiles(id) on delete set null,
add column if not exists reviewer_name text,
add column if not exists reviewer_email text,
add column if not exists tier text,
add column if not exists rating int,
add column if not exists feedback text,
add column if not exists media_name text,
add column if not exists media_path text,
add column if not exists ai_analysis text,
add column if not exists featured_on_website boolean default false,
add column if not exists submitted_at timestamptz default now();

alter table public.reviews enable row level security;

drop policy if exists "Allow read reviews" on public.reviews;
drop policy if exists "Admins can read reviews" on public.reviews;
drop policy if exists "Admins can read all reviews" on public.reviews;
drop policy if exists "Allow update reviews featured status" on public.reviews;
drop policy if exists "Allow admin update reviews featured status" on public.reviews;
drop policy if exists "Admins can update reviews" on public.reviews;
drop policy if exists "Public can read featured reviews" on public.reviews;

create policy "Public can read featured reviews"
on public.reviews
for select
to anon, authenticated
using (
  featured_on_website = true
  or public.is_admin()
);

create policy "Admins can update reviews"
on public.reviews
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Authenticated users can insert reviews"
on public.reviews
for insert
to authenticated
with check (true);

-- Optional fake review data
insert into public.reviews (
  reviewer_name,
  reviewer_email,
  tier,
  rating,
  feedback,
  media_name,
  media_path,
  ai_analysis,
  submitted_at
)
select
  'Wade Warren',
  'wade.warren@gmail.com',
  'Free',
  4,
  'The workout plan is easy to follow and helpful for beginners.',
  null,
  null,
  'positive',
  now() - interval '1 hour'
where not exists (
  select 1 from public.reviews where reviewer_email = 'wade.warren@gmail.com'
);

insert into public.reviews (
  reviewer_name,
  reviewer_email,
  tier,
  rating,
  feedback,
  media_name,
  media_path,
  ai_analysis,
  submitted_at
)
select
  'Anna Tan',
  'anna.tan@gmail.com',
  'Free',
  5,
  'The app helped me stay consistent with my weekly fitness routine.',
  null,
  null,
  'positive',
  now() - interval '3 hours'
where not exists (
  select 1 from public.reviews where reviewer_email = 'anna.tan@gmail.com'
);

insert into public.reviews (
  reviewer_name,
  reviewer_email,
  tier,
  rating,
  feedback,
  media_name,
  media_path,
  ai_analysis,
  submitted_at
)
select
  'Alissa Mackie',
  'alissa.mackie@gmail.com',
  'Priority',
  5,
  'The personalized plan is very useful and clear.',
  null,
  null,
  'positive',
  now() - interval '8 hours'
where not exists (
  select 1 from public.reviews where reviewer_email = 'alissa.mackie@gmail.com'
);

insert into public.reviews (
  reviewer_name,
  reviewer_email,
  tier,
  rating,
  feedback,
  media_name,
  media_path,
  ai_analysis,
  submitted_at
)
select
  'Becky Winsons',
  'becky.winsons@gmail.com',
  'Free',
  1,
  'The workout plan was not suitable for my goal.',
  null,
  null,
  'negative',
  now() - interval '1 day'
where not exists (
  select 1 from public.reviews where reviewer_email = 'becky.winsons@gmail.com'
);

-- =========================================================
-- 9. REPORTS TABLE
-- =========================================================

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  target_id text not null,
  report_type text not null,
  content_owner text,
  reporter text,
  comment_text text,
  post_caption text,
  media_name text,
  media_path text,
  status text default 'pending',
  submitted_at timestamptz default now()
);

alter table public.reports enable row level security;

drop policy if exists "Allow read reports" on public.reports;
drop policy if exists "Allow update reports" on public.reports;
drop policy if exists "Admins can read reports" on public.reports;
drop policy if exists "Admins can update reports" on public.reports;
drop policy if exists "Authenticated users can insert reports" on public.reports;

create policy "Admins can read reports"
on public.reports
for select
to authenticated
using (public.is_admin());

create policy "Admins can update reports"
on public.reports
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Authenticated users can insert reports"
on public.reports
for insert
to authenticated
with check (true);

-- =========================================================
-- 10. AUDIT LOGS TABLE
-- =========================================================

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid,
  admin_email text,
  action text not null,
  target text not null,
  target_type text,
  created_at timestamptz default now()
);

alter table public.audit_logs enable row level security;

drop policy if exists "Allow read audit logs" on public.audit_logs;
drop policy if exists "Allow insert audit logs" on public.audit_logs;
drop policy if exists "Admins can read audit logs" on public.audit_logs;
drop policy if exists "Admins can insert audit logs" on public.audit_logs;

create policy "Admins can read audit logs"
on public.audit_logs
for select
to authenticated
using (public.is_admin());

create policy "Admins can insert audit logs"
on public.audit_logs
for insert
to authenticated
with check (public.is_admin());

-- =========================================================
-- 11. WEBSITE CONTENT TABLE
-- =========================================================

create table if not exists public.website_content (
  section_key text primary key,
  content jsonb not null,
  updated_at timestamptz default now()
);

alter table public.website_content enable row level security;

drop policy if exists "Allow read website content" on public.website_content;
drop policy if exists "Allow update website content" on public.website_content;
drop policy if exists "Allow insert website content" on public.website_content;
drop policy if exists "Admins can update website content" on public.website_content;
drop policy if exists "Admins can insert website content" on public.website_content;

create policy "Allow read website content"
on public.website_content
for select
to anon, authenticated
using (true);

create policy "Admins can update website content"
on public.website_content
for update
to authenticated
using (public.is_admin())
with check (public.is_admin());

create policy "Admins can insert website content"
on public.website_content
for insert
to authenticated
with check (public.is_admin());

insert into public.website_content (section_key, content)
values
(
  'hero',
  '{
    "titleLine1": "Train smarter.",
    "titleLine2": "See real results.",
    "subtitle": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do dolor sit tincidunt ut labore et dolore magna aliqua. Dolor sit amet, consectetur adipiscing elit."
  }'
),
(
  'features',
  '{
    "sectionLabel": "Features",
    "title": "Everything to crush your goals",
    "items": [
      { "title": "Personalised Plans", "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do." },
      { "title": "Workout Tracking", "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do." },
      { "title": "Progress Analytics", "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do." },
      { "title": "Nutrition Support", "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do." },
      { "title": "Streaks & Rewards", "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do." },
      { "title": "Community Support", "text": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do." }
    ]
  }'
),
(
  'subscription',
  '{
    "sectionLabel": "Subscription Plans",
    "title": "Unlock Your Best Self",
    "plans": [
      {
        "title": "Free",
        "price": "$0",
        "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
        "features": ["Basic workouts", "Workout tracking", "Community Access", "Workout tracking", "", ""]
      },
      {
        "title": "Premium",
        "price": "$7.99",
        "description": "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do.",
        "features": ["Workout tracking", "Basic workouts", "Workout tracking", "Basic workouts", "Workout tracking", "Basic workouts"]
      }
    ]
  }'
),
(
  'faq',
  '{
    "title": "FAQs",
    "items": [
      { "question": "Is ShapeRush free to use?", "answer": "Yes, ShapeRush provides a free plan for users." },
      { "question": "Can I track weight, workout, or intermittent fasting?", "answer": "Yes, users can track their fitness progress inside the app." },
      { "question": "What do I need to get started?", "answer": "Create an account and download the ShapeRush app." }
    ]
  }'
)
on conflict (section_key) do nothing;

-- =========================================================
-- 12. STORAGE BUCKETS AND POLICIES
-- =========================================================

insert into storage.buckets (id, name, public)
values
  ('certifications', 'certifications', true),
  ('review-media', 'review-media', true),
  ('report-media', 'report-media', true)
on conflict (id) do update
set public = excluded.public;

drop policy if exists "Allow authenticated upload certifications" on storage.objects;
drop policy if exists "Allow public read certifications" on storage.objects;
drop policy if exists "Allow public read review media" on storage.objects;
drop policy if exists "Allow public read report media" on storage.objects;

create policy "Allow authenticated upload certifications"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'certifications');

create policy "Allow public read certifications"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'certifications');

create policy "Allow public read review media"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'review-media');

create policy "Allow public read report media"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'report-media');

-- =========================================================
-- SOCIAL POSTS AND POST IMAGE STORAGE
-- =========================================================

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content text not null default '' check (char_length(content) <= 1000),
  image_url text,
  visibility text not null default 'public'
    check (visibility in ('public', 'followers')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (length(trim(content)) > 0 or image_url is not null)
);

create index if not exists posts_user_id_idx on public.posts(user_id);
create index if not exists posts_created_at_idx on public.posts(created_at desc);

alter table public.posts enable row level security;

drop policy if exists "Authenticated users can read posts" on public.posts;
drop policy if exists "Users can create own posts" on public.posts;
drop policy if exists "Users can update own posts" on public.posts;
drop policy if exists "Users can delete own posts" on public.posts;

create policy "Authenticated users can read posts"
on public.posts for select to authenticated
using (true);

create policy "Users can create own posts"
on public.posts for insert to authenticated
with check (auth.uid() = user_id);

create policy "Users can update own posts"
on public.posts for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Users can delete own posts"
on public.posts for delete to authenticated
using (auth.uid() = user_id);

create table if not exists public.follows (
  follower_id uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);

create index if not exists follows_following_id_idx
on public.follows(following_id);

alter table public.follows enable row level security;

drop policy if exists "Authenticated users can read follows" on public.follows;
drop policy if exists "Users can follow from own account" on public.follows;
drop policy if exists "Users can unfollow from own account" on public.follows;

create policy "Authenticated users can read follows"
on public.follows for select to authenticated
using (true);

create policy "Users can follow from own account"
on public.follows for insert to authenticated
with check (auth.uid() = follower_id);

create policy "Users can unfollow from own account"
on public.follows for delete to authenticated
using (auth.uid() = follower_id);

insert into storage.buckets (id, name, public)
values ('post-images', 'post-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Public can view post images" on storage.objects;
drop policy if exists "Users can upload own post images" on storage.objects;
drop policy if exists "Users can update own post images" on storage.objects;
drop policy if exists "Users can delete own post images" on storage.objects;

create policy "Public can view post images"
on storage.objects for select
using (bucket_id = 'post-images');

create policy "Users can upload own post images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can update own post images"
on storage.objects for update to authenticated
using (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Users can delete own post images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'post-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);
