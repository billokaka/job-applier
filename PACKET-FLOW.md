# The packet tier

The depth treatment for the best fits of the day (up to the profile's `packets_per_day`, default
2). A packet turns one applied opportunity into a small account-based campaign: a compact evidence
pack, up to three relevant people, one distinct message each, follow-ups, and the interview
record. **Every message to a person is approved by the user one by one, in every mode.** The
application itself goes through the daily run's step 5 like any other.

```text
Applied (step 5) → Research pack → Map up to three people → Draft one message each
  → User approves each → Send and log (next run, step 2) → Follow up → Interview or close → Learn
```

## 1. Research pack (after the application, same run)

Compact and sourced, not a company summary:

- what the company sells and to whom; product, service, agency, marketplace, data or hybrid;
- the customer problem it publicly addresses;
- scale and commercial stage, when verifiable;
- one or two facts that change the work in this role;
- the responsibilities that decide which part of the user's proof list matters;
- every uncertainty, left as uncertainty.

Each claim is a `research_sources` row with `certainty` (confirmed, inferred, unknown), the URL and
the access time. `companies.research_status` moves to `partial` or `verified`.

## 2. Map up to three people

From the posting, the company page and the user's LinkedIn (and Sales Navigator when the user has
it). Three distinct people with three distinct reasons to care:

| Rank | Person | Why they matter |
| :-- | :-- | :-- |
| 1 | The likely or direct hiring manager | Knows the daily work and the gap the role fills |
| 2 | The functional or sales leader | Owns the outcome the role serves |
| 3 | Recruiter, talent partner, job poster, or founder by company scale | Owns the process and eligibility; at a small company, the decision |

Company scale changes the map: small founder-led (founder, direct commercial leader, one relevant
operations or team contact); growth (direct manager, functional head, internal recruiter); large
(the exact function's manager, the recruiter or poster, the nearest functional leader; never the
CEO for the title alone).

For each person: a `contacts` row (name, current company and title, LinkedIn URL, connection
degree, whether normal messaging is available; a work email only when found on a public source,
with the source and verification state) and an `opportunity_contacts` row (rank, recipient type,
`relevance_reason`, `authority_status` confirmed or inferred, business-unit match).

**Three is a target, never a quota.** One or two verifiable people and a recorded gap beat a third
added for the count. "Relevance is not authority": a reporting line that is not public is
`inferred`.

## 3. Choose the channel and draft

One primary first-touch channel per person: a normal LinkedIn message when connected; InMail when
not connected and the person is highly relevant; email when a verified work address exists and
email is the cleaner route; a connection note only when connecting is itself the right first
step (a note is not a compressed cover letter). Never the same copy through two channels on the
same day.

Every draft is a `messages` row at `awaiting_approval`, built on this shape:

```text
Saw the exact role and applied
→ one real thing understood about the company and the work
→ only the role-relevant scope of the user's experience, from the proof list
→ why this company and role make sense
→ a clear, low-pressure close; "my CV" if attached
```

Recipient purpose controls the message: the hiring manager asks "can this person do the daily
work"; the leader asks "will this person improve the outcome"; the recruiter asks "is this person
coherent, eligible and worth advancing"; the founder asks "does this person understand what we are
building". The three drafts are not lightly edited copies of one another. Register:
`ANSWER-AND-COPY-RULES.md` §5.

## 4. Approval, send, log

Each draft reaches the user as an ASK item: recipient and why, channel, subject if any, the exact
body, the attachment, the planned follow-up date. The user approves, edits, or says not to contact
(recorded as `not_contacting_reason`). The next run's step 2 sends approved messages, records the
exact final copy, time and thread id, and sets `sent`. A draft is never marked sent.

## 5. Follow up

Every active packet has one dated next action. Planning convention, not law: first follow-up about
4 to 5 working days after the first touch; second and last about 6 to 8 days later; stop on a
reply, a rejection, role closure, interview movement, or a request not to contact. A follow-up adds
something (context, a work sample, a relevant fact), never "checking in". Each follow-up is a new
draft and a new approval.

## 6. Interview and outcome

Replies, screens, interviews, work samples, offers and rejections are `interactions` rows with
evidence and a next action; the stage moves on evidence only. Interview preparation (the company's
likely questions, the proof to bring, the questions to ask) is written to the opportunity's notes
and offered to the user as an ASK item with the invite.

## 7. Definition of a complete packet

- deduplicated, qualified and applied with evidence;
- research saved with sources;
- up to three people verified and ranked, gaps stated;
- each intended recipient has an approved distinct message or a recorded reason not to contact;
- every sent touch logged exactly;
- a dated next action, or a closed reason.

*The packet treatment is the original company-by-company campaign, generalised. Nothing in it names
a person or a company.*
