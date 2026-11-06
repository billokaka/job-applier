# cv-generator/

The CV builder the applier uses at onboarding stage B. It turns a confirmed claim sheet (the
user's own facts, in JSON) into a single-column, ATS-readable PDF, validates it, and refuses to
render anything the user has not confirmed.

| File | What |
| :-- | :-- |
| `SKILL.md` | The skill: integrity contract, where it sits in the applier, the five-step workflow |
| `references/data-schema.md` | The claim-sheet JSON schema, with a minimal example |
| `scripts/cv_pdf_builder.py` | The builder: validate, render, inspect, report |

**When it runs.** Stage B of `../ONBOARDING-PLAN.md`: a user with no CV, a CV that reads as a list
of duties, or a wish for one position per role family. Also later, when the user's situation
changes.

**Requirements.** Python 3.9 or later; `pip install reportlab pypdf`. For the visual check, any
way to render PDF pages to images (Poppler's `pdftoppm` or a viewer's export).

**Rules that never bend.** No fact the user did not confirm. One external file name for every
position ("my CV"). The claim sheet and the PDF live in `users/<slug>/cv/`, which is git-ignored,
and nowhere else.

To use it as a Claude Code skill on its own, copy this folder to `.claude/skills/cv-generator/`.
