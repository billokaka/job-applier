-- The job applier: complete schema for a fresh Supabase project.
-- Engine 2.2. One user per project. Private, connector-operated: RLS on every
-- table, no anon or authenticated grants, no Supabase Auth dependency, no column
-- for any secret. Run once in the user's own project, then audit.sql, then
-- smoke_test.sql, then 01_seed_standard_answers.sql.
--
-- An existing project that already carries the v1 tracker (the original
-- company-by-company campaign) does NOT run this file: it runs the v2 migration
-- instead (see README.md in this folder).

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0. Workspace: the one private identity every row belongs to
-- ---------------------------------------------------------------------------

create table public.campaign_workspaces (
  id uuid primary key,
  name text not null check (btrim(name) <> ''),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.campaign_workspaces (id, name)
values ('00000000-0000-4000-8000-000000000001', 'job applier')
on conflict (id) do nothing;

create function public.set_job_hunt_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.set_job_hunt_updated_at() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. The pipeline: companies, opportunities, sources, contacts, applications,
--    messages, interactions, research, artifacts, events
-- ---------------------------------------------------------------------------

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  normalized_name text not null check (btrim(normalized_name) <> ''),
  website_url text,
  linkedin_company_url text,
  sales_nav_account_url text,
  company_type text check (company_type is null or company_type in ('product', 'service', 'agency', 'marketplace', 'data', 'hybrid', 'other')),
  industry text,
  employee_range text,
  headquarters text,
  hiring_geography text,
  company_summary text,
  research_status text not null default 'not_started' check (research_status in ('not_started', 'partial', 'verified')),
  last_researched_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id, normalized_name)
);

create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  company_id uuid not null,
  role_title text not null check (btrim(role_title) <> ''),
  normalized_role_title text not null check (btrim(normalized_role_title) <> ''),
  role_family text not null default 'other',          -- values come from candidate_profiles.role_families
  location_text text,
  work_model text not null default 'unclear' check (work_model in ('remote', 'hybrid', 'onsite', 'unclear')),
  employment_type text,
  hiring_geography text,
  compensation_text text,
  posted_at timestamptz,
  discovered_at timestamptz not null default now(),
  official_apply_url text,
  external_job_id text,
  job_description_summary text,
  job_snapshot_path text,
  fit_decision text not null default 'unreviewed' check (fit_decision in ('unreviewed', 'apply', 'apply_cautiously', 'skip')),
  fit_reason text,
  material_gap text,
  eligibility_status text not null default 'uncertain' check (eligibility_status in ('confirmed', 'uncertain', 'ineligible')),
  pipeline_stage text not null default 'discovered' check (pipeline_stage in (
    'discovered', 'qualifying', 'researching', 'ready_to_apply', 'held', 'applied',
    'mapping_contacts', 'drafting_outreach', 'awaiting_approval', 'outreach_active',
    'replied', 'recruiter_screen', 'hiring_manager_interview', 'later_stage', 'offer',
    'closed_rejected', 'closed_withdrawn', 'closed_role_filled', 'closed_no_response',
    'closed_skipped', 'closed_other'
  )),
  priority smallint check (priority between 1 and 5),
  saved_search_id uuid,
  apply_tier text check (apply_tier is null or apply_tier in ('quick', 'full', 'packet')),
  gate_results jsonb not null default '{}'::jsonb check (jsonb_typeof(gate_results) = 'object'),
  qualified_at timestamptz,
  qualified_by_run_id uuid,
  next_action text,
  next_action_at timestamptz,
  closed_reason text,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (company_id, workspace_id) references public.companies(id, workspace_id) on delete cascade,
  check (
    pipeline_stage not like 'closed_%'
    or (closed_reason is not null and btrim(closed_reason) <> '' and closed_at is not null)
  )
);

create table public.opportunity_sources (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  opportunity_id uuid not null,
  platform text not null check (btrim(platform) <> ''),
  source_type text not null check (source_type in ('job_listing', 'feed_post', 'career_page', 'recruiter_post', 'referral', 'other')),
  source_url text not null check (btrim(source_url) <> ''),
  source_job_id text,
  first_seen_at timestamptz not null default now(),
  last_checked_at timestamptz,
  is_live boolean,
  is_official boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id, opportunity_id, source_url),
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade
);

