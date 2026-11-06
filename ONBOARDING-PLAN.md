# Onboarding a new user

How a new person goes from "I want this" to a daily run that applies on their behalf, with every
fact theirs, every approval theirs, and nothing of them stored where it should not be. Written for
the operator who onboards (it can be the user) and for Cowork, which runs the interview and the
setup. Engine version: see `CHANGELOG.md`.

**Time, `[assumed]`:** about five working days end to end, with two to three hours of the user's
own time in total. The slow parts are the user's answers and the first test batch, not the setup.

## 0. Principles (read before the first call)

1. **The user's facts only.** The profile and the answer bank are built from the user's CVs and
   the user's own answers in the interview. Nothing is inferred into a claim. A blank waits for the
   user; it is never filled by guesswork.
2. **One user, one Supabase project, in the user's own account.** The operator never hosts another
   person's job data on a shared or employer project. The user can revoke access in one click.
3. **The user's own browser and logins.** The applier uses sessions the user signed in to. No
   password, cookie or token is ever written to a file, a prompt or the database.
4. **The user approves, scope by scope, then the workflow.** Nothing is submitted until the
   supervised batch has run and the user has written the approval in their own words.
5. **The user decides what is said about them.** Which employers are named, which numbers are
   cited, which clients are excluded, how salary is answered: all theirs.
6. **Honesty on forms is absolute.** The applier declines diversity questions, never answers
   identity questions, never takes assessments, never claims what the proof list does not hold.
7. **A new user changes nothing in the engine.** If onboarding needs an engine change, that is an
   engine bug, fixed in `applier/` for everyone and logged in `CHANGELOG.md`.

## 1. Fit check (before anything is built)

Ten minutes, by message. The applier is not for everyone. Stop here if any answer is no.

| Question to the user | Why it matters | No means |
| :-- | :-- | :-- |
| Do you have a current CV (any format) and are you willing to let it set the limits of what we claim? | The proof list comes from the CV | Stop: write the CV first |
| Can you name one or two kinds of role you want, in plain words? | Role families are the targeting | Stop: a career conversation first (`apply-job-search-career`), not an applier |
| Is there at least one country or arrangement where you can legally be hired or contracted? | G1 eligibility | Stop |
| Will you spend ten minutes a day on the ASK items (interview invites, questions we cannot answer)? | The system escalates to a human; an unread escalation is a lost interview | Stop, or agree a slower cadence |
| Will you sign in to LinkedIn, the job boards and your email on the browser the applier uses? | Logins are the user's | Stop |
| Do you own, or can you create, a free Supabase account? | One project per user | Stop |

Record the answers in `users/<slug>/onboarding-record.md` §1.

## 2. The stages

Each stage has an owner, a gate (what must be true before the next stage) and a done-when. The
onboarding record is updated at every stage; the user's README carries the status line.

### Stage A: intake interview (user + Cowork, 60 to 90 minutes)

Cowork runs **prompt 0, Onboarding interview** (`COWORK-TASK-PROMPTS.md`). The questions, in order,
and what each feeds:

| # | Ask, in plain words | Feeds |
| :-- | :-- | :-- |
| 1 | Your full name as it appears on your CV. The email you want on applications. Do you want your phone number on forms? Your city and country. Your time zone. Your LinkedIn URL. | profile §1 |
| 2 | Which countries can you legally work in, and how (citizen, resident, visa type)? Anywhere else, is "remote contractor" acceptable to you? Will you ever need visa sponsorship? | profile §2; answer bank A |
| 3 | Remote only, or hybrid or on-site somewhere? Which city? | profile §2 |
| 4 | In plain words, the two or three kinds of job you want, most wanted first. For each: what would you be doing all day? What must the job include? What must it not include? | profile §3 |
| 5 | What level are you at: junior, mid, senior, lead? If lead, how many people have you actually led? | profile §3 seniority |
| 6 | What requirements make a job a definite no for you (a skill you do not have, a location, a language, a degree, shifts, travel, commission only)? | profile §3 exclusions |
| 7 | Your minimum salary, with currency and per month or year. When a form asks for expected salary, what do you want us to say? | profile §5; answer bank A |
| 8 | Your notice period and earliest start. Full-time only, or part-time and contract too? | profile §5 |
| 9 | Your current employer, if any, and its clients you know of. Any former employer or company you never want to apply to. Any keywords that mean "no" (e.g. "call centre"). | profile §7; do_not_apply |
| 10 | Which past employers may we name? Which numbers from your CV may we cite, and are they yours to cite? | profile §4 permissions |
| 11 | Languages and level. Education as on the CV. | profile §4 |
| 12 | In your own words, three to five sentences each: why you want your first-choice kind of role; the one piece of work you are proudest of; the tools you have actually used. | answer bank B; the voice sample for `ANSWER-AND-COPY-RULES.md` |
| 13 | Which job boards and sites have you used before? Which ones have an account? | profile §8 |
| 14 | How many applications a day feels right, and on which days? When is your browser on? | profile §9; the schedule |
| 15 | Anything that must never be said or sent on your behalf? | profile §4 "never claim"; answer bank D |

