# Job campaign v2: the autonomous applier

**Date:** 2026-11-06 · **Engine version:** 2.1 (`CHANGELOG.md`) · **Status:** designed and
specified; migration written, not applied; nothing run · **Owner:** the operator · **Runner:**
Claude Cowork

## 1. What it is

One person's job search, run every day by Claude Cowork without the person's time. Cowork has the
browser (logged in to LinkedIn, Indeed, Gmail and the ATS accounts), the CVs on disk, and a private
Supabase project as its memory and CRM. Every day it finds new openings from saved searches,
qualifies them against the candidate's fit rules, applies to the ones that pass (target: 40
submissions a day), answers the application questions from an approved answer bank, sweeps the
inbox for replies and interview invites, logs everything to Supabase with evidence, and sends the
operator one short summary plus the list of things only a human can settle.

It is built generic. Everything about the person (facts, right to work, role families, CVs,
answers, salary floor, companies never to apply to) lives in the **candidate layer**: one profile,
one answer bank, one CV routing table, one do-not-apply list, one set of saved searches. The flow
and the schema never name a person. A second person is a second Supabase project with a second
profile, nothing else.

**v1 (August to September 2026)** was depth first: one company at a time, a research packet, three
mapped contacts, three distinct messages, approval before every submission and every message. It
ended in a hire for its first user. v2 keeps v1's data model and honesty rules, carries the packet
treatment into the engine as `PACKET-FLOW.md` for the best fits, and adds volume, autonomy and the
candidate layer on top.

## 2. Gates before dials

Facts that must be true before the dials (daily target, cadence, copy) matter at all:

| Gate | What must be true | How it is checked |
| :-- | :-- | :-- |
| G1 Eligibility | The candidate can legally take the roles the searches return (right to work, location, remote) | `candidate_profiles.right_to_work`; the qualify step's first test; roles that fail are `closed_skipped` |
| G2 Supply | The saved searches return enough qualified roles to apply to 40 a day | Read after the first 5 runs: `saved_searches.total_qualified_count`. Under 40 a day means the searches, not the applier, are the constraint |
| G3 Truth | Every fact on a form comes from the profile or the answer bank | `question_log.resolution`; a question with no source is escalated, never answered |
| G4 Access | Browser sessions hold for a full run; Supabase is reachable | The run's health check (step 0); a failure stops the run with a `technical_failure` escalation |
| G5 Approval | The operator has approved the workflow as a whole, on the evidence of a supervised test batch | A live `workflow_approvals` row with scope `daily_run_workflow` |

## 3. Architecture

```text
The user's folder (users/<slug>/), filled at onboarding (ONBOARDING-PLAN.md)
   candidate-profile.md · answer-bank.md · saved searches · do-not-apply · CV routing · cv/
        │  setup prompt loads them into Supabase; the user approves each scope
        ▼
Supabase (private project, the person's own account)
   v1: companies · opportunities · opportunity_sources · contacts · applications · messages ·
       interactions · research_sources · artifacts · pipeline_events
   v2: candidate_profiles · answer_bank · cv_routing_rules · do_not_apply · saved_searches ·
       job_sightings · runs · question_log · escalations · workflow_approvals
        ▲                                                            │
        │ reads rules and memory; writes rows with evidence           │ views: open_escalations,
        │                                                            │ run_overview, funnel
Claude Cowork, scheduled daily ──► Claude in Chrome (logged-in browser) ──► LinkedIn · Indeed ·
   (DAILY-RUN-FLOW.md)             local files: cv/*.pdf                    Wellfound · career pages ·
                                                                            ATS forms · Gmail
        │
        ▼
Operator: one daily summary + the escalation list (ask and block); weekly review
```

**Where secrets live:** nowhere in this workspace and nowhere in Supabase. The browser's own
sessions and password manager hold the logins. ATS accounts created during a run use the applicant
email from the profile and a password saved by the browser; Supabase records only that an account
exists on that platform (`applications.platform_account_email`).

**Resilience.** A Cowork run can die mid-way (browser crash, session end, time limit). The design
assumes it will:

- every write happens as soon as the fact exists (a sighting when seen, an application row when
  the form is opened, `submitted` the moment the confirmation is captured), so nothing is lost
  with the run;