create table public.contacts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  current_company_id uuid,
  full_name text not null check (btrim(full_name) <> ''),
  current_title text,
  linkedin_profile_url text,
  sales_nav_lead_url text,
  location_text text,
  connection_degree text check (connection_degree is null or connection_degree in ('first', 'second', 'third', 'out_of_network', 'unknown')),
  linkedin_message_available boolean,
  work_email text,
  email_verification_status text not null default 'unknown' check (email_verification_status in ('unknown', 'unverified', 'catch_all', 'verified', 'invalid')),
  email_source_url text,
  email_verified_at timestamptz,
  do_not_contact boolean not null default false,
  do_not_contact_reason text,
  last_verified_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (current_company_id, workspace_id) references public.companies(id, workspace_id) on delete cascade,
  check (not do_not_contact or (do_not_contact_reason is not null and btrim(do_not_contact_reason) <> '')),
  check (email_verification_status <> 'verified' or email_verified_at is not null)
);

create unique index contacts_workspace_linkedin_url_uidx
  on public.contacts (workspace_id, linkedin_profile_url)
  where linkedin_profile_url is not null;

create table public.opportunity_contacts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  opportunity_id uuid not null,
  contact_id uuid not null,
  priority_rank smallint not null check (priority_rank between 1 and 3),
  recipient_type text not null check (recipient_type in ('hiring_manager', 'functional_leader', 'sales_leader', 'recruiter', 'founder', 'job_poster', 'other')),
  relevance_reason text not null check (btrim(relevance_reason) <> ''),
  authority_status text not null default 'unknown' check (authority_status in ('confirmed', 'inferred', 'unknown')),
  relevance_status text not null default 'possible' check (relevance_status in ('verified', 'possible', 'rejected')),
  business_unit_match text,
  selected_channel text not null default 'none' check (selected_channel in ('linkedin_message', 'inmail', 'email', 'connection_note', 'none')),
  contact_status text not null default 'researching' check (contact_status in ('researching', 'selected', 'drafted', 'approved', 'contacted', 'replied', 'suppressed', 'not_contacting')),
  not_contacting_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id, opportunity_id, contact_id),
  unique (workspace_id, opportunity_id, priority_rank),
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (contact_id, workspace_id) references public.contacts(id, workspace_id) on delete cascade,
  check (contact_status <> 'not_contacting' or (not_contacting_reason is not null and btrim(not_contacting_reason) <> ''))
);

create table public.artifacts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  company_id uuid,
  opportunity_id uuid,
  artifact_type text not null check (artifact_type in ('cv', 'cover_letter', 'loom', 'work_sample', 'screenshot', 'job_snapshot', 'other')),
  internal_name text not null check (btrim(internal_name) <> ''),
  storage_path text not null check (btrim(storage_path) <> ''),
  content_hash text,
  version_label text,
  sanitized boolean not null default false,
  share_status text not null default 'private' check (share_status in ('private', 'approved_to_share', 'shared')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (company_id, workspace_id) references public.companies(id, workspace_id) on delete cascade,
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  opportunity_id uuid not null,
  application_channel text not null check (application_channel in ('ats', 'linkedin', 'indeed', 'email', 'referral', 'other')),
  application_url text,
  status text not null default 'preparing' check (status in ('preparing', 'held', 'submitted', 'confirmed', 'failed', 'withdrawn')),
  submitted_at timestamptz,
  confirmation_id text,
  confirmation_evidence_path text,
  cv_artifact_id uuid,
  cover_letter_artifact_id uuid,
  answers_snapshot jsonb not null default '{}'::jsonb check (jsonb_typeof(answers_snapshot) = 'object'),
  work_authorization_answer text,
  compensation_answer text,
  apply_tier text not null default 'quick' check (apply_tier in ('quick', 'full', 'packet')),
  run_id uuid,
  submission_mode text not null default 'supervised' check (submission_mode in ('supervised', 'workflow_approved')),
  held_reason text,
  cv_filename_sent text,
  cover_letter_text text,
  platform_account_email text,
  form_pages_seen smallint,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (cv_artifact_id, workspace_id) references public.artifacts(id, workspace_id),
  foreign key (cover_letter_artifact_id, workspace_id) references public.artifacts(id, workspace_id),
  check (status not in ('submitted', 'confirmed') or submitted_at is not null),
  check (status <> 'confirmed' or confirmation_evidence_path is not null or confirmation_id is not null),
  check (status <> 'held' or (held_reason is not null and btrim(held_reason) <> ''))
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  opportunity_id uuid not null,
  contact_id uuid not null,
  channel text not null check (channel in ('inmail', 'linkedin_message', 'connection_note', 'email')),
  message_type text not null check (message_type in ('initial', 'follow_up_1', 'follow_up_2', 'reply', 'thank_you', 'other')),
  subject text,
  body text not null check (btrim(body) <> ''),
  status text not null default 'draft' check (status in ('draft', 'awaiting_approval', 'approved', 'sent', 'failed', 'cancelled')),
  approved_at timestamptz,
  planned_send_at timestamptz,
  sent_at timestamptz,
  external_thread_id text,
  attachment_artifact_id uuid,
  supersedes_message_id uuid,
  failure_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (contact_id, workspace_id) references public.contacts(id, workspace_id) on delete cascade,
  foreign key (attachment_artifact_id, workspace_id) references public.artifacts(id, workspace_id),
  foreign key (supersedes_message_id, workspace_id) references public.messages(id, workspace_id),
  check (status not in ('approved', 'sent') or approved_at is not null),
  check (status <> 'sent' or sent_at is not null),
  check (status <> 'failed' or (failure_reason is not null and btrim(failure_reason) <> ''))
);

