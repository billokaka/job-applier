-- Operating queries for the job applier. Read-only unless marked. The run and
-- the weekly review use these; the user can paste any of them into the SQL editor.

-- 1. Health: profile approved, live approvals, mode
select full_name, approved_at from public.candidate_profiles;
select approval_scope, version_label, approved_at from public.workflow_approvals where superseded_at is null order by approval_scope;
select * from public.job_hunt_current_mode();

-- 2. Stale runs (write: closes them as failed)
select * from public.job_hunt_close_stale_runs();

-- 3. Today's queue, in apply order
select * from public.ready_to_apply_queue limit 60;

-- 4. Open escalations, ASK first
select * from public.open_escalations;

-- 5. Due follow-ups: approved messages whose planned send is now or past
select m.id, c.name as company, ct.full_name, m.channel, m.message_type, m.planned_send_at
from public.messages m
join public.opportunities o on o.id = m.opportunity_id
join public.companies c on c.id = o.company_id
join public.contacts ct on ct.id = m.contact_id
where m.status = 'approved' and coalesce(m.planned_send_at, now()) <= now()
order by m.planned_send_at nulls first;

-- 6. Due next actions on opportunities
select c.name as company, o.role_title, o.pipeline_stage, o.next_action, o.next_action_at
from public.opportunities o join public.companies c on c.id = o.company_id
where o.next_action_at <= now() and o.pipeline_stage not like 'closed_%'
order by o.next_action_at;

-- 7. Active saved searches for today (daily, or weekly on this weekday)
select id, name, platform, search_url, max_results_per_run, last_run_at, last_new_count
from public.saved_searches
where is_active
  and (cadence = 'daily' or (cadence = 'weekly' and weekly_day = lower(to_char(now(), 'dy'))))
order by name;

-- 8. Duplicate check before qualifying (parameters: company id, role family)
-- select * from public.job_hunt_duplicate_check('<company uuid>', '<role_family>');

-- 9. Runs, last 7 days
select * from public.run_overview where started_at > now() - interval '7 days';

-- 10. Submissions per day, last 14 days
select date_trunc('day', submitted_at)::date as day, count(*) as submitted,
       count(*) filter (where apply_tier = 'quick') as quick,
       count(*) filter (where apply_tier = 'full') as full,
       count(*) filter (where apply_tier = 'packet') as packet
from public.applications
where status in ('submitted', 'confirmed') and submitted_at > now() - interval '14 days'
group by 1 order by 1 desc;

-- 11. Funnel by role family, by source platform, by CV
select * from public.funnel_by_role_family order by applied desc;

select s.platform, count(distinct o.id) as opportunities,
       count(distinct a.id) filter (where a.status in ('submitted', 'confirmed')) as applied,
       count(distinct o.id) filter (where o.pipeline_stage in ('recruiter_screen', 'hiring_manager_interview', 'later_stage', 'offer')) as screens_or_later
from public.opportunities o
join public.opportunity_sources s on s.opportunity_id = o.id
left join public.applications a on a.opportunity_id = o.id
group by s.platform order by applied desc;

select ar.internal_name as cv, count(a.id) filter (where a.status in ('submitted', 'confirmed')) as applied,
       count(distinct o.id) filter (where o.pipeline_stage in ('recruiter_screen', 'hiring_manager_interview', 'later_stage', 'offer')) as screens_or_later
from public.applications a
join public.opportunities o on o.id = a.opportunity_id
left join public.artifacts ar on ar.id = a.cv_artifact_id
group by ar.internal_name order by applied desc;

-- 12. Escalations by type, last 7 days
select escalation_type, severity, count(*) from public.escalations
where created_at > now() - interval '7 days' group by 1, 2 order by 3 desc;

-- 13. Questions with no answer (candidates for the answer bank), last 14 days
select normalized_question, count(*) as times, max(question_text) as example, bool_or(required) as ever_required
from public.question_log
where resolution = 'escalated' and created_at > now() - interval '14 days'
group by 1 order by 2 desc;

-- 14. Answer-bank rows waiting for approval
select question_key, scope, scope_value, answer_text, notes from public.answer_bank where not approved order by created_at;

-- 15. Search yields and pause candidates (0 qualified in 14 days)
select s.name, s.platform, s.total_new_count, s.total_qualified_count, s.last_run_at,
       (select count(*) from public.opportunities o where o.saved_search_id = s.id and o.qualified_at > now() - interval '14 days'
          and o.fit_decision in ('apply', 'apply_cautiously')) as qualified_14d
from public.saved_searches s where s.is_active order by qualified_14d desc;

-- 16. Hand-check sample: five random submitted applications with evidence
select c.name as company, o.role_title, a.cv_filename_sent, a.confirmation_id, a.confirmation_evidence_path, a.submitted_at, a.answers_snapshot
from public.applications a
join public.opportunities o on o.id = a.opportunity_id
join public.companies c on c.id = o.company_id
where a.status in ('submitted', 'confirmed') and a.submitted_at > now() - interval '7 days'
order by random() limit 5;

-- 17. Status re-check list: applications under 30 days with a portal
select c.name as company, o.role_title, a.application_url, a.platform_account_email, a.submitted_at
from public.applications a
join public.opportunities o on o.id = a.opportunity_id
join public.companies c on c.id = o.company_id
where a.status in ('submitted', 'confirmed') and a.submitted_at > now() - interval '30 days'
  and a.application_channel = 'ats' and o.pipeline_stage = 'applied'
order by a.submitted_at;

-- 18. Kill-line read: screens per 300 submitted since go-live
with s as (
  select count(*) as submitted from public.applications where status in ('submitted', 'confirmed')
), k as (
  select count(*) as screens from public.opportunities
  where pipeline_stage in ('recruiter_screen', 'hiring_manager_interview', 'later_stage', 'offer')
)
select s.submitted, k.screens,
       case when s.submitted > 0 then round(k.screens::numeric * 300 / s.submitted, 1) end as screens_per_300,
       case when s.submitted >= 300 and k.screens::numeric * 300 / s.submitted < 6 then 'FAILS the line' else 'holds or not yet readable' end as verdict
from s, k;

-- 19. Export (offboarding): the pipeline and the applications
-- \copy (select * from public.job_pipeline_overview) to 'pipeline.csv' csv header
-- \copy (select * from public.applications) to 'applications.csv' csv header
