-- Schema audit for the job applier. Read-only. Every row should read PASS.
-- Works for a fresh project (00_job_applier_schema.sql) and for a v1 project
-- upgraded with the v2 migration.

with tracker_tables as (
  select unnest(array[
    'campaign_workspaces', 'companies', 'opportunities', 'opportunity_sources', 'contacts',
    'opportunity_contacts', 'artifacts', 'applications', 'messages', 'interactions',
    'research_sources', 'pipeline_events',
    'candidate_profiles', 'cv_routing_rules', 'answer_bank', 'do_not_apply',
    'saved_searches', 'job_sightings', 'runs', 'question_log', 'escalations', 'workflow_approvals'
  ]) as t
),
checks as (
  select '01 all 22 tables present' as check_name,
    (select count(*) from information_schema.tables it join tracker_tables tt on tt.t = it.table_name
      where it.table_schema = 'public') = 22 as ok
  union all
  select '02 every table has RLS',
    (select bool_and(c.relrowsecurity) from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      join tracker_tables tt on tt.t = c.relname
      where n.nspname = 'public' and c.relkind = 'r')
  union all
  select '03 no anon or authenticated grants on tables or views',
    (select count(*) from information_schema.role_table_grants g
      where g.table_schema = 'public' and g.grantee in ('anon', 'authenticated')
        and (g.table_name in (select t from tracker_tables)
             or g.table_name in ('job_pipeline_overview', 'open_escalations', 'run_overview',
                                 'funnel_by_role_family', 'ready_to_apply_queue'))) = 0
  union all
  select '04 no client policies',
    (select count(*) from pg_policies p
      where p.schemaname = 'public' and p.tablename in (select t from tracker_tables)) = 0
  union all
  select '05 workspace default on every campaign table',
    (select count(*) from information_schema.columns c
      where c.table_schema = 'public' and c.column_name = 'workspace_id'
        and c.column_default like '%00000000-0000-4000-8000-000000000001%'
        and c.table_name in (select t from tracker_tables) and c.table_name <> 'campaign_workspaces') = 21
  union all
  select '06 one candidate per workspace',
    exists (select 1 from pg_constraint
      where conrelid = 'public.candidate_profiles'::regclass and contype = 'u'
        and pg_get_constraintdef(oid) = 'UNIQUE (workspace_id)')
  union all
  select '07 opportunities.role_family is free text',
    not exists (select 1 from pg_constraint
      where conrelid = 'public.opportunities'::regclass and contype = 'c'
        and pg_get_constraintdef(oid) ilike '%role_family%')
  union all
  select '08 opportunities.pipeline_stage allows held and closed_skipped',
    exists (select 1 from pg_constraint
      where conrelid = 'public.opportunities'::regclass and contype = 'c'
        and pg_get_constraintdef(oid) ilike '%''held''%' and pg_get_constraintdef(oid) ilike '%''closed_skipped''%')
  union all
  select '09 applications.held requires held_reason',
    exists (select 1 from pg_constraint
      where conrelid = 'public.applications'::regclass and contype = 'c'
        and pg_get_constraintdef(oid) ilike '%held_reason%')
  union all
  select '10 applications carry tier, run, mode',
    (select count(*) from information_schema.columns
      where table_schema = 'public' and table_name = 'applications'
        and column_name in ('apply_tier', 'run_id', 'submission_mode', 'cv_filename_sent')) = 4
  union all
  select '11 answer_bank.approved requires approved_at',
    exists (select 1 from pg_constraint
      where conrelid = 'public.answer_bank'::regclass and contype = 'c'
        and pg_get_constraintdef(oid) ilike '%approved_at%')
  union all
  select '12 one live approval per scope',
    exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'workflow_approvals_live_uidx')
  union all
  select '13 sightings unique per platform and url',
    exists (select 1 from pg_constraint
      where conrelid = 'public.job_sightings'::regclass and contype = 'u'
        and pg_get_constraintdef(oid) ilike '%platform, source_url%')
  union all
  select '14 runs: stopped or failed need a reason',
    exists (select 1 from pg_constraint
      where conrelid = 'public.runs'::regclass and contype = 'c'
        and pg_get_constraintdef(oid) ilike '%stop_reason%')
  union all
  select '15 five views with security_invoker',
    (select count(*) from pg_class c
      where c.relkind = 'v'
        and c.relname in ('job_pipeline_overview', 'open_escalations', 'run_overview', 'funnel_by_role_family', 'ready_to_apply_queue')
        and c.reloptions::text ilike '%security_invoker=true%') = 5
  union all
  select '16 run functions exist',
    (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname in ('job_hunt_close_run', 'job_hunt_close_stale_runs', 'job_hunt_current_mode')) = 3
  union all
  select '17 functions not callable by anon or authenticated',
    not exists (
      select 1 from information_schema.role_routine_grants g
      where g.routine_schema = 'public' and g.grantee in ('anon', 'authenticated')
        and g.routine_name like 'job_hunt_%')
  union all
  select '18 updated_at triggers on mutable tables',
    (select count(distinct event_object_table) from information_schema.triggers
      where trigger_schema = 'public'
        and event_object_table in (
          'companies', 'opportunities', 'opportunity_sources', 'contacts', 'opportunity_contacts',
          'artifacts', 'applications', 'messages', 'interactions', 'research_sources',
          'candidate_profiles', 'cv_routing_rules', 'answer_bank', 'do_not_apply',
          'saved_searches', 'job_sightings', 'runs', 'escalations')) = 18
  union all
  select '19 private artifact bucket exists',
    exists (select 1 from storage.buckets where id = 'job-hunt-artifacts' and public = false)
  union all
  select '20 no bucket policies for clients',
    not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
      and (qual ilike '%job-hunt-artifacts%' or with_check ilike '%job-hunt-artifacts%'))
  union all
  select '21 no column named like a secret',
    not exists (select 1 from information_schema.columns
      where table_schema = 'public' and table_name in (select t from tracker_tables)
        and (column_name ilike '%password%' or column_name ilike '%token%' or column_name ilike '%secret%'
             or column_name ilike '%cookie%' or column_name ilike '%api_key%'))
)
select check_name, case when ok then 'PASS' else 'FAIL' end as result
from checks
order by check_name;
