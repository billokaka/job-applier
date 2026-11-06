# The daily run

What Claude Cowork does every day, in order. Supabase is the memory: every step reads from it
first and writes to it with evidence. The person is "the candidate"; every fact about them comes
from `candidate_profiles` and `answer_bank`. Nothing here names a person.

**Modes.** `supervised`: every submission is shown to the operator first (the test batch and the
re-test after a change). `workflow_approved`: submissions go out under the live
`daily_run_workflow` approval; only hard blocks and `ask` items reach the operator.

**Targets** come from the profile's run settings (default: 40 submissions, about 30 quick and 8
full; up to 2 packets; stop at 4 hours of run time).

```text
0 Health check → 1 Inbox sweep → 2 Due follow-ups → 3 Discover → 4 Qualify → 5 Apply by tier
→ 6 Packets → 7 Close the run → 8 Summary to the operator
```

## Step 0: health check (stop the run if any fails)

1. Supabase answers: `select 1`, then read `candidate_profiles` (exactly one row, `approved_at`
   set) and the live `workflow_approvals` rows. No `daily_run_workflow` approval means the run is
   `supervised`.
2. Any scope approval superseded since the last run means the first 5 submissions are
   `supervised` (re-test).
3. The browser is logged in: open LinkedIn Jobs, Indeed and Gmail; a login page on any of them is
   a `technical_failure` escalation for that platform and that platform is skipped today.
4. The CV files named in `cv_routing_rules` exist on disk at the recorded paths.
5. **Stale and interrupted work.** A `runs` row still `running` and older than 6 hours is marked
   `failed` with `stop_reason = 'stale: no finish recorded'` and closed with
   `job_hunt_close_run(id)`. Every `applications` row left `preparing` is queued for resume in
   step 5 (reopen, check the ATS for an existing submission, record or continue), never duplicated.
6. Open a `runs` row: `run_type = daily`, the mode, `target_submissions`, `status = running`.

## Step 1: inbox sweep (before any applying)

Gmail, LinkedIn messages, and any ATS notification emails since the last run's `finished_at`.

For each message that relates to an opportunity in Supabase (match by company, role, ATS id or
thread id):

- write an `interactions` row (type, direction, time, a faithful one-line summary, evidence path);
- move the opportunity's stage on evidence only (`replied`, `recruiter_screen`,
  `hiring_manager_interview`, `closed_rejected` with the reason), and write the `pipeline_events`
  row;
- an interview invite, a scheduling link, a question from a recruiter, or a request for anything
  (documents, a test, availability) is an `escalations` row at severity `ask` with a proposed
  reply in the candidate's register. **The reply is not sent.** It waits for approval, then goes
  through `messages` like any other send.

A message from an unknown company or recruiter about a role not in Supabase is logged as a new
`discovered` opportunity with `source_type = referral` or `recruiter_post`, then qualified in step 4.

## Step 2: due follow-ups

Read every `messages` row with `status = approved` and a planned send date of today or earlier,
and every opportunity whose `next_action_at` is due. Send only what carries an approval. Log the
exact copy and time. Follow-ups that need a new draft go to the summary as `ask` items.

## Step 3: discover

For each active `saved_searches` row (daily cadence, or weekly on its day):

1. Open the search URL or run the query on its platform, newest first, up to
   `max_results_per_run`.
2. For each listing, upsert a `job_sightings` row keyed by platform and URL. Fill the raw company,
   title, location, posted text, job id, and a content hash of title + company + location + the
   first 300 characters of the description. A row that existed gets `last_seen_at` and
   `times_seen` updated and is not re-qualified.
3. A new sighting whose hash matches an existing sighting is `duplicate`, linked to that
   sighting's opportunity, and the URL is added as an `opportunity_sources` row. Not re-qualified.
4. Update the search's `last_run_at` and `last_new_count`.

New sightings become `companies` (search by normalised name first) and `opportunities` rows at
stage `discovered`, with the sighting linked and an `opportunity_sources` row for the URL. Save
the posting text to the private bucket when the platform allows it (`job_snapshot_path`).

## Step 4: qualify