Cowork writes the answers into `users/<slug>/candidate-profile.md` and `answer-bank.md`, in the
user's words, labelled `[sourced: user, <date>]`, and lists every field still blank.

**Gate A:** identity, right to work, at least one role family, the salary floor and the do-not-apply
list are filled. **Done when** the user has read the two files and corrected them once.

### Stage B: CV intake (Cowork, 30 minutes; user confirms)

1. The user puts every CV they use in `users/<slug>/cv/` (or names a folder). One CV is fine.
   **No CV, or one that reads as a list of duties:** build one with `cv-generator/SKILL.md` from
   the interview's facts (a claim sheet the user confirms line by line), one position per role
   family only if the user wants it, all under one external file name. About an hour more.
2. Cowork reads each CV and writes the **proof list** (profile §4): one fact per line, as the CV
   states it, with the file as source. Employers, dates, titles, team sizes, numbers, tools, degrees.
3. Cowork compares the CVs: a number or date that differs between them is listed as a
   contradiction for the user to settle. Only one set goes in the proof list.
4. Cowork proposes the **CV routing** (profile §6): which CV for which role family, by the
   responsibilities each CV leads with; a default; one external file name for all.
5. The user confirms the proof list and the routing.

**Gate B:** the proof list has no contradiction left and a default CV is set. **Done when** every
CV has a routing row and the external label is chosen.

### Stage C: answer bank bootstrap (Cowork drafts; user edits, 30 minutes)

1. Standard rows (answer bank A) filled from the profile.
2. Role-family answers (B) drafted from the interview's voice sample and the proof list, in the
   user's register (`ANSWER-AND-COPY-RULES.md`). The user edits each until it sounds like them.
3. "Never answer" (D) read aloud to the user and confirmed.
4. The user adds any question they have met before on forms, with their answer.

**Gate C:** every standard row has an answer or a documented "leave blank". **Done when** the user
has edited the B rows in their own words.

### Stage D: search design (Cowork with the user logged in, 45 minutes)

1. From the role families, Cowork proposes five to eight saved searches across the platforms the
   user named: titles and synonyms, remote or location filters, date filter "past 24 hours", and a
   hiring-posts search on LinkedIn.
2. With the user signed in, each search is run once. Cowork records the URL the platform gives, and
   how many of the first 20 results pass the gates on sight. A search under 5 of 20 is reworked
   or dropped.
3. **Supply estimate (G2):** the sum of expected qualified listings per day across searches. If it
   is under the user's daily target, the target is lowered to the estimate and the user is told. A
   target the supply cannot feed is a design error, not an applier failure.

**Gate D:** at least three searches with 5 or more of 20 passing on sight; a daily target the
supply supports. **Done when** the rows are in profile §8.

### Stage E: infrastructure (user and operator, 30 minutes)

| Step | Who |
| :-- | :-- |
| Create a free Supabase project in the user's own account, in a region near them | user |
| Run `schema/00_job_applier_schema.sql`, then `schema/audit.sql` (every row PASS), `schema/smoke_test.sql` (PASS), `schema/01_seed_standard_answers.sql`. (A project that already holds the original v1 tracker takes the upgrade path in `schema/README.md` instead) | operator, from the user's account (SQL editor); never from any other account |
| Connect Cowork to that project (the connector's authorisation is the user's). Connect Claude in Chrome. Give Cowork read access to `users/<slug>/` and the CV folder | user |
| Sign in on that browser to LinkedIn, each job board, email, and any ATS with an existing account | user |
| Confirm the private bucket `job-hunt-artifacts` exists with no public policies (audit checks 19 and 20) | operator |

**Gate E:** audit and smoke test PASS; Cowork lists the connector; the browser shows the sites
signed in.

### Stage F: load and approve the scopes (Cowork, then the user, 20 minutes)

Cowork runs **prompt 1, Setup**: loads the profile, answer bank, routing, do-not-apply and searches
into Supabase; uploads the CVs to the bucket; reads everything back as tables. The user reads the
tables and says, for each scope, "approve <scope>: <own words>". Six live rows in
`workflow_approvals`.

**Gate F:** six scope approvals; `candidate_profiles.approved_at` set; every answer bank row
`approved = true`.

### Stage G: supervised test batch (Cowork with the user present, half a day)

