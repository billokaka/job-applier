# Platforms and application systems

What the run should expect from each place it applies, which tier it usually falls in, and what
stops it. **Provenance:** general knowledge of these systems as of 2026, `[assumed]` until the
user's supervised test batch confirms each one; the batch's findings go into the user's onboarding
record and, when general, into this file through `CHANGELOG.md`. Nothing here is a ranking claim
or a promise about any platform's behaviour.

## Discovery platforms

| Platform | How the run searches | Notes |
| :-- | :-- | :-- |
| LinkedIn Jobs | The user's saved-search URL (keywords, location, remote filter, date filter); sort by most recent | The apply button leads either to Easy Apply (quick tier) or to the employer's own system (full tier). Hiring posts are a separate search over posts |
| LinkedIn posts | A post search on hiring phrases plus the role words, past 24 hours | A post is a `feed_post` sighting; the apply route is whatever the post names (often an email or a form) |
| Indeed | Search URL with query, location, date and remote filters | "Apply on company site" leads to the ATS; Indeed's own quick apply is quick tier. Indeed may interpose skills tests: hard block |
| Wellfound | Role and location filters; the user's profile must be complete on the site | Applications are mostly one page with a short note: quick or full depending on questions |
| Company career pages | A saved search per company page the user cares about, weekly | Usually an ATS underneath (see below) |
| Other boards (regional, niche) | Whatever the board offers; recorded as `platform = other` with the board name in `filters` | Many redirect to email applications: the run drafts the email as a `messages`-style ASK item, never sends it unapproved |

## Application systems (ATS)

| System | What the form usually asks | Tier | Known blockers |
| :-- | :-- | :-- | :-- |
| LinkedIn Easy Apply | Contact details, CV upload, a few screening questions (years, right to work, salary), sometimes a short text | quick | Screening questions are often required choice fields: the bank must hold them. Daily volume may be limited by the platform |
| Greenhouse | Name, email, phone, CV, LinkedIn, custom questions, EEO section | full | Custom questions vary widely; cover letter sometimes required |
| Lever | Name, email, phone, CV, LinkedIn, "additional information" box, custom cards | full | Often a single page; cover letter in the free-text box |
| Workable | Name, email, phone, CV, summary, a few custom questions, sometimes a video prompt | full | Video or assessment prompts: hard block |
| Ashby | Similar to Greenhouse; custom question sets | full | Custom questions; some require account creation |
| Workday | Account creation per employer, multi-page: contact, experience re-entry, education, questions, EEO, sometimes voluntary disclosures | full | Re-entering the CV into fields page by page is slow; the 15-minute budget may hold it. Account per employer: the browser's password manager keeps the password. Self-identification pages: decline |
| SmartRecruiters, Teamtailor, Recruitee, BambooHR, JazzHR, iCIMS, Taleo | One to three pages; CV plus custom questions | full | Taleo and iCIMS often need accounts and are slow; same rules |
| Email applications | The posting gives an address | drafted as an ASK item | Never sent without the user's approval; it is a message, not a form |

## What every platform gets

- The CV chosen by `cv_routing_rules`, uploaded under the external label.
- Standard fields from the answer bank; EEO and diversity sections declined; data-processing
  consent for this application only; marketing consent off.
- One account per platform, under the applicant email; the password lives in the browser only.
- A confirmation captured before `submitted` is set: the confirmation page, the application id, or
  the confirmation email.
- Natural pace: one application in flight, one tab per platform, the platform's own navigation.

## What stops a platform for the day

A warning about unusual activity, a rate limit, a lock, a verification code or a captcha. The run
records a `platform_restriction` escalation at severity `block`, finishes the application in flight
only if it is one click from confirmation, and does not open that platform again until the next
run. The user decides whether anything else is needed.

## Updating this file

A platform that behaves differently from the table is an engine finding: note it in the user's
onboarding record (with no personal facts), then change this file and `CHANGELOG.md`.