create table public.interactions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  opportunity_id uuid not null,
  contact_id uuid,
  interaction_type text not null check (interaction_type in ('reply', 'phone_call', 'recruiter_screen', 'interview', 'work_sample', 'offer', 'rejection', 'status_update', 'other')),
  direction text not null check (direction in ('inbound', 'outbound', 'meeting')),
  occurred_at timestamptz not null,
  summary text not null check (btrim(summary) <> ''),
  outcome text,
  next_action text,
  next_action_at timestamptz,
  evidence_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (contact_id, workspace_id) references public.contacts(id, workspace_id) on delete cascade
);

create table public.research_sources (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  company_id uuid,
  opportunity_id uuid,
  contact_id uuid,
  claim_type text not null check (claim_type in ('company', 'role', 'eligibility', 'contact', 'compensation', 'other')),
  claim_text text not null check (btrim(claim_text) <> ''),
  certainty text not null check (certainty in ('confirmed', 'inferred', 'unknown')),
  source_url text,
  source_title text,
  source_class text check (source_class is null or source_class in ('official_company', 'official_platform', 'person_profile_or_post', 'secondary_source', 'other')),
  accessed_at timestamptz not null default now(),
  quoted_text text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (company_id, workspace_id) references public.companies(id, workspace_id) on delete cascade,
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (contact_id, workspace_id) references public.contacts(id, workspace_id) on delete cascade,
  check (company_id is not null or opportunity_id is not null or contact_id is not null)
);

create table public.pipeline_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  opportunity_id uuid not null,
  event_type text not null check (btrim(event_type) <> ''),
  from_state text,
  to_state text,
  event_at timestamptz not null default now(),
  actor_type text not null check (actor_type in ('user', 'agent', 'external_system')),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  created_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade
);

-- ---------------------------------------------------------------------------
-- 2. The candidate layer: who the applier applies as
-- ---------------------------------------------------------------------------

create table public.candidate_profiles (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  full_name text not null check (btrim(full_name) <> ''),
  headline text,
  applicant_email text,
  phone_text text,
  location_text text,
  time_zone text,
  linkedin_url text,
  portfolio_url text,
  right_to_work jsonb not null default '[]'::jsonb check (jsonb_typeof(right_to_work) = 'array'),
  work_models_accepted text[] not null default array['remote']::text[],
  role_families jsonb not null default '[]'::jsonb check (jsonb_typeof(role_families) = 'array'),
  seniority_band text,
  years_experience numeric(4,1),
  languages jsonb not null default '[]'::jsonb check (jsonb_typeof(languages) = 'array'),
  education jsonb not null default '[]'::jsonb check (jsonb_typeof(education) = 'array'),
  facts_may_state jsonb not null default '[]'::jsonb check (jsonb_typeof(facts_may_state) = 'array'),
  must_not_claim text[] not null default array[]::text[],
  hard_requirements_excluded text[] not null default array[]::text[],
  preferred_company_patterns text[] not null default array[]::text[],
  salary_floor_amount numeric(12,2),
  salary_floor_currency text,
  salary_floor_period text check (salary_floor_period is null or salary_floor_period in ('hour', 'month', 'year')),
  salary_answer_policy text,
  notice_period_text text,
  earliest_start_text text,
  contract_types_accepted text[] not null default array['full_time']::text[],
  default_cv_artifact_id uuid,
  run_settings jsonb not null default '{"daily_target": 40, "quick_share": 30, "full_share": 8, "packets_per_day": 2, "time_limit_hours": 4, "run_days": ["mon","tue","wed","thu","fri"]}'::jsonb
    check (jsonb_typeof(run_settings) = 'object'),
  voice_sample text,
  profile_markdown_path text,
  content_hash text,
  approved_at timestamptz,
  approved_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id)
);

create table public.cv_routing_rules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  role_shape text not null check (btrim(role_shape) <> ''),
  match_keywords text[] not null default array[]::text[],
  match_role_families text[] not null default array[]::text[],
  artifact_id uuid not null,
  external_label text not null default 'my CV',
  priority smallint not null default 100,
  is_active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (artifact_id, workspace_id) references public.artifacts(id, workspace_id)
);

