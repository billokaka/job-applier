---
name: cv-generator
description: >
  Create, render, and validate single-column ATS-readable PDF CVs from
  user-supplied career facts and a target role. Use when the user asks to build,
  tailor, format, optimize, or export a CV or resume as PDF, and at stage B of
  the applier's onboarding when a user has no CV, a weak one, or needs one CV
  position per role family. Record candidate confirmation status for
  achievements and metrics, enforce page budgets, ASCII-safe punctuation,
  embedded Unicode fonts, clean text extraction, and visual PDF review. Never
  invent missing employers, dates, responsibilities, outcomes, or numbers; turn
  unknowns into questions or omit them.
---

# CV Generator

Produce a polished CV from candidate-supplied career facts. Treat the input JSON
as a claim sheet: direct confirmation from the candidate is sufficient, and the
builder enforces structure, page count, language checks, and PDF extractability.
Do not demand external records, screenshots, or analytics unless the user asks
for an independent evidence audit.

## Integrity contract

1. Never invent or "calculate realistically" an achievement, metric, employer,
   date, credential, tool, or responsibility.
2. Treat a claim supplied or explicitly confirmed by the candidate as
   `user-confirmed`; external documentation is not required.
3. Do not turn an industry benchmark into the candidate's result. Include a
   comparison only when the candidate supplies or approves the wording.
4. Treat named frameworks as the candidate's declared working methods, not as
   proven predictors of CV performance.
5. Mark legacy or unconfirmed data `legacy-unverified`. It may be rendered only
   with `--allow-unverified`, which places a visible draft warning in the PDF.
6. Keep private input and generated files out of release packages and public
   version control. Tell the user where sensitive artifacts were written.
7. When redesigning an existing CV, preserve every source fact unless the user
   explicitly asks to omit or correct it. A layout change is not permission to
   delete a claim, infer a missing detail, or rewrite the candidate's history.

## Where this sits in the applier

This skill **produces the document.** It does not decide positioning.

- **The claim sheet and the profile are the same facts.** Everything in a claim
  sheet must also be in, or go into, the user's `candidate-profile.md` §4 (the
  proof list). The applier may only state what the proof list holds, so a fact
  on the CV that is not on the proof list is a fact the applier will never
  mention, and a fact on the proof list that the CV contradicts is a
  contradiction stage B must settle.
- **One CV position per role family, when the user wants it.** A position is a
  different emphasis of the same facts (which roles lead, which bullets come
  first, which title line), never different facts. Each position is an
  `artifacts` row and a `cv_routing_rules` row. **Externally there is only ever
  "my CV":** every position is sent under the same external file name
  (`external_label`), and no message or form ever says that variants exist.
- **Positioning first.** If the user does not yet know which kinds of role they
  want, run the onboarding interview (prompt 0) before generating anything; a
  CV built before the role families are settled is a list of duties.
- **The register** follows `../ANSWER-AND-COPY-RULES.md` §5: plain words, short
  sentences, no superlatives about the person, the banned words out.

## Workflow

### 1. Establish the claim sheet

Collect:

- target role family and industry;
- name, titles, location, contact links (only what the user wants disclosed);
- employment history and education;
- responsibilities and outcomes;
- metrics plus the denominator or time period when needed to prevent ambiguity;
- the page budget: one page by default for early-career profiles, two pages only
  when role breadth or seniority genuinely needs it;
- a theme and compact, standard, or relaxed layout density.

When facts are incomplete, ask concise questions or omit the claim. Do not fill
gaps with model knowledge. Candidate attestation is enough for
`user-confirmed`; do not pause the CV workflow to request external proof.
Do not infer language proficiency when the source lists only language names.

Read `references/data-schema.md` before creating or editing the JSON. Set the
top-level status after the user confirms the claim sheet or revised claim set:

- `user-confirmed`
- `source-backed`
- `legacy-unverified`

For a reference-CV redesign (the user already has a CV):

1. Render every source page and extract its text.
2. Build a fact inventory covering contact details, titles, summary claims,
   metrics, every role and date, named clients or products, responsibilities,
   tools, education, languages, and portfolio or project details.
3. Separate presentation changes from factual changes. Colors, hierarchy,
   spacing, section order, page breaks, and removal of decorative metric boxes
   are presentation changes. Deleting the metric itself, changing a date, or
   altering scope is a factual change.
4. Mark the claim sheet `source-backed` when the source is user-provided and
   described in `evidence.notes`; record any user-attested verification there.
5. Reconcile the final extracted PDF against the inventory before delivery.

### 2. Write for selection relevance

- Lead with role-relevant proof, not generic personality claims.
- Use compact result-action-context bullets.
- Preserve the candidate's actual scope. Do not upgrade "contributed to" into
  "led" or "owned."
- Prefer direct verbs and concrete nouns.
- Avoid `synergize`, `leverage`, `utilize`, and `results-driven`.
- Use ASCII hyphens, pipes, and bullet markers. The builder normalizes Unicode
  dashes and display punctuation before rendering.
- When shortening or reorganizing a reference CV, remove duplication rather
  than facts. If a decorative metric block is removed, retain its verified claim
  in the summary or relevant experience.

### 3. Build

The standalone builder is bundled at `scripts/cv_pdf_builder.py`. It needs
Python 3.9 or later with `reportlab` and `pypdf` (`pip install reportlab pypdf`).

```powershell
python scripts/cv_pdf_builder.py `
  --data <claim-sheet.json> `
  --output <candidate-role-cv.pdf> `
  --report <candidate-role-cv.validation.json>
```

Use `--allow-unverified` only for an internal draft. Never present a draft as a
production-ready CV.

The builder:

- validates the schema and evidence status;
- rejects banned language;
- escapes all user content before ReportLab markup;
- uses embedded Vera TrueType fonts with Unicode maps;
- avoids layout tables and Symbol-font bullets;
- keeps section headings with their first content and roles together where they
  fit;
- supports compact density for source-heavy two-page CVs without forcing tiny
  type;
- renders a language name by itself when no proficiency level was supplied;
- enforces the requested one- or two-page budget;
- reopens the PDF and checks extracted text for control-character corruption;
- writes a machine-readable validation report.

### 4. Render and inspect

Automated extraction is not visual QA. Render every final page to PNG (Poppler's
`pdftoppm`, or any PDF viewer's export), inspect it, and regenerate until there
are:

- no orphaned section headings;
- no clipped text or collisions;
- no page beginning with an unexplained continuation bullet;
- balanced page use and readable type;
- no avoidable half-empty page when a natural role boundary can rebalance the
  document;
- consistent headers, spacing, and footer numbering.

### 5. Deliver

Deliver the PDF and validation report together. State:

- candidate-confirmation status;
- page count versus budget;
- whether the PDF was visually inspected;
- whether a reference-CV fact reconciliation was completed;
- any facts the candidate asked to omit.

Save the PDF to `users/<slug>/cv/` and the claim sheet beside it (both are
git-ignored). Then create the `artifacts` row and the `cv_routing_rules` row
through the setup prompt, and add every fact the CV carries to the proof list.
Do not package the claim sheet anywhere else.
