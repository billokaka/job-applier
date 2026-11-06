# Cowork task prompts

Paste-ready. Each prompt stands on its own: it names the files to read and the Supabase project to
use, and it assumes no past chat. Replace `<applier>` (the path of this folder on the machine),
`<slug>` and `<project-ref>` once per user. The Supabase project reference is an identifier, not a
secret; never paste a key, password or token into a prompt. In Cowork or Claude Code opened on this
folder, "onboard me" is enough: `CLAUDE.md` routes to prompt 0.

| # | Prompt | When | Mode |
| :-- | :-- | :-- | :-- |
| 0 | Onboarding interview | Stage A of `ONBOARDING-PLAN.md`, once | interactive |
| 1 | Setup | Stage F, once (and per scope on a re-test) | interactive |
| 2 | Test batch | Stage G, once | supervised |
| 3 | Daily run | Scheduled, weekdays | workflow-approved |
| 4 | Weekly review | Scheduled, weekly | read and report |
| 5 | Re-test | After any change to the user's files | automatic |
| 6 | Offboarding | On a hire, a stop or a request | interactive |

---

## 0. Onboarding interview (stage A, interactive, with the user)

```text
You are onboarding a new user to the job applier. Read first:
1. <applier>/ONBOARDING-PLAN.md (§0, §1 and stage A)
2. <applier>/templates/candidate-profile.md
3. <applier>/templates/answer-bank.md
4. <applier>/ANSWER-AND-COPY-RULES.md §5 (the register)

Create <applier>/users/<slug>/ from the templates (candidate-profile.md,
answer-bank.md, onboarding-record.md, README.md from user-README.md).

Run the fit check (plan §1), then the interview (stage A), one question at a time, in plain
words, in the order given. Do not skip a question; do not fill a field the user did not answer.
Write every answer in the user's own words into the two files, labelled [sourced: user, <date>].
Keep the voice sample verbatim in the onboarding record.

When the interview ends: list every field still blank, grouped by whether it blocks go-live
(plan §4) or not; read the "never answer" list (answer bank §D) to the user and record their
confirmation; set the README status to onboarding and the engine version from CHANGELOG.md.

Rules: a blank is honest; never guess; never write a password, token or identity number; the user
decides what is named and cited about them. End with the list of blanks and the next stage (B,
CV intake).
```

## 1. Setup (stage F, interactive)

```text
You are setting up the job applier for the user in <applier>/users/<slug>/.
Read, in this order:
1. <applier>/SYSTEM-DESIGN.md
2. <applier>/DAILY-RUN-FLOW.md
3. <applier>/users/<slug>/candidate-profile.md
4. <applier>/users/<slug>/answer-bank.md
5. <applier>/schema/SCHEMA.md

Supabase project: <project-ref>, the user's own account. Do not use any other project.

Do this:
A. Check the schema: run <applier>/schema/audit.sql (every
   row PASS) and schema/smoke_test.sql (PASS). If a check fails because the schema is missing,
   stop and tell me; do not create or migrate the schema yourself.
B. Load the candidate layer from the two markdown files into Supabase: one candidate_profiles
   row; one answer_bank row per answer (approved = false); cv_routing_rules rows; do_not_apply
   rows; saved_searches rows. Upload each CV in the profile's CV table to the private bucket
   job-hunt-artifacts under <workspace_id>/cv/ and create its artifacts row (artifact_type cv,
   share_status approved_to_share). Set the profile's default_cv_artifact_id.
C. Read everything back and show me a table per scope so the user can check it. Mark any
   field left blank because the markdown did not say.
D. Check the browser: open LinkedIn Jobs, each job board and the email the saved searches and
   the inbox sweep need. Tell me which are signed in. Do not sign in; do not store a password.
E. When the user says "approve <scope>: <own words>", write a workflow_approvals row for that
   scope with those words as approved_note and a hash of the loaded content, superseding any
   live row for the scope. On "approve answer_bank" set approved = true and approved_at on
   every answer_bank row. On "approve candidate_profile" set candidate_profiles.approved_at.
   Mirror each approval into users/<slug>/README.md.

Rules: never invent a fact about the user; a blank is honest. No application, message or form
is submitted in setup. Report in plain words, one table per scope.
```

## 2. Test batch (stage G, supervised)

```text
Run the job applier's supervised test batch for the user in
<applier>/users/<slug>/, Supabase project <project-ref>. Read first:
1. <applier>/DAILY-RUN-FLOW.md (the whole file)
2. <applier>/ANSWER-AND-COPY-RULES.md (the whole file)
3. <applier>/SYSTEM-DESIGN.md §4 to §6

Mode: supervised. Target: 20 submitted applications across quick and full tiers, at least 5
full. No packets today. Time limit: 3 hours.

Follow the flow exactly: step 0 health check (open a runs row, run_type test_batch,
approval_mode supervised), step 1 inbox sweep, step 3 discover, step 4 qualify, step 5 apply.
Before every submission show, in one block: company, role, official link, fit decision with the
strongest fit points and the material gap, the CV chosen (internal name) and the file name the
employer will see, every question with the answer and its source (bank, derived, blank), the
cover letter if any, the truth-check line. Wait for the user. "go" submits; a correction is
applied, then "go"; "skip" closes the opportunity as closed_skipped with the user's reason.

Every correction becomes an answer_bank row (approved = false, note "from test batch,
confirm"). Every question goes to question_log with its resolution. Hard blocks hold the row
and escalate; show the block and move on. Never submit without a confirmation page or id.
Close the run with job_hunt_close_run and give the step 8 summary plus the list of answer_bank
rows waiting for approval. Append the batch's facts to users/<slug>/onboarding-record.md §G.
```

