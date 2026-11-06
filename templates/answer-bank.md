# Answer bank: <full name>

Approved answers to the questions application forms ask. The applier uses an answer exactly as
written; `may_adapt = yes` lets it reword to the question's length and form, never add a fact. A
required question with no row here and no derivation from the profile's proof list holds the
application and comes back as a question for the candidate. Each run adds the unseen questions it
met to the "Pending" section through `question_log`; the candidate answers them here, then
re-approves the bank.

Format of a row: a stable key; the phrasings seen; the type; the answer; whether it may be
reworded; the scope (`global`, or `platform <name>`, `company <name>`, `role_family <key>`).

## A. Standard fields (every platform)

| Key | Phrasings seen | Type | Answer | Adapt | Scope |
| :-- | :-- | :-- | :-- | :-- | :-- |
| `work_authorization_<country>` | "Are you legally authorised to work in <country>?" | boolean | | no | global |
| `sponsorship_needed_<country>` | "Will you now or in the future require sponsorship?" | boolean | | no | global |
| `location_current` | "Where are you located?" | text | | no | global |
| `relocation` | "Are you willing to relocate?" | boolean | | no | global |
| `remote_preference` | "Preferred work arrangement" | choice | | no | global |
| `salary_expectation` | "Expected salary", "Desired compensation" | text | (from profile §5 policy) | yes | global |
| `notice_period` | "Notice period", "When can you start?" | text | | yes | global |
| `years_experience_total` | "Years of experience" | number | | no | global |
| `linkedin_url` | "LinkedIn profile" | url | | no | global |
| `phone` | "Phone number" | text | (profile §1 says yes or no) | no | global |
| `how_did_you_hear` | "How did you hear about this role?" | choice | prefer: the platform the listing was on; else "Job board" | yes | global |
| `gender_ethnicity_disability_veteran` | EEO and diversity questions | choice | "Prefer not to say" / "Decline to self-identify" | no | global |
| `consent_data_processing` | "I consent to the processing of my data for this application" | boolean | yes, when it is the application's own privacy notice | no | global |
| `consent_marketing` | "Keep me informed about other roles" | boolean | no | no | global |

## B. Role-family answers (the "why" questions)

One per role family key from the profile §3. Four to six sentences in the candidate's own words,
plain, no claim outside the proof list. The applier may adapt length.

| Key | Phrasings seen | Answer | Adapt | Scope |
| :-- | :-- | :-- | :-- | :-- |
| `why_this_role_<family>` | "Why are you interested in this role?" | | yes | role_family <key> |
| `why_us` | "Why do you want to work at <company>?" | Rule: name one specific thing from the posting or the company's site that is true and relevant, then one line on fit from the proof list. Never a generic line. | yes | global |
| `biggest_achievement` | "Tell us about an achievement" | | yes | global |
| `tools_and_stack` | "Which tools have you used?" | | no | global |
| `cover_letter` | "Cover letter" (when requested) | Rule: four short paragraphs: the role and where it was seen; one real understanding of the company; the relevant scope of experience from the proof list; a plain close. The candidate's register. | yes | global |

## C. Platform-specific

| Key | Phrasings seen | Type | Answer | Adapt | Scope |
| :-- | :-- | :-- | :-- | :-- | :-- |
| | | | | | platform |

## D. Never answer (hard block, always)

These are never answered by the applier, whatever the form says. The application is held and the
candidate is asked.

- Government ID, passport, national insurance, tax or social security numbers
- Date of birth, except the "over 18" checkbox
- Bank or payment details
- A photo or ID document upload
- Timed tests, coding or skills assessments, video answers, personality questionnaires
- References' personal contact details
- Terms the candidate has not read (contractor agreements, NDAs presented inside the form)
- Any question whose honest answer would need a fact outside the profile

## E. Pending (questions met, not yet answered)

Added by the run from `question_log`. The candidate answers, moves the row up, and re-approves.

| Seen on | Company | Question text | Required | Proposed answer (by the run, from the proof list; blank if none) |
| :-- | :-- | :-- | :-- | :-- |
| | | | | |

## F. Approval record

| Version | Approved on | Note |
| :-- | :-- | :-- |
| | | |
