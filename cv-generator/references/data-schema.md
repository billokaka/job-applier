# CV claim-sheet schema

## Contents

1. Candidate-confirmation status
2. Required fields
3. Optional sections
4. Minimal example
5. Reference-CV redesign inventory
6. Pre-build review

## 1. Candidate-confirmation status

The top-level `evidence` object applies to every candidate-specific factual claim
in the file.

```json
{
  "evidence": {
    "status": "user-confirmed",
    "confirmed_by": "candidate",
    "confirmed_on": "2026-07-30",
    "notes": "Candidate reviewed the complete claim sheet."
  }
}
```

Allowed statuses:

- `user-confirmed`: the candidate supplied or confirmed the claim sheet.
- `source-backed`: the claims are supported by user-provided records; describe
  the records in `notes`.
- `legacy-unverified`: historical or demonstration data that has not been
  confirmed. The builder refuses it unless `--allow-unverified` is passed and
  then marks the PDF as a draft.

Direct candidate confirmation is sufficient for `user-confirmed`; external
documentation is not required. Never promote a model-generated guess to a
candidate-confirmed claim.

## 2. Required fields

| Field | Type | Rule |
| :-- | :-- | :-- |
| `schema_version` | integer | Must be `1` |
| `evidence` | object | Must contain an allowed `status` |
| `page_budget` | integer | `1` or `2`; the builder fails on overflow |
| `name` | string | Candidate's supplied name |
| `theme` | string | `navy_teal`, `charcoal_gold`, `tech_slate`, `minimal_monochrome`, or `clean_blue` |
| `layout_density` | string | Optional: `compact`, `standard` (default), or `relaxed` |
| `titles` | array of strings | One to three target-relevant titles |
| `contact` | array of strings | Only contact details the user wants disclosed |
| `summary` | string | Factual positioning paragraph |
| `experience` | array of objects | At least one role |

Each experience object accepts:

- `role`
- `company`
- `location`
- `dates`
- `context`
- `key_metrics` as an array of strings
- `execution` as an array of strings
- optional `page_break_before: true` when a reviewed two-page layout needs the
  role to begin on the second page

The status covers metrics embedded anywhere in these fields. A candidate's
direct attestation is sufficient. Leave genuinely unknown or model-generated
content out of a production claim sheet.

## 3. Optional sections

- `metric_pills`: up to four `{ "metric": "...", "label": "..." }` objects.
- `systems`: `{ "title": "...", "description": "..." }` objects.
- `methodologies`: `{ "name": "...", "description": "..." }` objects. Describe
  only methods the candidate says they actually use; do not claim the framework
  is scientifically validated.
- `tech_stack`: object mapping category names to arrays of tools.
- `competencies`: array of strings.
- `education`: `{ "degree": "...", "institution": "...", "year": "..." }`.
- `languages`: `{ "name": "...", "level": "..." }`. `level` is optional; leave
  it blank when the source gives no proficiency, and the builder renders only
  the language name.

## 4. Minimal example

```json
{
  "schema_version": 1,
  "evidence": {
    "status": "user-confirmed",
    "confirmed_by": "candidate",
    "confirmed_on": "2026-07-30",
    "notes": "Candidate reviewed every claim."
  },
  "page_budget": 1,
  "name": "FULL NAME",
  "theme": "navy_teal",
  "titles": ["Target Role"],
  "contact": ["City, Country", "email@example.com", "linkedin.com/in/example"],
  "metric_pills": [
    {"metric": "25%", "label": "Cycle Time Reduced"}
  ],
  "summary": "Role-relevant summary using candidate-supplied facts.",
  "experience": [
    {
      "role": "Role",
      "company": "Company",
      "location": "Location",
      "dates": "2024 - Present",
      "context": "Confirmed scope and operating context.",
      "key_metrics": ["Reduced a measured cycle time by 25% through a documented workflow change."],
      "execution": ["Built and maintained the workflow with the stated team."]
    }
  ],
  "systems": [],
  "methodologies": [],
  "tech_stack": {},
  "competencies": [],
  "education": [],
  "languages": []
}
```

## 5. Reference-CV redesign inventory

Before redesigning an existing CV, inventory every source fact:

- name, titles, contact details, and portfolio links;
- summary claims and every metric;
- every role, employer, location, date, responsibility, named client, product,
  project, and outcome;
- tools, competencies, education, credentials, and languages.

Record presentation-only decisions separately, such as theme, section order,
metric-box removal, density, and page breaks. Reconcile the final PDF's extracted
text against the inventory. Do not treat a visual redesign as permission to omit
or alter candidate facts.

## 6. Pre-build review

Before setting `user-confirmed` or `source-backed`, review the claim sheet with
the candidate:

- employer names, titles, dates, and locations;
- ownership verbs such as led, owned, architected, and generated;
- every number, percentage, currency amount, comparison, and time saving;
- education and credentials;
- tools and frameworks;
- contact details intended for disclosure;
- page budget and target role.
