# Candidate profile: <full name>

The only source of facts about the candidate that the applier may use. Fill it in the candidate's
own words. A blank is honest; a guess is poison. Label facts `[sourced: candidate, <date>]` or
`[observed: CV, <file>]`. The setup prompt loads this file into `candidate_profiles`,
`cv_routing_rules`, `do_not_apply` and `saved_searches`.

## 1. Identity (what forms ask first)

| Field | Value |
| :-- | :-- |
| Full name (as on the CV) | |
| Headline (one line, as on LinkedIn) | |
| Applicant email (the one used on every application) | |
| Phone on forms? (`yes <number>` or `no`) | |
| Location (city, country) | |
| Time zone | |
| LinkedIn URL | |
| Portfolio or website URL (optional) | |

## 2. Right to work

One row per country the candidate may work in or from. The qualify step's first gate.

| Country | Status (`citizen`, `permanent`, `visa <type>`, `remote contractor only`, `none`) | Note |
| :-- | :-- | :-- |
| | | |

Work models accepted (delete what does not apply): `remote`, `hybrid <city>`, `onsite <city>`.

## 3. Role families (what the candidate is looking for)

Ordered. The key is what the database stores; the description is what the qualify step matches
against responsibilities, never the title alone.

| Priority | Key | What the role does, in plain words | Must include | Must not include |
| :-- | :-- | :-- | :-- | :-- |
| 1 | | | | |
| 2 | | | | |

Seniority band (one line, e.g. "individual contributor, mid to senior; team lead only up to N
reports"):

Years of experience the CV supports:

Hard requirements that make a role a skip (one per line, e.g. "deep SQL", "security clearance",
"on-site in <city>", "fluent <language>"):

- 

## 4. Facts the applier may state (the proof list)

Everything the applier may put on a form, in a cover letter or in a message. If it is not here, it
is not said. One fact per line with its source.

- `[observed: CV]` 
- `[sourced: candidate]` 

Things never to claim (degrees, certifications, employers, tools, numbers the candidate does not
hold or cannot back):

- 

Languages (language, level): 

Education (institution, qualification, year):

## 5. Money, timing and availability

| Field | Value |
| :-- | :-- |
| Salary floor (amount, currency, per month or year) | |
| How to answer salary fields (e.g. "give the range X to Y", "say negotiable when optional", "never below the floor") | |
| Notice period | |
| Earliest start | |
| Hours or contract types accepted | |

## 6. CVs and routing

Every CV file the applier may send, and when. Externally there is one CV; the employer sees the
`external_label` as the file name. Rules are tried in priority order; the first match wins; the
default is used when none matches.

| Priority | Internal name | File path | Use when (role family keys or title keywords) | External label |
| :-- | :-- | :-- | :-- | :-- |
| 10 | | | | my CV |
| default | | | | my CV |

## 7. Do not apply

Companies, domains or keywords the applier must never apply to, with the reason. The current
employer and its clients always belong here.

| Scope (`company`, `domain`, `keyword`) | Pattern | Reason | Expires |
| :-- | :-- | :-- | :-- |
| | | | |

## 8. Saved searches

One row per search the daily run opens. Prefer the platform's own saved-search URL (it carries the
filters). `cadence` is `daily` or `weekly`; `cap` is the most listings read per run.

| Name | Platform | URL or query | Filters in words | Cadence | Cap |
| :-- | :-- | :-- | :-- | :-- | :-- |
| | | | | daily | 50 |

## 9. Run settings

| Setting | Value |
| :-- | :-- |
| Daily submission target | 40 |
| Quick / full split | about 30 / 8 |
| Packets per day | 2 |
| Time limit per run | 4 hours |
| Run days | weekdays |
| Summary goes to | |

## 10. Approval record

Filled by the setup prompt when the operator approves this file (scope `candidate_profile`).

| Version | Approved on | Note |
| :-- | :-- | :-- |
| | | |