Cowork runs **prompt 2, Test batch**: 20 applications, each shown before submission with every
answer and its source. The user says go, corrects, or skips. Corrections become answer-bank rows.
Hard blocks are shown as they occur so the user sees what the applier refuses to do.

What the batch is for: catching a wrong standard answer before it goes out 40 times; growing the
answer bank with the real questions these platforms ask; showing the user the evidence trail.

**Gate G:** 20 submissions with evidence; the pending answer-bank rows approved or deleted by the
user; no open `block` escalation the user has not seen.

### Stage H: workflow approval and go-live (user, 10 minutes)

The user writes: "approve daily_run_workflow, based on test batch run <id>: <own words>". Cowork
writes the row. The daily run and the weekly review are scheduled in the user's Cowork (prompts 3
and 4), on the days and at the time from profile §9, when the browser is on and idle.

**Gate H:** the live `daily_run_workflow` row; two scheduled tasks.

### Stage I: the first two weeks (user, ten minutes a day)

- The user reads each daily summary and answers the ASK items the same day. An interview invite
  gets a reply approved within 24 hours.
- Every unanswerable question that comes back goes into the answer bank; the bank is re-approved
  (the next five submissions are supervised automatically).
- The weekly review runs twice. The second one reads the kill line (`SYSTEM-DESIGN.md` §5) if 300
  submissions are reached, otherwise at the date set at onboarding (two weeks from go-live).
- Hand check: the user opens five of their own applications' evidence and confirms the CV and the
  answers.

**Done when** two weekly reviews exist, the kill line has been read once, and the user has said in
writing that the summaries are usable. Onboarding closes; the user's README moves to "live".

## 3. Definition of done (the whole onboarding)

- `users/<slug>/` holds the README (status "live", engine version, dates), the profile, the answer
  bank, the onboarding record, and the CV folder or its path.
- The user's Supabase project passes both audits and holds six scope approvals plus the live
  workflow approval, with the user's own words in each.
- A `test_batch` run with 20 evidenced submissions, and at least ten daily runs.
- The user has answered an ASK item and approved an answer-bank addition at least once.
- No secret anywhere; the operator holds no access the user did not grant and cannot revoke.

## 4. What blocks go-live (no exceptions)

- Any `[operator]` or blank in: identity, right to work, salary floor, do-not-apply.
- A contradiction in the proof list.
- A failed audit row.
- Fewer than three working searches.
- A test batch under 20, or with an unread `block` escalation.
- Approvals written by anyone but the user.

## 5. Steady state after onboarding

| Rhythm | What | Who |
| :-- | :-- | :-- |
| Daily | Summary read; ASK items answered; approved replies and drafts sent by the next run | user (10 min) |
| Weekly | Review read; answer-bank additions approved; one change at most | user (20 min) |
| On any profile or bank change | Re-approve the scope; five supervised submissions | user + Cowork |
| Monthly | Kill-line re-read on the own baseline; searches pruned; CVs refreshed if the user's situation changed | user + operator |
| On a hire or a pause | Offboarding (§6) or pause (set every search to `paused`, unschedule the daily run) | user |

## 6. Offboarding

When the user is hired, stops, or asks:

1. Unschedule the daily run and the weekly review.
2. Export: the pipeline view, the applications with evidence paths, and the answer bank, as files
   the user keeps (`users/<slug>/export-<date>/`). The user owns the record of where they applied.
3. Delete: the Supabase project (or the user keeps it; their choice), the bucket's contents, and
   `users/<slug>/` from the operator's workspace once the user has the export.
4. Revoke: the Cowork connector and the operator's access to the user's Supabase account.
5. Nothing of the user remains with the operator except the onboarding record's engine lessons,
   with every personal fact removed.

## 7. Onboarding timeline (typical, `[assumed]`)

| Day | Stages | User's time |
| :-- | :-- | :-- |
| 1 | Fit check; A intake interview; B CV intake | 90 min |
| 2 | C answer bank; D search design | 75 min |
| 3 | E infrastructure; F load and approve | 40 min |
| 4 | G supervised test batch | half a day present |
| 5 | H workflow approval; go-live | 10 min |
| 6 to 19 | I first two weeks; two weekly reviews; kill-line read | 10 min a day |

## 8. Lessons to carry back into the engine

Every onboarding ends with one section in the record: what a stage needed that the plan did not
say; which questions the forms asked that the template's answer bank lacked; which hard block
fired unexpectedly. Those go to `CHANGELOG.md` as engine changes, never as user-specific patches.

*Provenance: stage gates and the done-when tests are design `[assumed]` on 2026-11-06, untested on a
real second user; the interview questions map one to one onto the profile and answer-bank templates.*