For each `discovered` opportunity, in order of posting date, run the gates from the profile and
the fit rules. Stop at the first fail. Record every gate in `gate_results`.

| # | Gate | Fail means |
| :-- | :-- | :-- |
| 1 | Right to work and location: the role's hiring geography is in the profile's list, or the role is remote and open to the candidate's country | `closed_skipped`, reason `eligibility` |
| 2 | Work model is in `work_models_accepted` | `closed_skipped`, reason `work_model` |
| 3 | Role family matches one in the profile's list (title and responsibilities, not title alone) | `closed_skipped`, reason `role_family` |
| 4 | Seniority inside the profile's band | `closed_skipped`, reason `seniority` |
| 5 | No requirement from `hard_requirements_excluded` is mandatory in the posting | `closed_skipped`, reason `excluded_requirement` |
| 6 | Published salary, if any, at or above the floor | `closed_skipped`, reason `salary_below_floor` |
| 7 | Company, domain and keywords not in `do_not_apply` | `closed_skipped`, reason `do_not_apply`, plus a `block` escalation (so the operator sees the hit) |
| 8 | No open or recent (90 days) opportunity at the same company in the same role family (`job_hunt_duplicate_check`) | `closed_skipped`, reason `duplicate`, linked to the earlier one |

A pass gets:

- `fit_decision`: `apply`, or `apply_cautiously` with `material_gap` written (one honest
  uncertainty, never more than one; two means skip);
- `priority` 1 to 5: the role family's priority, raised one step when the responsibilities match
  the candidate's strongest evidence, lowered one step for each soft mismatch;
- `apply_tier`: `quick` when the apply channel is Easy Apply, Indeed quick apply or a one-page
  form; `full` otherwise (`PLATFORMS.md` lists the systems); `packet` when priority is 1 and the
  day's packet count is under the profile's `packets_per_day`;
- stage `ready_to_apply`, `qualified_at`, `qualified_by_run_id`.

Qualify no more than the day needs: stop when `ready_to_apply` rows reach about 1.5 times the
remaining target, so tomorrow starts from fresh postings.

## Step 5: apply, by tier, priority first

Order: resumed `preparing` rows first, then packets' applications (they are the best fits), then
full, then quick, highest priority first (`ready_to_apply_queue` gives this order). Stop at the
target, the time limit, or when the queue is empty. **Time budget: 15 minutes per application;**
past it the row is `held` with reason `technical: time budget` and the run moves on.

Answers follow `ANSWER-AND-COPY-RULES.md` (the source rule, matching, derivation, the register).

For each opportunity:

1. **CV.** Pick the artifact by `cv_routing_rules` (first active rule whose keywords or role
   families match, lowest priority number wins); none matching means the profile's default. Record
   `cv_artifact_id` and `cv_filename_sent`. The file the employer sees is named so that it reads as
   one CV (the routing table's `external_label`); never a name that reveals a variant.
2. **Open the official apply URL.** A redirect to a platform the profile does not use, or a
   third-party aggregator asking for an account, is a `technical_failure` hold.
3. **Account.** If the ATS needs an account, use `applicant_email`; let the browser's password
   manager keep the password. Record `platform_account_email`. No password anywhere else.
4. **Fill the form, one question at a time.** For every field, write a `question_log` row:
   - a match in `answer_bank` (by `question_patterns`, then by meaning): use the approved answer
     exactly; `may_adapt = true` allows rewording to the question's length and form, never a new
     fact; `resolution = answered_from_bank`;
   - no match but derivable from `facts_may_state` (years, employers, tools, locations):
     `derived_from_profile`, and the derivation is written into `answer_given`;
   - optional and not derivable: leave blank, `left_blank_optional`;
   - required and not derivable: **hard block.** `escalated`; the application goes to `held` with
     `held_reason`; an `escalations` row of type `unanswerable_question` with the question text, so
     the operator can add it to the bank. Do not submit.
   - cover letter requested: build it from the profile's facts and the answer bank's cover-letter
     rules (four short paragraphs, the candidate's register, no claim outside the profile); store
     in `cover_letter_text`. In `supervised` mode it is shown; in `workflow_approved` mode it goes.
5. **Hard blocks** (`SYSTEM-DESIGN.md` §6): any trigger holds the row and escalates. Captchas,
   assessments, identity data and platform warnings are never worked around.
6. **Supervised mode:** before submitting, show the operator: company, role, official link, fit
   decision with points and gap, CV chosen, every answer, the cover letter, the attachment. Wait.
   Apply corrections; a corrected answer is written to `answer_bank` as `approved = false` with the
   note "from test batch, confirm", for the operator to approve in the review.
7. **Truth check, then submit.** Before pressing submit, re-read every answer about to go and
   check it against the source rule (`ANSWER-AND-COPY-RULES.md` §4); one unsourced answer holds
   the row. Write "truth check: n answers, n bank, n derived, n blank, 0 unsourced" to
   `applications.notes`. Then submit and capture evidence: the confirmation page screenshot to the
   private bucket (`<workspace_id>/<yyyy-mm>/<run_id>/<application_id>-confirmation.png`), the
   ATS or platform application id, the confirmation email if it arrives during the run. Set
   `applications.status = submitted` (or `confirmed` when evidence exists), `submitted_at`,
   `submission_mode`, `run_id`, `apply_tier`, `answers_snapshot` (every answer, no secrets);
   opportunity stage `applied`; `pipeline_events` row. **No confirmation, no `submitted`:** the
   row stays `preparing` with a note and the next run checks the ATS.
8. **Next action.** Set `next_action` to "status check" at submitted + 14 days.

Platform conduct: natural pace, one tab per platform, no more than one application in flight at a
time. A platform's warning, limit or lock is a `platform_restriction` block for that platform for
the rest of the run.

## Step 6: packets (up to 2 a day)

For the opportunities tiered `packet` and applied today, run `PACKET-FLOW.md` §1 to §3: the
compact evidence pack with `research_sources` rows; up to three verified contacts with relevance
and authority status (never a third for the count); one distinct draft per contact in `messages`
at `awaiting_approval`. **Nothing is sent.** Each draft is an `ask` item in the summary with the
recipient, channel, subject, exact body, attachment and planned follow-up date. The operator
approves each; the next run's step 2 sends what was approved.

## Step 7: close the run

Call `job_hunt_close_run(run_id, status, stop_reason, summary)`: it writes the counts from the
tables (discovered, qualified, submitted with this `run_id`, held, escalated, failed, replies
logged) and `finished_at`. `status` is `completed`, `partial` (target not reached: say why in
`stop_reason`) or `stopped` (a block that stopped the whole run). `summary` is the text of step 8.

## Step 8: the summary to the operator

One screen, this order, plain words. Omit empty sections, but say "no ask items" when there are
none.

```text
Daily run <date>, mode <supervised|workflow_approved>
Submitted <n>/<target> (quick <q>, full <f>, packet <p>) · held <h> · new replies <r>

ASK (your decision)
- <company>, <role>: interview invite for <date>. Proposed reply attached. [escalation id]
- <company>, <role>: outreach draft to <name, title> via <channel>. [message id]
- Question with no answer in the bank (<n> applications held): "<question text>". Add an answer?

BLOCKED (for the record; nothing to do unless you want to)
- <company>: do-not-apply hit (<pattern>).
- <platform>: restriction shown at <time>; platform skipped after <n> applications.

PIPELINE
- Screens booked: <n> · interviews: <n> · rejections: <n>
- Searches: <name> <new>/<qualified>; ... (a search with 0 qualified for 14 days is marked)

NEXT RUN: <date>; <n> rows ready to apply; re-test <on|off>.
```

## Weekly review (its own run type)

Read `run_overview`, `funnel_by_role_family`, `saved_searches`, `open_escalations` and
`question_log` grouped by `resolution`. Produce: submissions per day against the target; held and
escalation counts by type; screens per 100 submitted by role family, source and CV; search yields
with pause suggestions; the five-application hand check (right CV, right answers, confirmation
present); the kill-line read when due; one recommended change, with its reason. Status re-check of
applications under 30 days old with a portal. Answer-bank candidates (`approved = false`) listed
for the operator to approve.

*The flow is generic by design. Anything that reads as one person's fact belongs in the profile or
the answer bank, not here.*
