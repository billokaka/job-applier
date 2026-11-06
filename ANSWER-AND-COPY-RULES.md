# Answer and copy rules

How the applier answers a form question, writes a cover letter or a message, and checks itself
before submitting. The flow (`DAILY-RUN-FLOW.md` step 5) points here. These rules are the same for
every user; the user's facts and voice come from their profile and answer bank.

## 1. The source rule

Every answer has exactly one of four sources, recorded in `question_log.resolution`:

| Source | When | What is allowed |
| :-- | :-- | :-- |
| `answered_from_bank` | The question matches an approved `answer_bank` row by pattern or by meaning | The row's answer, exactly; rewording for length or form only when `may_adapt = true` |
| `derived_from_profile` | The answer is arithmetic or selection over `facts_may_state` (years from dates, the list of employers, the tools used, the city) | The derivation written into `answer_given`, e.g. "years = 2026 minus 2019 from the CV's first sales role" |
| `left_blank_optional` | The field is optional and no source exists | Blank. Never "N/A" as a filler for a real question |
| `escalated` | The field is required and no source exists | Hold the application; escalation type `unanswerable_question`; the exact question text, so the user can add a row |

A question that matches a bank row only loosely (the same topic, a different ask) is treated as
no match. Close is not the same.

## 2. Matching a question to the bank

1. Normalise: lower-case, strip punctuation, strip the company name, collapse "you/your".
2. Try `question_patterns` for an exact or near-exact phrasing.
3. Try by meaning: the question asks for the same fact as a row's `question_key` (right to work,
   salary, notice, years, why this role, why us, achievement, tools, how heard, consents).
4. Choice fields: pick the first option in `answer_choices_preferred` that the form offers; if none
   is offered, escalate (the form's options may encode something the user has to decide).
5. Scoped rows beat global rows: `company` scope, then `platform`, then `role_family`, then `global`.

## 3. Derivation rules (what counts as derivable)

Derivable from the proof list without asking:

- years of experience in total or in a role family, from the CV's dates (round down);
- the most recent employer, title and dates;
- the list of tools, when the CV names them;
- the highest qualification, when the CV names it;
- the city and country;
- whether a stated requirement is met, when the proof list states it plainly (for example "3+
  years in outbound sales" against dated outbound roles).

Not derivable, always escalated or declined:

- a skill level the CV does not state ("expert in X");
- a number the CV does not carry (quota attainment, revenue, team size);
- a willingness or preference the profile does not state (travel, shifts, relocation to a new city);
- anything about health, family, age, nationality beyond right to work, criminal record, credit;
- a reference's name or contact details.

## 4. The truth check before submit

Before any submission, in both modes, the run re-reads every answer it is about to send and
checks each against the source rule. One failure holds the application. The check is written to
`applications.notes` as "truth check: n answers, n from bank, n derived, n blank, 0 unsourced".
This is the step that makes autonomy safe; it is never skipped for speed.

## 5. The register

Everything written for a user sounds like that user, not like a template:

- The voice sample from the onboarding interview (three to five sentences in the user's words)
  sets the register: sentence length, formality, the words they use for their own work.
- Short sentences. Plain words. No idioms a non-native reader would not know. Commas sparingly.
  No em dashes.
- No superlatives about the user ("exceptional", "passionate", "results-driven"). Facts and what
  they did.
- Banned: unlock, unleash, transform, revolutionize, synergy, game-changer, comprehensive,
  facilitate, optimize, utilization, cutting-edge, robust, streamline, leverage, orchestrate,
  "I hope this finds you well", "I wanted to reach out", "just checking in".
- Externally the CV is "my CV". Never "my sales CV" or "the version for this role".

## 6. "Why us" and "why this role"

- "Why this role": the user's approved role-family answer, adapted to the posting's words for the
  work, never to claims the posting makes about itself.
- "Why us": one true, specific thing from the posting or the company's own site (what they sell,
  to whom, a stated problem), in one sentence; then one sentence of fit from the proof list. No
  praise, no "I have always admired". If nothing specific can be found in five minutes, the answer
  is the role-family answer alone, and `question_log` notes "no company-specific fact found".

## 7. Cover letters

Only when the form asks. Four short paragraphs, under 220 words:

1. The role and where it was seen. One line.
2. One real thing about the company (as in §6).
3. The relevant scope of the user's experience, from the proof list, matched to the posting's
   responsibilities. Two to four sentences. No fact outside the list.
4. A plain close: availability, "my CV is attached", "happy to talk whenever suits you".

Stored in `applications.cover_letter_text`. In supervised mode it is shown; in workflow-approved
mode it goes, because its every fact passed the truth check.

## 8. Messages to people (the packet tier)

Governed by `PACKET-FLOW.md` §3 to §5. Every message is approved one by one by the user, whatever
the mode. The register rules above apply. Recipient and channel change the message; no copy is
reused across the three contacts.

## 9. Declines and consents (fixed, every user)

- Diversity, gender, ethnicity, disability, veteran status: "Prefer not to say" or the form's
  equivalent. Never an answer, even if the user would give one in person.
- "Are you over 18": yes, when the profile's facts make it true.
- Data-processing consent for this application: yes. Marketing or talent-pool consent: no, unless
  the user's answer bank says otherwise.
- Terms, agreements or NDAs inside a form: not accepted; hold and escalate.

## 10. Length and form limits

- Respect the field's maximum; shorten by cutting sentences, never by abbreviating facts.
- Numbers as digits. Dates in the form's own format.
- No links in answers unless the field asks for one.
- Attachments: the routed CV only, named with the external label. No extra documents unless the
  user's answer bank lists one as `approved_to_share`.
