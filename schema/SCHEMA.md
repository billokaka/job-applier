# The data model

One private database per user. Related tables plus a few views; the tables are authoritative. Every
campaign table carries `workspace_id` (one fixed value per project), `created_at`, `updated_at`,
and composite foreign keys that keep related rows in the same workspace.

```text
campaign_workspaces
  ─1 candidate_profiles ──> artifacts (default CV)
  ─< cv_routing_rules ──> artifacts
  ─< answer_bank
  ─< do_not_apply
  ─< saved_searches ──< job_sightings ──> opportunities
  ─< companies ──< opportunities ──< opportunity_sources
                        ├──< applications ──> artifacts (CV, cover letter)
                        ├──< opportunity_contacts >── contacts
                        ├──< messages ──> contacts
                        ├──< interactions
                        ├──< research_sources
                        └──< pipeline_events
  ─< runs ──< applications · job_sightings · question_log · escalations
  ─< workflow_approvals ──> runs (the test batch)

views: job_pipeline_overview · ready_to_apply_queue · open_escalations · run_overview · funnel_by_role_family
functions: job_hunt_close_run · job_hunt_close_stale_runs · job_hunt_current_mode · job_hunt_duplicate_check
```

## The candidate layer

| Table | One row per | What matters |
| :-- | :-- | :-- |
| `candidate_profiles` | the user (unique per workspace) | identity for forms; `right_to_work` (array of country and status); `work_models_accepted`; `role_families` (key, label, priority, must include, must not include); seniority; `facts_may_state` (the proof list: the only facts the run may state); `must_not_claim`; `hard_requirements_excluded`; salary floor and `salary_answer_policy`; notice and start; `contract_types_accepted`; `default_cv_artifact_id`; `run_settings` (daily target, tier shares, packets, time limit, run days); `voice_sample`; `approved_at` |
| `cv_routing_rules` | a routing rule | `match_keywords`, `match_role_families` → `artifact_id`; `external_label` (the one file name the employer sees); `priority` (lowest wins) |
| `answer_bank` | an approved answer | `question_key`, `question_patterns`, `answer_type`, `answer_text` (the answer or a RULE), `answer_choices_preferred`, `scope` and `scope_value` (global, platform, company, role_family), `may_adapt`, `approved` (needs `approved_at`), `use_count` |
| `do_not_apply` | an exclusion | `scope` (company, domain, keyword, platform_account), `pattern`, `reason`, `expires_at` |

## Discovery

| Table | One row per | What matters |
| :-- | :-- | :-- |
| `saved_searches` | a search the run opens | `platform`, `search_url` or `query_text`, `filters`, `cadence` (daily, weekly + `weekly_day`, paused), `max_results_per_run`, `pass_on_sight_of_20` (stage D), yields |
| `job_sightings` | a listing seen (unique per platform + URL) | raw title, company, location, posted text, `source_job_id`, `content_hash`; `times_seen`; `opportunity_id`; `disposition` (new, linked, duplicate, ignored_rule, ignored_expired) |

## The pipeline

