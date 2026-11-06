# schema/: the applier's database

One private Supabase project per user, in the user's own account. Two ways in:

| Situation | Run, in order | Then |
| :-- | :-- | :-- |
| **A fresh project** (every new user) | `00_job_applier_schema.sql` | `audit.sql` (every row PASS), `smoke_test.sql` (PASS, rolled back), `01_seed_standard_answers.sql` |
| **A project that already holds the v1 tracker** (the original company-by-company campaign, from this workspace's `supabase/migrations/`) | the two v1 migrations if not yet applied, then `supabase/migrations/20261106120000_job_hunt_v2_autonomous_apply.sql` | `audit.sql`, `smoke_test.sql`, `01_seed_standard_answers.sql` |

The fresh script and the v2 migration produce the same objects. Three small differences in the
fresh script, carried into the next v2 migration if the upgraded path is ever used again:
`messages.channel` says `email` (v1 said `gmail`); `messages.planned_send_at`,
`interactions.interaction_type = 'status_update'`, `candidate_profiles.linkedin_url`,
`portfolio_url`, `preferred_company_patterns`, `contract_types_accepted`, `run_settings`,
`voice_sample`, `saved_searches.weekly_day`, `pass_on_sight_of_20`, `runs.engine_version` and
`job_hunt_duplicate_check()` exist only in the fresh script; `audit.sql` checks what both have.

| File | What |
| :-- | :-- |
| `00_job_applier_schema.sql` | 22 tables, 5 views, 4 functions, 1 private bucket. No Auth dependency, RLS everywhere, no client grants, no column for a secret |
| `01_seed_standard_answers.sql` | The standard answer-bank rows (EEO declines, consents, the person-dependent ones with a note for the setup prompt). Inserted unapproved |
| `audit.sql` | 21 read-only checks |
| `smoke_test.sql` | Inserts, closes a run, checks counts, mode and the constraints that keep the applier honest; rolls back |
| `queries.sql` | The queries the run and the weekly review use, and the user can paste |
| `SCHEMA.md` | The data model, table by table, and the rules the run enforces on top |

**Never:** a password, token, cookie, identity number or key in any row; a project in anyone's
account but the user's; `anon` or `authenticated` grants on these tables.