alter table public.candidate_profiles
  add constraint candidate_profiles_default_cv_fkey
  foreign key (default_cv_artifact_id, workspace_id) references public.artifacts(id, workspace_id);

create table public.answer_bank (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  question_key text not null check (btrim(question_key) <> ''),
  question_patterns text[] not null default array[]::text[],
  answer_type text not null default 'text'
    check (answer_type in ('text', 'boolean', 'number', 'choice', 'date', 'file', 'url')),
  answer_text text,
  answer_choices_preferred text[] not null default array[]::text[],
  max_length integer,
  scope text not null default 'global' check (scope in ('global', 'platform', 'company', 'role_family')),
  scope_value text,
  may_adapt boolean not null default false,
  approved boolean not null default false,
  approved_at timestamptz,
  use_count integer not null default 0,
  last_used_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  check (not approved or approved_at is not null)
);

create unique index answer_bank_key_scope_uidx
  on public.answer_bank (workspace_id, question_key, scope, (coalesce(scope_value, '')));

create table public.do_not_apply (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  scope text not null check (scope in ('company', 'domain', 'keyword', 'platform_account')),
  pattern text not null check (btrim(pattern) <> ''),
  reason text not null check (btrim(reason) <> ''),
  added_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id, scope, pattern)
);

-- ---------------------------------------------------------------------------
-- 3. Discovery: saved searches and sightings
-- ---------------------------------------------------------------------------

create table public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  name text not null check (btrim(name) <> ''),
  platform text not null check (btrim(platform) <> ''),
  search_url text,
  query_text text,
  filters jsonb not null default '{}'::jsonb check (jsonb_typeof(filters) = 'object'),
  cadence text not null default 'daily' check (cadence in ('daily', 'weekly', 'paused')),
  weekly_day text check (weekly_day is null or weekly_day in ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')),
  max_results_per_run smallint not null default 50,
  is_active boolean not null default true,
  pass_on_sight_of_20 smallint,                 -- stage D of onboarding
  last_run_at timestamptz,
  last_new_count integer,
  total_new_count integer not null default 0,
  total_qualified_count integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id, name)
);

alter table public.opportunities
  add constraint opportunities_saved_search_fkey
  foreign key (saved_search_id, workspace_id) references public.saved_searches(id, workspace_id) on delete set null;

-- ---------------------------------------------------------------------------
-- 4. The run ledger, questions, escalations, approvals
-- ---------------------------------------------------------------------------

create table public.runs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  run_type text not null check (run_type in ('daily', 'test_batch', 'weekly_review', 'inbox_sweep', 'manual')),
  approval_mode text not null check (approval_mode in ('supervised', 'workflow_approved')),
  engine_version text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  status text not null default 'running'
    check (status in ('running', 'completed', 'partial', 'stopped', 'failed')),
  target_submissions smallint,
  discovered_count integer not null default 0,
  qualified_count integer not null default 0,
  submitted_count integer not null default 0,
  held_count integer not null default 0,
  escalated_count integer not null default 0,
  failed_count integer not null default 0,
  replies_logged_count integer not null default 0,
  stop_reason text,
  summary text,
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  check (status = 'running' or finished_at is not null),
  check (status not in ('stopped', 'failed') or (stop_reason is not null and btrim(stop_reason) <> ''))
);

alter table public.applications
  add constraint applications_run_fkey
  foreign key (run_id, workspace_id) references public.runs(id, workspace_id) on delete set null;

alter table public.opportunities
  add constraint opportunities_qualified_by_run_fkey
  foreign key (qualified_by_run_id, workspace_id) references public.runs(id, workspace_id) on delete set null;

create table public.job_sightings (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  saved_search_id uuid,
  run_id uuid,
  platform text not null check (btrim(platform) <> ''),
  source_url text not null check (btrim(source_url) <> ''),
  source_job_id text,
  company_name_raw text,
  role_title_raw text,
  location_raw text,
  posted_text_raw text,
  content_hash text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  times_seen integer not null default 1,
  opportunity_id uuid,
  disposition text not null default 'new'
    check (disposition in ('new', 'linked', 'duplicate', 'ignored_rule', 'ignored_expired')),
  disposition_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  unique (workspace_id, platform, source_url),
  foreign key (saved_search_id, workspace_id) references public.saved_searches(id, workspace_id) on delete set null,
  foreign key (run_id, workspace_id) references public.runs(id, workspace_id) on delete set null,
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete set null
);

