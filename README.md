# Facil Jobs

Facil Jobs is the international recruitment portal being rebuilt from the former Facil Express site.

## Product rules
- Only approved Facil Jobs administrators can create, publish, close, or edit vacancies.
- Applicants create worker accounts and apply directly on the site.
- Applicants can see only their own applications and their application status.
- Admins can review applications and update statuses.
- Each job benefit can have its own title, description, and photo.
- CVs are stored in a private bucket; benefit photos are public only after the associated vacancy is published.
- Do not publish sample jobs, invented employers, invented salary ranges, or benefits that have not been checked.

## Current implementation
- `index.html`: responsive Facil Jobs frontend, job search, vacancy detail and benefit gallery, worker signup/sign-in, direct application form, CV upload, admin job editor, benefit photo uploads, job management and application status controls.
- `supabase/schema.sql`: database tables, row-level security policies and storage bucket policies.

## Supabase setup
The original Facil Express Supabase project was restored. The core database migration was submitted. Storage initialization still needs to finish before photo/CV upload can be tested.

1. In Supabase SQL Editor, run the full `supabase/schema.sql` after the Storage schema is available. If the core migration has already been applied, running the file again is safe because its tables and policies are created idempotently.
2. Create a worker account on the site.
3. To promote your own account to administrator, run the following in SQL Editor, replacing the email:
   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb) || '{"role":"admin"}'::jsonb
   where email = 'YOUR-ADMIN-EMAIL';
   ```
4. Sign out and sign in again. The account must have `app_metadata.role = admin` in its refreshed session.
5. Test a job with real employer-approved details and a real photo for each listed benefit. Do not use sample listings in production.

## Important launch checks
- Confirm email confirmation and password recovery settings.
- Configure a verified sender for transactional emails before enabling application notifications.
- Test worker signup, sign-in, CV upload, application submission, applicant-only visibility, admin-only publishing, benefit photo display and status updates.
- Add a privacy notice, terms, data-retention policy and a contact channel before accepting public applications.
- Do not ask applicants to pay recruitment or visa fees to personal accounts. Clearly identify the legal employer, work authorization route and who pays each relocation expense.