After the batch, the user reviews the pending rows and, when satisfied, says: "approve
daily_run_workflow, based on test batch run <run id>: <own words>". Prompt 1's rule E writes it.

## 3. Daily run (scheduled, weekdays)

```text
Run today's job applier run for the user in <applier>/users/<slug>/,
Supabase project <project-ref>. Read first:
1. <applier>/DAILY-RUN-FLOW.md (the whole file)
2. <applier>/ANSWER-AND-COPY-RULES.md (the whole file)
3. <applier>/PACKET-FLOW.md (for step 6)
4. <applier>/PLATFORMS.md (tiers and blockers)
Follow the flow step by step, 0 to 8. Do not skip the inbox sweep. The queries the steps need
are in <applier>/schema/queries.sql.

Mode: read it from Supabase with job_hunt_current_mode(). workflow_approved means submit under
the live approval; supervised means stop before any submission and tell the user. A scope
approval superseded since the last run means the first 5 submissions today are supervised:
show each and wait for "go".

Targets: from candidate_profiles' run settings (default 40 submissions, about 30 quick and 8
full; up to 2 packets; 4 hours). Stop at whichever comes first.

Hard rules (never relax): no fact about the user that is not in candidate_profiles.facts_may_state
or an approved answer_bank row; a required question with no source holds the application and
escalates; the truth check runs before every submit; no assessments, videos, captchas, identity
numbers, payment details or terms, ever; no application to a do_not_apply match; no message to
a person without that message's approval; externally there is one CV, "my CV"; no password,
token or cookie stored anywhere; no "submitted" without a confirmation page, email or id; 15
minutes per application at most. A platform warning or limit stops that platform for the day.

Write to Supabase as you go, with evidence paths. Close the run with job_hunt_close_run. End
with the step 8 summary, ASK items first. If there are no ASK items, say so in one line.
```

## 4. Weekly review (scheduled, weekly)

```text
Run the weekly review for the job applier, user <applier>/users/<slug>/,
Supabase project <project-ref>. Read first:
<applier>/DAILY-RUN-FLOW.md ("Weekly review") and
<applier>/SYSTEM-DESIGN.md §5 (the kill condition) and §9.

Open a runs row (run_type weekly_review). Then:
1. Read run_overview for the last 7 days: submissions per day against target, by tier; held
   and escalated by type.
2. Read funnel_by_role_family: screens per 100 submitted by role family. Also by source
   (opportunity_sources.platform) and by CV (applications.cv_artifact_id).
3. Read saved_searches: new and qualified per search; propose pausing any with 0 qualified
   in 14 days.
4. Status re-check: reopen every application under 30 days old that has an ATS portal and
   record its status as an interactions row where it changed.
5. Hand check: pick 5 submitted applications at random; open their evidence; confirm the CV
   sent matches the routing rule and the answers match the bank. Report mismatches.
6. List answer_bank rows with approved = false, and open escalations older than 3 days.
7. Kill line: if 300 submitted or the kill-line date in users/<slug>/README.md has passed, read
   screens per 300 and say whether the line (6 per 300) holds. If it fails, name the first
   stage with no evidence in this order: eligibility, targeting, CV, answers, sources. One
   recommended change only.

Close the run with job_hunt_close_run. Report in one screen, plain words, tables for the
numbers. Append one line to users/<slug>/README.md's status log.
```

## 5. Re-test (after a change to the user's files)

Nothing to paste: the user edits the markdown, prompt 1's step B reloads that scope ("reload the
answer bank from the file"), and the user says "approve <scope>: <own words>". The old approval is
superseded, the new one written, and the next daily run supervises its first 5 submissions on its
own (`job_hunt_current_mode()` reports it).

## 6. Offboarding (interactive)

```text
Offboard the job applier user in <applier>/users/<slug>/, Supabase
project <project-ref>. Read <applier>/ONBOARDING-PLAN.md §6.

1. Confirm with the user the reason (hired, pause, request) and whether they keep the Supabase
   project. Pause is not offboarding: for a pause, set every saved_search to paused, tell the
   user to unschedule the daily run and the weekly review, set the README status to paused, and
   stop here.
2. Export to users/<slug>/export-<date>/: job_pipeline_overview as CSV; applications with
   evidence paths as CSV; answer_bank as markdown; the open escalations. Download the bucket's
   evidence files into the export folder. Tell the user where it is.
3. On the user's written "delete": list what will be deleted (project or tables, bucket
   contents, the user folder except the export) and wait for a second "delete". Then delete.
4. Tell the user to revoke the Cowork connector and any access they granted the operator.
5. Write the "Lessons for the engine" section of the onboarding record with every personal fact
   removed; copy it to the operator. Set the README status to offboarded.

Never delete without the two written confirmations. Never keep a copy of the user's data.
```

---

*These prompts carry the rules by reference, not by copy: the flow and the rules files own them.
If a rule changes, change those files and `CHANGELOG.md`, never the prompt alone.*