create table public.question_log (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  run_id uuid,
  opportunity_id uuid,
  application_id uuid,
  platform text,
  question_text text not null check (btrim(question_text) <> ''),
  normalized_question text,
  field_type text,
  required boolean,
  matched_answer_id uuid,
  resolution text not null check (resolution in (
    'answered_from_bank', 'derived_from_profile', 'left_blank_optional', 'escalated', 'skipped_application'
  )),
  answer_given text,
  created_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (run_id, workspace_id) references public.runs(id, workspace_id) on delete set null,
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (application_id, workspace_id) references public.applications(id, workspace_id) on delete cascade,
  foreign key (matched_answer_id, workspace_id) references public.answer_bank(id, workspace_id) on delete set null
);

create table public.escalations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  run_id uuid,
  opportunity_id uuid,
  application_id uuid,
  escalation_type text not null check (escalation_type in (
    'unanswerable_question', 'identity_or_sensitive_data', 'assessment_or_video',
    'captcha_or_verification', 'do_not_apply_hit', 'salary_below_floor', 'eligibility_conflict',
    'claim_not_in_profile', 'duplicate_suspected', 'interview_invite', 'reply_needs_answer',
    'platform_restriction', 'technical_failure', 'other'
  )),
  severity text not null check (severity in ('block', 'ask', 'info')),
  summary text not null check (btrim(summary) <> ''),
  proposed_action text,
  status text not null default 'open' check (status in ('open', 'resolved', 'dismissed')),
  resolved_at timestamptz,
  resolution_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (run_id, workspace_id) references public.runs(id, workspace_id) on delete set null,
  foreign key (opportunity_id, workspace_id) references public.opportunities(id, workspace_id) on delete cascade,
  foreign key (application_id, workspace_id) references public.applications(id, workspace_id) on delete cascade,
  check (status = 'open' or resolved_at is not null)
);

create table public.workflow_approvals (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null default '00000000-0000-4000-8000-000000000001'::uuid
    references public.campaign_workspaces(id) on delete restrict,
  approval_scope text not null check (approval_scope in (
    'candidate_profile', 'answer_bank', 'cv_routing', 'fit_rules', 'saved_searches',
    'do_not_apply', 'daily_run_workflow'
  )),
  version_label text not null check (btrim(version_label) <> ''),
  content_hash text,
  test_batch_run_id uuid,
  approved_at timestamptz not null default now(),
  approved_note text not null check (btrim(approved_note) <> ''),
  superseded_at timestamptz,
  superseded_reason text,
  created_at timestamptz not null default now(),
  unique (id, workspace_id),
  foreign key (test_batch_run_id, workspace_id) references public.runs(id, workspace_id) on delete set null
);

create unique index workflow_approvals_live_uidx
  on public.workflow_approvals (workspace_id, approval_scope)
  where superseded_at is null;

-- ---------------------------------------------------------------------------
-- 5. Indexes
-- ---------------------------------------------------------------------------

create index opportunities_workspace_stage_idx on public.opportunities (workspace_id, pipeline_stage);
create index opportunities_workspace_next_action_idx on public.opportunities (workspace_id, next_action_at) where next_action_at is not null;
create index opportunities_company_idx on public.opportunities (company_id);
create index opportunities_company_family_idx on public.opportunities (workspace_id, company_id, role_family, discovered_at desc);
create index opportunity_sources_opportunity_idx on public.opportunity_sources (opportunity_id);
create index contacts_company_idx on public.contacts (current_company_id);
create index opportunity_contacts_opportunity_idx on public.opportunity_contacts (opportunity_id, priority_rank);
create index applications_opportunity_idx on public.applications (opportunity_id, created_at desc);
create index applications_run_idx on public.applications (run_id, status);
create index messages_opportunity_idx on public.messages (opportunity_id, created_at desc);
create index messages_due_idx on public.messages (workspace_id, status, planned_send_at);
create index interactions_opportunity_idx on public.interactions (opportunity_id, occurred_at desc);
create index research_sources_opportunity_idx on public.research_sources (opportunity_id);
create index pipeline_events_opportunity_idx on public.pipeline_events (opportunity_id, event_at desc);
create index job_sightings_hash_idx on public.job_sightings (workspace_id, content_hash);
create index job_sightings_job_id_idx on public.job_sightings (workspace_id, platform, source_job_id) where source_job_id is not null;
create index question_log_resolution_idx on public.question_log (workspace_id, resolution, created_at desc);
create index escalations_open_idx on public.escalations (workspace_id, status, severity, created_at desc);

-- ---------------------------------------------------------------------------
-- 6. Triggers, RLS, grants
-- ---------------------------------------------------------------------------

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'campaign_workspaces', 'companies', 'opportunities', 'opportunity_sources', 'contacts',
    'opportunity_contacts', 'artifacts', 'applications', 'messages', 'interactions',
    'research_sources', 'candidate_profiles', 'cv_routing_rules', 'answer_bank',
    'do_not_apply', 'saved_searches', 'job_sightings', 'runs', 'escalations'
  ]
  loop
    execute format(
      'create trigger %I before update on public.%I for each row execute function public.set_job_hunt_updated_at()',
      table_name || '_set_updated_at', table_name
    );
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from anon, authenticated', table_name);
  end loop;
  -- append-only tables: RLS and revoke, no updated_at trigger
  foreach table_name in array array['pipeline_events', 'question_log', 'workflow_approvals']
  loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on table public.%I from anon, authenticated', table_name);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Views