- a `runs` row left `running` for more than 6 hours is a stale run: the next run marks it `failed`
  with `stop_reason = 'stale: no finish recorded'` and computes its counts from the tables;
- an `applications` row left `preparing` is resumed, not duplicated: the next run reopens the
  apply URL, checks the ATS for an existing submission, and either records it or continues;
- each application has a time budget (15 minutes); past it the row is `held` with reason
  `technical: time budget`, so one broken form cannot eat the run;
- counts are never kept in memory: `job_hunt_close_run()` writes them from the tables.

**Evidence paths** in the private bucket follow one convention so an export is one folder:
`<workspace_id>/<yyyy-mm>/<run_id>/<application_id>-confirmation.png`, and
`<workspace_id>/cv/<artifact internal name>.pdf` for the CVs.

## 4. The three tiers

| Tier | What it covers | Who approves | Daily share |
| :-- | :-- | :-- | :-- |
| **Quick** | LinkedIn Easy Apply, Indeed quick apply, and ATS forms that take the CV plus standard fields (name, email, location, right to work, salary, notice) | The workflow approval (G5); no per-item approval | about 30 |
| **Full** | Forms with custom questions, a cover letter, or multi-page ATS flows (Workday, Greenhouse, Lever, Workable, Ashby and the like). Answers are built only from the answer bank and the profile's `facts_may_state` | The workflow approval; any question with no source is a hard block | about 8 |
| **Packet** | The best fits of the day: the v1 treatment. Research pack, up to three mapped contacts, distinct outreach messages, follow-ups | The application as per the tier it falls in; **every message to a person is approved one by one** (a message is not a form) | up to 2 |

The 40 is quick plus full. Packets are extra and capped at 2 because they cost the operator
approval time.

**Tier assignment** happens at qualify: the application channel decides quick vs full; a priority of
1 (the fit rules' top band, plus a published salary at or above the floor, plus a role family with
priority 1) promotes to packet.

## 5. The approval model (FRAME, consequential)

This is the decision that makes v2 different from v1, so it got the full pass.

**The choice.** Per-application approval (v1) cannot reach 40 a day: the operator's time is the
thing the system exists to save. Workflow-level approval (the practice's A-8 rule: approve the
whole workflow after full testing; hard blocks still stop any row) can. The cost is that a wrong
answer goes out 40 times before anyone sees it.

**The design.**

1. **Setup approval.** The operator approves each scope separately: profile, answer bank, CV
   routing, fit rules, saved searches, do-not-apply. Each approval is a row in `workflow_approvals`
   with the operator's own note and a hash of the content approved.
2. **Supervised test batch.** The first 20 applications run in `supervised` mode: each one is shown
   before submission exactly as v1's Gate 1 (company, role, link, fit points and gaps, CV chosen,
   every answer). The operator corrects; corrections become answer-bank rows. The batch is a `runs`
   row of type `test_batch`.
3. **Workflow approval.** After the batch, the operator writes one approval row with scope
   `daily_run_workflow`, citing the batch. From then on the daily run submits without per-item
   approval.
4. **Re-test on change.** Any edit to the profile, answer bank, fit rules or CV routing supersedes
   that scope's approval and sends the next 5 applications back to supervised mode. The
   `daily_run_workflow` approval stays, so the run continues; only those 5 wait.
5. **Hard blocks never relax.** See §6. A blocked row is held, logged, escalated, and the run moves
   on.

**Outside view.** Mass-apply tools exist (browser auto-appliers for LinkedIn and Indeed). What the
public record says about them, labelled `[sourced: vendor and user reports, read in earlier
sessions, not re-checked today]`: the failure mode is never "too few applications", it is wrong
answers on forms, duplicate applications to the same employer, and the wrong CV attached. v2 is
designed around those three: the answer bank, the sightings table with a per-URL and per-hash
dedupe, and CV routing recorded on every application.

**Incentive on the recommender.** Claude designed and will run this, so the design's confidence is
downgraded: the supervised batch of 20 is the test, and the two-week read is where the design is
judged, not here.

**Premortem: it is 2026-12-06 and v2 failed. Why?**

