# Changelog: the applier engine

Newest first. A version is bumped on any change to a file in `applier/` or to the schema. Each
user's README records the version they run; the re-test rule (`SYSTEM-DESIGN.md` §5) applies when
a user moves to a new version.

## 2.3 (2026-11-06)

- **Deployable as a repository root.** `CLAUDE.md` (Claude's entry file: "onboard me" routes to
  the fit check and prompt 0), a public-facing `README.md`, `LICENSE` (MIT), `.gitignore`
  (`users/`, PDFs, claim sheets, exports, any secret file pattern), `users/README.md`.
- `users/` now lives inside the engine folder and is git-ignored; prompts use `<applier>` (the
  folder's path) instead of a workspace path.
- `cv-generator/`: the CV builder skill generalised into the engine (skill, claim-sheet schema,
  PDF builder); onboarding stage B uses it for a user with no CV or a weak one.
- `CLAUDE.md` "When something breaks": how a user's own Claude repairs the schema, the platform
  notes or the flow, and logs it, without touching the hard blocks or the honesty rules.

## 2.2 (2026-11-06)

- **The engine is self-contained.** Nothing in `applier/` points outside it except the user folders.
- `schema/`: `00_job_applier_schema.sql` builds the whole database in a fresh project (22 tables,
  5 views, 4 functions, the private bucket) with no Supabase Auth dependency and no column for a
  secret; `01_seed_standard_answers.sql`; `audit.sql` (21 checks); `smoke_test.sql` (rolls back;
  checks counts, mode, re-test and the honesty constraints); `queries.sql` (the operating queries,
  including the kill-line read); `SCHEMA.md`; a README with the two paths (fresh vs upgraded v1).
- `PACKET-FLOW.md`: the depth treatment, generalised from the original campaign flow; the daily
  run and the copy rules point to it instead of an archive.
- `PLATFORMS.md`: discovery platforms and application systems, what each asks, its tier, what
  stops it; `[assumed]` until each user's test batch confirms.
- `job_hunt_duplicate_check()` for qualify gate 8; `runs.engine_version`; `messages.planned_send_at`;
  `candidate_profiles.run_settings` and `voice_sample`; `saved_searches.weekly_day` and
  `pass_on_sight_of_20`.
- Prompts and the onboarding plan use `schema/` for stage E.

## 2.1 (2026-11-06)

- The engine moved to `applier/` and users to `users/<slug>/`; nothing in the engine names a person.
- `ONBOARDING-PLAN.md`: fit check, nine stages with gates, the 15-question interview, go-live
  blocks, steady state, offboarding, timeline.
- `ANSWER-AND-COPY-RULES.md`: the source rule, matching, derivation rules, the truth check before
  submit, the register, cover letters, declines.
- `DAILY-RUN-FLOW.md`: resume after an interrupted run; a time budget per application; the truth
  check; bucket path convention; the stale-run rule.
- `COWORK-TASK-PROMPTS.md`: prompt 0 (onboarding interview) and prompt 6 (offboarding); paths
  generalised to `users/<slug>/`.
- Schema: `job_hunt_close_run(run_id)` writes a run's counts from the tables; `job_hunt_current_mode()`
  returns the mode; `ready_to_apply_queue` view; stale-run handling documented.
- Templates: `onboarding-record.md`, `user-README.md`.

## 2.0 (2026-11-06)

- First design of the autonomous applier on top of v1: candidate layer, answer bank, three tiers,
  workflow-level approval after a supervised batch, ten hard blocks, kill line, discovery with
  sightings dedupe, runs and escalations, the v2 migration and audit.

## 1.0 (2026-08-16 to 2026-09-11)

- The company-by-company campaign: eleven tables, the nine-stage flow, per-send approval. Closed on
  a hire for its first user, whose workspace keeps the original files.