-- ---------------------------------------------------------------------------

create view public.job_pipeline_overview
with (security_invoker = true)
as
select
  o.id as opportunity_id,
  o.workspace_id,
  c.id as company_id,
  c.name as company_name,
  o.role_title,
  o.role_family,
  o.location_text,
  o.work_model,
  o.hiring_geography,
  o.compensation_text,
  o.fit_decision,
  o.eligibility_status,
  o.pipeline_stage,
  o.priority,
  o.apply_tier,
  o.official_apply_url,
  o.discovered_at,
  application.status as application_status,
  application.submitted_at,
  application.cv_artifact_id,
  application.cv_filename_sent,
  coalesce(contact_rollup.verified_contact_count, 0) as verified_contact_count,
  coalesce(contact_rollup.contacts, '[]'::jsonb) as contacts,
  coalesce(message_rollup.draft_count, 0) as message_draft_count,
  coalesce(message_rollup.approved_count, 0) as message_approved_count,
  coalesce(message_rollup.sent_count, 0) as message_sent_count,
  latest_interaction.interaction_type as latest_interaction_type,
  latest_interaction.outcome as latest_interaction_outcome,
  latest_interaction.occurred_at as latest_interaction_at,
  o.next_action,
  o.next_action_at,
  floor(extract(epoch from (now() - coalesce(application.submitted_at, o.discovered_at))) / 86400)::integer as days_in_pipeline,
  o.closed_reason,
  o.closed_at,
  o.updated_at
from public.opportunities o
join public.companies c on c.id = o.company_id and c.workspace_id = o.workspace_id
left join lateral (
  select a.status, a.submitted_at, a.cv_artifact_id, a.cv_filename_sent
  from public.applications a
  where a.opportunity_id = o.id and a.workspace_id = o.workspace_id
  order by a.created_at desc
  limit 1
) application on true
left join lateral (
  select
    count(*) filter (where oc.relevance_status = 'verified')::integer as verified_contact_count,
    jsonb_agg(
      jsonb_build_object(
        'priority_rank', oc.priority_rank,
        'contact_id', ct.id,
        'full_name', ct.full_name,
        'current_title', ct.current_title,
        'recipient_type', oc.recipient_type,
        'relevance_status', oc.relevance_status,
        'contact_status', oc.contact_status,
        'selected_channel', oc.selected_channel
      ) order by oc.priority_rank
    ) as contacts
  from public.opportunity_contacts oc
  join public.contacts ct on ct.id = oc.contact_id and ct.workspace_id = oc.workspace_id
  where oc.opportunity_id = o.id and oc.workspace_id = o.workspace_id
) contact_rollup on true
left join lateral (
  select
    count(*) filter (where m.status in ('draft', 'awaiting_approval'))::integer as draft_count,
    count(*) filter (where m.status = 'approved')::integer as approved_count,
    count(*) filter (where m.status = 'sent')::integer as sent_count
  from public.messages m
  where m.opportunity_id = o.id and m.workspace_id = o.workspace_id
) message_rollup on true
left join lateral (
  select i.interaction_type, i.outcome, i.occurred_at
  from public.interactions i
  where i.opportunity_id = o.id and i.workspace_id = o.workspace_id
  order by i.occurred_at desc
  limit 1
) latest_interaction on true;

create view public.open_escalations
with (security_invoker = true)
as
select
  e.id as escalation_id,
  e.workspace_id,
  e.created_at,
  e.severity,
  e.escalation_type,
  e.summary,
  e.proposed_action,
  c.name as company_name,
  o.role_title,
  o.official_apply_url,
  o.pipeline_stage,
  a.status as application_status,
  e.run_id
from public.escalations e
left join public.opportunities o on o.id = e.opportunity_id and o.workspace_id = e.workspace_id
left join public.companies c on c.id = o.company_id and c.workspace_id = o.workspace_id
left join public.applications a on a.id = e.application_id and a.workspace_id = e.workspace_id
where e.status = 'open'
order by case e.severity when 'block' then 0 when 'ask' then 1 else 2 end, e.created_at desc;

