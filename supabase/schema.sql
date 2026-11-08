-- Facil Jobs schema. Apply only to the restored Facil Express Supabase project.
create extension if not exists pgcrypto;

create or replace function public.is_facil_jobs_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin', false);
$$;

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  employer text not null,
  country text not null,
  location text not null,
  job_type text not null default 'Full-time',
  salary text,
  description text not null,
  requirements text[] not null default '{}',
  visa_support text not null default 'Not specified',
  deadline date,
  cover_path text,
  status text not null default 'draft' check (status in ('draft','published','closed')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.job_benefits (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  title text not null,
  description text not null default '',
  photo_path text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete restrict,
  applicant_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  phone text not null,
  country_of_residence text not null,
  experience text not null default '',
  introduction text not null,
  cv_path text not null,
  status text not null default 'submitted'
    check (status in ('submitted','under_review','shortlisted','interview','accepted','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(job_id, applicant_id)
);

create index if not exists jobs_status_created_idx on public.jobs(status, created_at desc);
create index if not exists applications_applicant_created_idx on public.applications(applicant_id, created_at desc);
create index if not exists applications_job_created_idx on public.applications(job_id, created_at desc);

alter table public.jobs enable row level security;
alter table public.job_benefits enable row level security;
alter table public.applications enable row level security;

drop policy if exists "Public can view published jobs" on public.jobs;
create policy "Public can view published jobs" on public.jobs
for select to anon, authenticated
using (status = 'published' or (select public.is_facil_jobs_admin()));

drop policy if exists "Admins manage jobs" on public.jobs;
create policy "Admins manage jobs" on public.jobs
for all to authenticated
using ((select public.is_facil_jobs_admin()))
with check ((select public.is_facil_jobs_admin()));

drop policy if exists "Public can view benefits for published jobs" on public.job_benefits;
create policy "Public can view benefits for published jobs" on public.job_benefits
for select to anon, authenticated
using (
  exists (
    select 1 from public.jobs j
    where j.id = job_benefits.job_id
      and (j.status = 'published' or (select public.is_facil_jobs_admin()))
  )
);

drop policy if exists "Admins manage job benefits" on public.job_benefits;
create policy "Admins manage job benefits" on public.job_benefits
for all to authenticated
using ((select public.is_facil_jobs_admin()))
with check ((select public.is_facil_jobs_admin()));

drop policy if exists "Applicants submit their own applications" on public.applications;
create policy "Applicants submit their own applications" on public.applications
for insert to authenticated
with check (
  applicant_id = (select auth.uid())
  and exists (select 1 from public.jobs j where j.id = job_id and j.status = 'published')
);

drop policy if exists "Applicants view their own applications" on public.applications;
create policy "Applicants view their own applications" on public.applications
for select to authenticated
using (applicant_id = (select auth.uid()) or (select public.is_facil_jobs_admin()));

drop policy if exists "Admins update applications" on public.applications;
create policy "Admins update applications" on public.applications
for update to authenticated
using ((select public.is_facil_jobs_admin()))
with check ((select public.is_facil_jobs_admin()));

grant select on public.jobs, public.job_benefits to anon, authenticated;
grant select, insert, update, delete on public.jobs, public.job_benefits to authenticated;
grant select, insert, update on public.applications to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('job-benefit-photos', 'job-benefit-photos', true, 7340032, array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('applicant-cvs', 'applicant-cvs', false, 5242880, array['application/pdf','application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view job benefit photos" on storage.objects;
create policy "Public can view job benefit photos" on storage.objects
for select to anon, authenticated
using (bucket_id = 'job-benefit-photos');

drop policy if exists "Admins upload job benefit photos" on storage.objects;
create policy "Admins upload job benefit photos" on storage.objects
for insert to authenticated
with check (bucket_id = 'job-benefit-photos' and (select public.is_facil_jobs_admin()));

drop policy if exists "Admins update job benefit photos" on storage.objects;
create policy "Admins update job benefit photos" on storage.objects
for update to authenticated
using (bucket_id = 'job-benefit-photos' and (select public.is_facil_jobs_admin()))
with check (bucket_id = 'job-benefit-photos' and (select public.is_facil_jobs_admin()));

drop policy if exists "Admins delete job benefit photos" on storage.objects;
create policy "Admins delete job benefit photos" on storage.objects
for delete to authenticated
using (bucket_id = 'job-benefit-photos' and (select public.is_facil_jobs_admin()));

drop policy if exists "Applicants upload their own CV" on storage.objects;
create policy "Applicants upload their own CV" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'applicant-cvs'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Applicants and admins read CVs" on storage.objects;
create policy "Applicants and admins read CVs" on storage.objects
for select to authenticated
using (
  bucket_id = 'applicant-cvs'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or (select public.is_facil_jobs_admin())
  )
);

-- After your own administrator account has been created, run this once in SQL Editor:
-- update auth.users
-- set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
-- where email = 'YOUR-ADMIN-EMAIL';
-- Then sign out and sign back in so the refreshed JWT contains app_metadata.role = admin.