| Cause | Guard in the design |
| :-- | :-- |
| The searches return few qualified roles; the applier idles at 8 a day and nobody notices | G2 is read after five runs; `saved_searches` yields are in the weekly review; under-supply is a search problem, not an applier problem |
| A wrong salary or right-to-work answer went to 100 employers | The supervised batch; `answer_bank.approved` is required to use an answer; the re-test on change |
| The same company got three applications in a week | `job_sightings` dedupe by URL, job id and content hash; the qualify step checks `companies` for an open or recent opportunity (90 days, same role family) |
| The wrong CV went out | `cv_routing_rules` with a default; `applications.cv_filename_sent` recorded; the weekly review samples five |
| LinkedIn or Indeed restricted the account | `platform_restriction` escalation at severity block stops that platform for the run; the operator decides |
| The run answered a question with a made-up fact | G3: no source, no answer; `question_log` shows every answer's source; `claim_not_in_profile` escalations |
| Interview invites sat unread in Gmail for days | The inbox sweep is step 1 of every run, before any applying; invites are `ask` escalations at the top of the summary |
| Supabase paused (free plan) and the run wrote nothing | Step 0 health check; a run that cannot write stops before it applies |
| The operator stopped reading the summaries | The summary is one screen; `ask` items first; a run with no `ask` items says so in one line |

**Kill condition (number and derivation).** Read on 2026-11-20 or at 300 submitted applications,
whichever is first: **fewer than 6 recruiter screens per 300 submitted (2%) stops volume mode.**
Derivation `[assumed]`: public reports on mass applications put screen rates in the low single
digits; 2% is set as the floor below which the applier is producing noise, and the first read
establishes the own baseline that replaces this number. On a stop, diagnose top-down: eligibility
→ role family and seniority targeting → CV position → answers → sources. Never all at once.

**What FRAME changed:** the supervised batch was 10 in the first draft; it is 20 because the
answer bank grows most in the first batch and 10 would leave the full tier untested. The daily
40 became a target with a kill line rather than a promise. Packets were capped at 2.

## 6. Hard blocks

A hard block stops the row, sets the application to `held` (or the opportunity to `closed_skipped`
when nothing was started), writes an `escalations` row at severity `block`, and the run continues
with the next row. The list never relaxes under any approval.

| Block | Trigger |
| :-- | :-- |
| Unanswerable question | A required question with no match in the answer bank and no derivation from `facts_may_state` |
| Identity or sensitive data | The form asks for a government ID number, passport number, date of birth, bank details, a photo, references' private contact details, or a signature on terms the operator has not read |
| Assessment or video | A timed test, a coding or skills assessment, a recorded video answer, or a personality questionnaire. The run never does these on the candidate's behalf |
| Captcha or verification | A captcha, a phone or email verification code, or a two-factor prompt |
| Do-not-apply hit | The company, its domain, or a keyword matches `do_not_apply` (the current employer, its clients, protected names, companies the operator excluded) |
| Salary below floor | A published or required salary field below `salary_floor_amount` |
| Eligibility conflict | The role requires a right to work the profile does not list, on-site presence the profile does not accept, or a language the profile does not list |
| Claim not in profile | Answering would require a degree, certification, employer, number or skill not in `facts_may_state` |
| Duplicate suspected | An open or recent opportunity at the same company in the same role family, or a sighting whose content hash matches an applied role |
| Platform restriction | The platform shows a limit, a warning, a lock or an unusual verification. Stops that platform for the rest of the run |

**Never, regardless of mode:** apply to a protected name; state that several CV versions exist
(externally there is one, "my CV"); send a message to a person without that message's approval;
mark `submitted` without a confirmation page, email or ATS id; store a password, token, cookie or
identity number anywhere.

## 7. Discovery and monitoring

- **Saved searches** are rows in `saved_searches`: platform, URL or query, filters, cadence, cap
  per run. The run opens each active search, newest first, and records every listing as a
  `job_sightings` row (unique per platform and URL; hash of title, company, location and the JD
  excerpt for cross-platform duplicates). A sighting seen before is counted, not re-qualified.
- **Hiring posts** on LinkedIn (feed and search) are a saved search of platform `linkedin_posts`;
  they create sightings of `source_type` `feed_post` and go through the same qualify step.