create view public.run_overview
with (security_invoker = true)
as
select
  r.id as run_id,
  r.workspace_id,
  r.run_type,
  r.approval_mode,
  r.engine_version,
  r.started_at,
  r.finished_at,
  r.status,
  r.target_submissions,
  r.discovered_count,
  r.qualified_count,
  r.submitted_count,
  r.held_count,
  r.escalated_count,
  r.failed_count,
  r.replies_logged_count,
  (select count(*) from public.applications a
     where a.run_id = r.id and a.workspace_id = r.workspace_id and a.apply_tier = 'quick'
       and a.status in ('submitted', 'confirmed'))::integer as quick_submitted,
  (select count(*) from public.applications a
     where a.run_id = r.id and a.workspace_id = r.workspace_id and a.apply_tier = 'full'
       and a.status in ('submitted', 'confirmed'))::integer as full_submitted,
  (select count(*) from public.applications a
     where a.run_id = r.id and a.workspace_id = r.workspace_id and a.apply_tier = 'packet'
       and a.status in ('submitted', 'confirmed'))::integer as packet_submitted,
  r.stop_reason,
  r.summary
from public.runs r
order by r.started_at desc;

create view public.funnel_by_role_family
with (security_invoker = true)
as
select
  o.workspace_id,
  o.role_family,
  count(*)::integer as opportunities,
  count(*) filter (where o.fit_decision in ('apply', 'apply_cautiously'))::integer as qualified,
  count(*) filter (where exists (
    select 1 from public.applications a
    where a.opportunity_id = o.id and a.workspace_id = o.workspace_id
      and a.status in ('submitted', 'confirmed')))::integer as applied,
  count(*) filter (where o.pipeline_stage in ('replied', 'recruiter_screen', 'hiring_manager_interview', 'later_stage', 'offer'))::integer as replied_or_later,
  count(*) filter (where o.pipeline_stage in ('recruiter_screen', 'hiring_manager_interview', 'later_stage', 'offer'))::integer as screens_or_later,
  count(*) filter (where o.pipeline_stage = 'offer')::integer as offers
from public.opportunities o
group by o.workspace_id, o.role_family;

create view public.ready_to_apply_queue
with (security_invoker = true)
as
select
  o.workspace_id,
  o.id as opportunity_id,
  c.name as company_name,
  o.role_title,
  o.role_family,
  o.official_apply_url,
  o.fit_decision,
  o.material_gap,
  o.priority,
  o.apply_tier,
  o.posted_at,
  o.qualified_at,
  resumable.application_id as resume_application_id,
  case
    when resumable.application_id is not null then 0
    when o.apply_tier = 'packet' then 1
    when o.apply_tier = 'full' then 2
    else 3
  end as tier_order
from public.opportunities o
join public.companies c on c.id = o.company_id and c.workspace_id = o.workspace_id
left join lateral (
  select a.id as application_id
  from public.applications a
  where a.opportunity_id = o.id and a.workspace_id = o.workspace_id and a.status = 'preparing'
  order by a.created_at desc
  limit 1
) resumable on true
where o.pipeline_stage = 'ready_to_apply'
   or resumable.application_id is not null
order by tier_order, o.priority nulls last, o.posted_at desc nulls last;

revoke all on table public.job_pipeline_overview, public.open_escalations, public.run_overview,
  public.funnel_by_role_family, public.ready_to_apply_queue
from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 8. Functions the run calls
-- ---------------------------------------------------------------------------

create function public.job_hunt_close_run(
  p_run_id uuid,
  p_status text,
  p_stop_reason text default null,
  p_summary text default null
)
returns public.runs
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  r public.runs;
begin
  if p_status not in ('completed', 'partial', 'stopped', 'failed') then
    raise exception 'job_hunt_close_run: status must be completed, partial, stopped or failed';
  end if;

  update public.runs run
  set
    finished_at = coalesce(run.finished_at, now()),
    status = p_status,
    stop_reason = coalesce(p_stop_reason, run.stop_reason),
    summary = coalesce(p_summary, run.summary),
    discovered_count = (
      select count(*) from public.job_sightings s
      where s.run_id = run.id and s.workspace_id = run.workspace_id and s.disposition in ('new', 'linked')),
    qualified_count = (
      select count(*) from public.opportunities o
      where o.qualified_by_run_id = run.id and o.workspace_id = run.workspace_id
        and o.fit_decision in ('apply', 'apply_cautiously')),
    submitted_count = (
      select count(*) from public.applications a
      where a.run_id = run.id and a.workspace_id = run.workspace_id and a.status in ('submitted', 'confirmed')),
    held_count = (
      select count(*) from public.applications a
      where a.run_id = run.id and a.workspace_id = run.workspace_id and a.status = 'held'),
    escalated_count = (
      select count(*) from public.escalations e
      where e.run_id = run.id and e.workspace_id = run.workspace_id),
    failed_count = (
      select count(*) from public.applications a
      where a.run_id = run.id and a.workspace_id = run.workspace_id and a.status = 'failed'),
    replies_logged_count = (
      select count(*) from public.interactions i
      where i.workspace_id = run.workspace_id and i.direction = 'inbound'
        and i.created_at >= run.started_at and i.created_at <= coalesce(run.finished_at, now()))
  where run.id = p_run_id
  returning * into r;

  if r.id is null then
    raise exception 'job_hunt_close_run: run % not found', p_run_id;
  end if;
  return r;
