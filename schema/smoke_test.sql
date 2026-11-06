-- Transaction-safe smoke test for the job applier schema. Inserts a fake
-- profile, run, company, opportunity, application and question, closes the run
-- through job_hunt_close_run, checks the counts and the mode, then rolls
-- everything back. Returns one row: PASS or FAIL with the reason.

begin;

do $$
declare
  v_profile uuid;
  v_run uuid;
  v_company uuid;
  v_opp uuid;
  v_app uuid;
  v_closed public.runs;
  v_mode record;
  v_count integer;
begin
  -- the mode before any approval must be supervised
  select * into v_mode from public.job_hunt_current_mode();
  if v_mode.mode <> 'supervised' or v_mode.supervised_remaining is not null then
    raise exception 'FAIL: mode before approval should be supervised with null remaining, got % / %', v_mode.mode, v_mode.supervised_remaining;
  end if;

  insert into public.candidate_profiles (full_name, applicant_email, location_text)
  values ('Smoke Test', 'smoke@example.invalid', 'Nowhere')
  on conflict (workspace_id) do update set full_name = excluded.full_name
  returning id into v_profile;

  insert into public.runs (run_type, approval_mode, target_submissions, engine_version)
  values ('test_batch', 'supervised', 1, 'smoke')
  returning id into v_run;

  insert into public.companies (name, normalized_name, website_url)
  values ('Smoke Test Company', 'smoke test company', 'https://example.invalid')
  returning id into v_company;

  insert into public.opportunities (company_id, role_title, normalized_role_title, role_family,
    pipeline_stage, fit_decision, qualified_at, qualified_by_run_id, apply_tier, official_apply_url)
  values (v_company, 'Smoke Role', 'smoke role', 'smoke_family',
    'ready_to_apply', 'apply', now(), v_run, 'quick', 'https://example.invalid/apply')
  returning id into v_opp;

  -- the queue must show it
  select count(*) into v_count from public.ready_to_apply_queue where opportunity_id = v_opp;
  if v_count <> 1 then
    raise exception 'FAIL: ready_to_apply_queue did not list the opportunity';
  end if;

  -- duplicate check must find it for the same company and family
  select count(*) into v_count from public.job_hunt_duplicate_check(v_company, 'smoke_family');
  if v_count <> 1 then
    raise exception 'FAIL: job_hunt_duplicate_check did not find the open opportunity';
  end if;

  insert into public.job_sightings (saved_search_id, run_id, platform, source_url, opportunity_id, disposition)
  values (null, v_run, 'smoke', 'https://example.invalid/job/1', v_opp, 'linked');

  insert into public.applications (opportunity_id, application_channel, status, submitted_at,
    confirmation_id, apply_tier, run_id, submission_mode, cv_filename_sent)
  values (v_opp, 'ats', 'submitted', now(), 'SMOKE-1', 'quick', v_run, 'supervised', 'my CV.pdf')
  returning id into v_app;

  insert into public.question_log (run_id, opportunity_id, application_id, platform, question_text, resolution, answer_given)
  values (v_run, v_opp, v_app, 'smoke', 'Smoke question?', 'left_blank_optional', null);

  insert into public.escalations (run_id, opportunity_id, application_id, escalation_type, severity, summary)
  values (v_run, v_opp, v_app, 'other', 'info', 'smoke escalation');

  -- a held application must carry a reason
  begin
    insert into public.applications (opportunity_id, application_channel, status, apply_tier, run_id)
    values (v_opp, 'ats', 'held', 'quick', v_run);
    raise exception 'FAIL: held without held_reason was accepted';
  exception
    when check_violation then null;
  end;

  -- an approved answer must carry approved_at
  begin
    insert into public.answer_bank (question_key, answer_text, approved) values ('smoke_key', 'x', true);
    raise exception 'FAIL: approved answer without approved_at was accepted';
  exception
    when check_violation then null;
  end;

  v_closed := public.job_hunt_close_run(v_run, 'completed', null, 'smoke summary');
  if v_closed.submitted_count <> 1 or v_closed.qualified_count <> 1 or v_closed.discovered_count <> 1
     or v_closed.escalated_count <> 1 or v_closed.status <> 'completed' or v_closed.finished_at is null then
    raise exception 'FAIL: close_run counts wrong: submitted %, qualified %, discovered %, escalated %',
      v_closed.submitted_count, v_closed.qualified_count, v_closed.discovered_count, v_closed.escalated_count;
  end if;

  -- a workflow approval flips the mode
  insert into public.workflow_approvals (approval_scope, version_label, approved_note, test_batch_run_id)
  values ('daily_run_workflow', 'smoke', 'smoke approval', v_run);

  select * into v_mode from public.job_hunt_current_mode();
  if v_mode.mode <> 'workflow_approved' or v_mode.supervised_remaining <> 0 then
    raise exception 'FAIL: mode after workflow approval should be workflow_approved / 0, got % / %', v_mode.mode, v_mode.supervised_remaining;
  end if;

  -- a scope re-approval after the last run triggers the re-test of 5
  -- (approved_at is set one second after the run closed: now() is fixed for the whole
  -- transaction, so a default timestamp would equal finished_at, not exceed it)
  insert into public.workflow_approvals (approval_scope, version_label, approved_note, approved_at)
  values ('answer_bank', 'smoke', 'smoke re-approval', now() + interval '1 second');

  select * into v_mode from public.job_hunt_current_mode();
  if v_mode.supervised_remaining <> 5 then
    raise exception 'FAIL: re-test should be 5 after a scope re-approval, got %', v_mode.supervised_remaining;
  end if;

  -- a second live approval for the same scope must be refused
  begin
    insert into public.workflow_approvals (approval_scope, version_label, approved_note)
    values ('answer_bank', 'smoke2', 'duplicate live approval');
    raise exception 'FAIL: two live approvals for one scope were accepted';
  exception
    when unique_violation then null;
  end;

  raise notice 'PASS: schema smoke test';
end $$;

rollback;

select 'PASS (rolled back; see the notice above for a FAIL reason if any)' as result;