- **Inbox sweep** (every run, first): Gmail and LinkedIn messages for replies to applications and
  outreach; ATS status emails (rejection, next step, interview). Each becomes an `interactions`
  row and a stage change with evidence. An interview invite or a question from a recruiter is an
  `ask` escalation with a proposed reply; the reply itself is approved before sending.
- **Status re-check** (weekly): every application under 30 days old with an ATS portal is reopened
  and its status recorded.
- **Search health** (weekly): a search with zero qualified roles in 14 days is paused and listed.

## 8. Qualify: gates, then priority, then tier

Gates are pass/fail from the profile and fit rules, in this order, stopping at the first fail:
eligibility (right to work and location), work model, role family in the profile's list, seniority
band, excluded requirements, salary floor when published, do-not-apply, duplicate. Results go in
`opportunities.gate_results` as `{gate: pass|fail, reason}`. A fail sets `fit_decision = skip` and
`closed_skipped` with the gate as the reason.

A pass gets `fit_decision = apply` or `apply_cautiously` (one material uncertainty, recorded in
`material_gap`), a priority 1 to 5 from the role family's priority and the strength of the
responsibility match, and a tier (§4).

## 9. Measurement

Read weekly (`run_overview`, `funnel_by_role_family`, `saved_searches`):

- submitted per day against the 40 target, split by tier;
- held and escalated per run, by type (a rising `unanswerable_question` count means the answer
  bank needs work, not the run);
- screens per 100 submitted, by role family, source and CV position;
- yield per saved search;
- a sample of five applications checked by hand for the right CV and the right answers.

Diagnose top-down (§5's kill condition). One change at a time, then two weeks.

## 10. One engine, many users

The engine is this folder. A user is `users/<slug>/` (profile, answer bank, onboarding record,
README, CVs; git-ignored) plus a Supabase project in that user's own account. `ONBOARDING-PLAN.md` takes a new
user from the fit check to a live run in nine gated stages, with a 15-question interview that
Cowork runs (prompt 0) and an offboarding that leaves nothing of the user with the operator.

The invariants:

- nothing in `applier/` names a person; a user-specific need is met in the user's files;
- an engine change is versioned in `CHANGELOG.md`; each user's README records the version they
  run; moving a user to a new version triggers the re-test rule (§5);
- one Supabase project per user, in the user's account, revocable by the user;
- the user writes every approval in their own words.

## 11. Files

| File | What it is |
| :-- | :-- |
| `README.md` | The engine's index and scope |
| `SYSTEM-DESIGN.md` | This file |
| `ONBOARDING-PLAN.md` | A new user from fit check to live; offboarding |
| `DAILY-RUN-FLOW.md` | The run, step by step, with the hard blocks and the summary format |
| `PACKET-FLOW.md` | The depth treatment for the best fits: research pack, three people, distinct messages, follow-ups |
| `ANSWER-AND-COPY-RULES.md` | Source rule, matching, derivation, truth check, register, cover letters, declines |
| `PLATFORMS.md` | What each job platform and application system asks, its tier, and what stops it |
| `COWORK-TASK-PROMPTS.md` | Paste-ready prompts: onboarding interview, setup, test batch, daily run, weekly review, re-test, offboarding |
| `SETUP-CHECKLIST.md` | The short operator checklist for stages E to H |
| `CHANGELOG.md` | Engine versions |
| `templates/` | `candidate-profile.md`, `answer-bank.md`, `onboarding-record.md`, `user-README.md` |
| `schema/` | The database: the fresh-project script, the seed, the audit, the smoke test, the operating queries, `SCHEMA.md` |
| `cv-generator/` | The CV builder: skill, claim-sheet schema, PDF builder |
| `CLAUDE.md`, `LICENSE`, `.gitignore` | The entry file for Claude; MIT; `users/` and PDFs kept out of git |
| `users/<slug>/` | One folder per user, private |

*Provenance: the v1 facts are `[observed]` from the archived files; the tier shares, the 20-application
batch, the 2% kill line and the premortem causes are `[assumed]` design choices to be replaced by the
own baseline after the first read; the auto-applier failure modes are `[sourced]` from vendor and user
reports read in earlier sessions and not re-checked today.*