| Table | One row per | What matters |
| :-- | :-- | :-- |
| `companies` | employer (unique per normalised name) | type, size, geography, `research_status` |
| `opportunities` | opening (many sightings and sources map to one) | `role_family` (free text, from the profile's list), `work_model`, `hiring_geography`, `compensation_text`, `fit_decision` (unreviewed, apply, apply_cautiously, skip), `material_gap`, `gate_results` (per gate: pass or fail with reason), `priority` 1 to 5, `apply_tier` (quick, full, packet), `pipeline_stage` (discovered … ready_to_apply, held, applied … offer, closed_*), `next_action` and date, `closed_reason` required on any closed stage |
| `opportunity_sources` | a place the opening was seen | platform, type, URL, `is_official` |
| `applications` | a submission (usually one per opportunity) | `status` (preparing, held, submitted, confirmed, failed, withdrawn), `apply_tier`, `run_id`, `submission_mode` (supervised, workflow_approved), `cv_artifact_id` and `cv_filename_sent`, `cover_letter_text`, `answers_snapshot` (every answer, no secrets), `confirmation_id` or `confirmation_evidence_path` (required for confirmed), `held_reason` (required for held), `platform_account_email` |
| `artifacts` | a file (CV, cover letter, screenshot, job snapshot) | `storage_path` in the private bucket, `share_status` |
| `contacts`, `opportunity_contacts` | a person; a person's relevance to one opening (rank 1 to 3, recipient type, authority confirmed or inferred) | the packet tier only |
| `messages` | a draft or sent message to a person | `status` (draft … approved, sent), `approved_at` required for approved and sent, `planned_send_at`, exact `body` preserved |
| `interactions` | a reply, call, screen, interview, offer, rejection, status update | evidence path, next action |
| `research_sources` | a sourced claim about a company, role or contact | `certainty` confirmed, inferred, unknown; URL and access time |
| `pipeline_events` | a state change (append-only) | from, to, actor (user, agent, external_system) |

## The run ledger

| Table | One row per | What matters |
| :-- | :-- | :-- |
| `runs` | a run (daily, test_batch, weekly_review, inbox_sweep, manual) | `approval_mode`, `engine_version`, `target_submissions`, counts written by `job_hunt_close_run` from the tables, `status` (running, completed, partial, stopped, failed; the last two need `stop_reason`), `summary` |
| `question_log` | a form question met | `question_text`, `normalized_question`, `field_type`, `required`, `matched_answer_id`, `resolution` (answered_from_bank, derived_from_profile, left_blank_optional, escalated, skipped_application), `answer_given` |
| `escalations` | something the run could not settle | `escalation_type` (14 values), `severity` (block, ask, info), `summary`, `proposed_action`, `status` |
| `workflow_approvals` | a user approval of one scope | `approval_scope` (candidate_profile, answer_bank, cv_routing, fit_rules, saved_searches, do_not_apply, daily_run_workflow), `version_label`, `content_hash`, `test_batch_run_id`, `approved_note` (the user's words), `superseded_at`; one live row per scope |

## Views

| View | Gives |
| :-- | :-- |
| `job_pipeline_overview` | one readable row per opportunity: company, role, fit, stage, tier, application status, CV sent, contacts, message counts, latest interaction, next action, days in pipeline |
| `ready_to_apply_queue` | today's work in order: interrupted `preparing` rows, then packet, full, quick by priority and posting date |
| `open_escalations` | open items, block first, then ask, then info |
| `run_overview` | one row per run with counts and tier split |
| `funnel_by_role_family` | opportunities, qualified, applied, replied, screens, offers per family |

## Functions

| Function | Does |
| :-- | :-- |
| `job_hunt_close_run(run_id, status, stop_reason, summary)` | writes the run's counts from the tables and closes it |
| `job_hunt_close_stale_runs(interval)` | fails runs left running past the threshold (default 6 hours) |
| `job_hunt_current_mode(workspace_id)` | the mode (supervised or workflow_approved), how many submissions are supervised (0, or 5 after a scope re-approval), and why |
| `job_hunt_duplicate_check(company_id, role_family, within, workspace_id)` | open or recent opportunities at the same company in the same family (gate 8) |

## Rules the run enforces on top of the schema

- A fact on a form traces to `candidate_profiles.facts_may_state` or an approved `answer_bank` row;
  the trace is the `question_log` row; the truth check before submit confirms it.
- `submission_mode = workflow_approved` needs a live `daily_run_workflow` approval at submit time
  (`job_hunt_current_mode`).
- `submitted` is set only with a confirmation page, email or id captured.
- Counts come from `job_hunt_close_run`, never from memory.
- Secrets are never stored. The schema has no column for them, and `audit.sql` check 21 says so.

## Access model

Private and connector-operated: no Supabase Auth, RLS on every table, no `anon` or `authenticated`
grants, views with `security_invoker`, functions revoked from client roles, one private bucket
with no client policies. The user's Supabase account is the only key, and the user can revoke the
connector at any time.