end;
$$;

create function public.job_hunt_close_stale_runs(p_stale_after interval default interval '6 hours')
returns setof public.runs
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
declare
  stale record;
begin
  for stale in
    select id from public.runs
    where status = 'running' and started_at < now() - p_stale_after
  loop
    return next public.job_hunt_close_run(stale.id, 'failed', 'stale: no finish recorded', null);
  end loop;
  return;
end;
$$;

create function public.job_hunt_current_mode(
  p_workspace_id uuid default '00000000-0000-4000-8000-000000000001'::uuid
)
returns table (mode text, supervised_remaining integer, reason text)
language sql
security invoker
set search_path = pg_catalog, public
as $$
  with live_workflow as (
    select approved_at from public.workflow_approvals
    where workspace_id = p_workspace_id and approval_scope = 'daily_run_workflow' and superseded_at is null
  ),
  last_run as (
    select max(finished_at) as finished_at from public.runs
    where workspace_id = p_workspace_id and status in ('completed', 'partial', 'stopped')
  ),
  changed_scopes as (
    select count(*) as n from public.workflow_approvals w, last_run
    where w.workspace_id = p_workspace_id
      and w.approval_scope <> 'daily_run_workflow'
      and w.superseded_at is null
      and w.approved_at > coalesce(last_run.finished_at, '1970-01-01'::timestamptz)
  )
  select
    case when exists (select 1 from live_workflow) then 'workflow_approved' else 'supervised' end as mode,
    case
      when not exists (select 1 from live_workflow) then null
      when (select n from changed_scopes) > 0 then 5
      else 0
    end as supervised_remaining,
    case
      when not exists (select 1 from live_workflow) then 'no live daily_run_workflow approval'
      when (select n from changed_scopes) > 0 then 'a scope was re-approved since the last run: re-test 5'
      else 'live workflow approval; no scope changed since the last run'
    end as reason;
$$;

-- Duplicate check used by qualify gate 8: an open or recent opportunity at the
-- same company in the same role family.
create function public.job_hunt_duplicate_check(
  p_company_id uuid,
  p_role_family text,
  p_within interval default interval '90 days',
  p_workspace_id uuid default '00000000-0000-4000-8000-000000000001'::uuid
)
returns table (opportunity_id uuid, role_title text, pipeline_stage text, discovered_at timestamptz)
language sql
security invoker
set search_path = pg_catalog, public
as $$
  select o.id, o.role_title, o.pipeline_stage, o.discovered_at
  from public.opportunities o
  where o.workspace_id = p_workspace_id
    and o.company_id = p_company_id
    and o.role_family = p_role_family
    and (o.pipeline_stage not like 'closed_%' or o.discovered_at > now() - p_within)
  order by o.discovered_at desc;
$$;

revoke all on function public.job_hunt_close_run(uuid, text, text, text) from public, anon, authenticated;
revoke all on function public.job_hunt_close_stale_runs(interval) from public, anon, authenticated;
revoke all on function public.job_hunt_current_mode(uuid) from public, anon, authenticated;
revoke all on function public.job_hunt_duplicate_check(uuid, text, interval, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Storage: one private bucket, no client policies
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('job-hunt-artifacts', 'job-hunt-artifacts', false)
on conflict (id) do update set public = false;

-- ---------------------------------------------------------------------------
-- 10. Comments
-- ---------------------------------------------------------------------------

comment on table public.campaign_workspaces is 'The one private identity; independent of Supabase Auth. One user per project.';
comment on table public.candidate_profiles is 'One candidate per workspace: the only source of facts the applier may state about the person.';
comment on table public.answer_bank is 'Approved answers to application questions. A question with no match is escalated, never invented.';
comment on table public.runs is 'One row per applier run. Counts are written from the tables by job_hunt_close_run.';
comment on table public.escalations is 'What the run could not settle. block = the row stopped; ask = the user decides; info = for the record.';
comment on table public.workflow_approvals is 'The user''s approvals, in their own words. A live daily_run_workflow row lets the run submit without per-application approval.';
comment on table public.pipeline_events is 'Append-only by convention: evidence-backed state changes.';
comment on view public.job_pipeline_overview is 'One row per opportunity. The tables remain authoritative.';
