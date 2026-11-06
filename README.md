# The job applier

A job search that runs itself, for one person, with honesty built in.

You sign in to your job sites once, answer an interview about yourself once, and approve what
the system may say about you. After that, Claude finds new openings every day from your saved
searches, checks each one against your rules, applies to the ones that fit (about 40 a day), fills
the forms from your approved answers, sweeps your inbox for replies, keeps a full record in your
own private database, and sends you one short summary with the few things only you can decide.

It never invents a fact about you. It never answers an identity question, takes a test, records a
video, passes a captcha, accepts terms, or messages a person without your approval of that exact
message. If it cannot answer a required question from your approved facts, it holds that
application and asks you.

**Version:** 2.3 (`CHANGELOG.md`). **Status:** fully specified; the database scripts have not yet
been run against a live Postgres by the author, so the first user's setup is the first live test.
The smoke test in `schema/` exists to catch that.

## What you need

| Need | Why |
| :-- | :-- |
| **Claude Cowork** (or Claude Code) with the **Claude in Chrome** extension | It runs the daily task and drives the browser |
| A free **Supabase** account of your own | Your private database: profile, answers, every application, every reply. Nobody else's project, ever |
| A browser signed in to LinkedIn, your job boards and your email | The applier uses your sessions; it never stores a password |
| Your CV, or an hour to build one | The proof list comes from it. `cv-generator/` builds one if you have none |
| Ten minutes a day | To read the summary and answer the ASK items (interview invites, questions with no answer yet) |
| Optionally Python 3.9+ | Only for the CV builder |

## Quick start

1. Clone or download this folder. Open it in Claude Cowork or Claude Code.
2. Say: **"Onboard me."** Claude reads `CLAUDE.md`, runs the fit check and the 15-question
   interview, and builds your private `users/<you>/` folder from your answers.
3. Follow `ONBOARDING-PLAN.md` with Claude: your CV and proof list, your answer bank, your saved
   searches, the Supabase project (`schema/`), a supervised batch of 20 applications you watch,
   then your approval of the daily run.
4. Schedule the daily run and the weekly review (prompts 3 and 4 in `COWORK-TASK-PROMPTS.md`).
5. Read the summary each day. The kill line in `SYSTEM-DESIGN.md` §5 tells you when to stop and
   rethink, so you never apply into silence for months.

About five days from start to live, with two to three hours of your own time in total.

## How it stays honest

- **Your facts only.** The profile's proof list and the answer bank are the only sources. Every
  answer on every form is logged with its source. A truth check runs before every submission.
- **You approve, in your own words.** Each part of your setup, then a batch of 20 applications
  shown to you one by one, then the daily workflow. Any change to your facts sends the next five
  applications back to you.
- **Hard blocks.** The list in `SYSTEM-DESIGN.md` §6 stops a row no matter what mode the run is in.
- **No secrets, nowhere.** Not in files, not in prompts, not in the database. Check 21 of the
  schema audit makes sure there is no column that could hold one.
- **Your data is yours.** One Supabase project in your account; you can revoke access in a click.
  Offboarding exports everything to you and deletes the rest.

## The files

| File | What it is | Read it when |
| :-- | :-- | :-- |
| `CLAUDE.md` | How Claude behaves in this folder | Claude reads it first |
| `SYSTEM-DESIGN.md` | What the applier is and is not; the gates; the three tiers; the approval model; the hard blocks; the kill line | Once, to understand it |
| `ONBOARDING-PLAN.md` | A new user from fit check to live: nine stages with gates, the interview, go-live blocks, steady state, offboarding | Before onboarding |
| `COWORK-TASK-PROMPTS.md` | Paste-ready prompts: onboarding interview, setup, test batch, daily run, weekly review, re-test, offboarding | When scheduling or running |
| `DAILY-RUN-FLOW.md` | The run, step 0 to 8, and the weekly review | Every run |
| `ANSWER-AND-COPY-RULES.md` | How a question is answered, derived, declined or escalated; the truth check; the register; cover letters | Every run |
| `PACKET-FLOW.md` | The depth treatment for the best fits: research, up to three people, messages you approve one by one | Step 6 of a run |
| `PLATFORMS.md` | Each job platform and application system: what it asks, which tier, what stops it | Qualify and apply |
| `SETUP-CHECKLIST.md` | The short list for the infrastructure and go-live steps | Stages E to H |
| `cv-generator/` | Build an ATS-readable PDF CV from your confirmed facts | Stage B, or any time |
| `schema/` | The database: one script for a fresh project, a seed, an audit, a smoke test, the operating queries, the data model | Stage E |
| `templates/` | The profile, the answer bank, the onboarding record, the user README | Stage A |
| `users/` | Your private folder. **Git-ignored. Never commit it.** | Yours |
| `CHANGELOG.md` | Versions | On any change |

## What it does not do

It does not promise interviews. It does not apply to companies you excluded, or to the same
company twice in ninety days. It does not run while a platform is warning you. It does not take
assessments or record videos for you. It does not decide which jobs you want: that is the
interview, and you.

## Contributing

A change to anything outside `users/` is an engine change: version it in `CHANGELOG.md`. A need
that only one person has belongs in that person's files, not in the engine. Platform behaviour
you observe that differs from `PLATFORMS.md` is worth a pull request, with no personal facts in
it.

## Licence

MIT, see `LICENSE`. Use it, change it, share it. No warranty: the person applying is responsible
for what is submitted in their name, and the approval model exists so that they always know
what that is.
