# Setup checklist (stages E to H of the onboarding plan)

The short operator list for the infrastructure and go-live steps. The full plan, with the
interview and the gates before these, is `ONBOARDING-PLAN.md`. Each step says who does it.

| # | Who | Step | Done when |
| :-- | :-- | :-- | :-- |
| 1 | User | Create a free Supabase project in your own account, in a region near you. (An existing project on the free plan may have paused: restore it) | The project shows active |
| 2 | Operator, from the user's account | In the SQL editor run `schema/00_job_applier_schema.sql`, then `schema/audit.sql`, `schema/smoke_test.sql`, `schema/01_seed_standard_answers.sql`. (An existing v1 project: the upgrade path in `schema/README.md`) | Every audit row PASS; smoke test PASS |
| 3 | User | Connect Cowork to that project (your authorisation, revocable). Connect Claude in Chrome. Give Cowork file access to this folder (the applier) and your CV folder | Cowork lists the connector and the folders |
| 4 | User | Sign in on that browser to LinkedIn, each job board in your saved searches, your email, and any ATS where you already have an account | Each site shows you signed in |
| 5 | Both | Every `[operator]` or blank in identity, right to work, salary floor and do-not-apply is filled; at least three saved searches have URLs | Plan §4 has nothing blocking |
| 6 | Claude | Prompt 1, Setup. Review the per-scope tables | Rows loaded; blanks listed |
| 7 | User | "approve <scope>: <your words>" for profile, answer bank, CV routing, fit rules, saved searches, do-not-apply | Six live rows in `workflow_approvals`; mirrored in your README |
| 8 | Claude, user present | Prompt 2, Test batch (20 supervised applications) | A `test_batch` run with evidence on every submission |
| 9 | User | Approve or delete the pending answer-bank rows; then "approve daily_run_workflow, based on test batch run <id>: <your words>" | The live `daily_run_workflow` row |
| 10 | User | Schedule prompt 3 (daily, your run days and time, browser on and idle) and prompt 4 (weekly) in Cowork | Two scheduled tasks |
| 11 | User | Read the summaries daily; answer ASK items the same day. Kill-line read at the date in your README or at 300 submissions | Two weekly reviews exist; onboarding closes |

**Never in any step:** a password, token or cookie in a file or in Supabase; anyone else's
Supabase project; a message to a person without its own approval; an approval written by anyone
but the user.
