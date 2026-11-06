-- Standard answer-bank rows every user starts with. Inserted as approved = false;
-- the user confirms them at stage C and approves the bank at stage F.
-- Rows whose answer depends on the person are seeded with answer_text null and a
-- note saying what the setup prompt fills from the profile.

insert into public.answer_bank (question_key, question_patterns, answer_type, answer_text, answer_choices_preferred, scope, may_adapt, notes)
values
  ('sponsorship_needed',
   array['will you now or in the future require sponsorship', 'do you require visa sponsorship', 'need sponsorship to work'],
   'boolean', null, array[]::text[], 'global', false,
   'Fill from candidate_profiles.right_to_work: no when the profile seeks no relocation or visa'),

  ('relocation',
   array['are you willing to relocate', 'open to relocation'],
   'boolean', null, array[]::text[], 'global', false,
   'Fill from the profile: no unless work_models_accepted lists a city'),

  ('remote_preference',
   array['preferred work arrangement', 'work location preference', 'remote hybrid or onsite'],
   'choice', null, array['Remote', 'Fully remote', 'Hybrid', 'On-site'], 'global', false,
   'Order the choices from candidate_profiles.work_models_accepted'),

  ('salary_expectation',
   array['expected salary', 'desired compensation', 'salary expectations', 'what are your salary requirements'],
   'text', null, array[]::text[], 'global', true,
   'Fill from candidate_profiles.salary_answer_policy; never below the floor'),

  ('notice_period',
   array['notice period', 'when can you start', 'earliest start date', 'availability to start'],
   'text', null, array[]::text[], 'global', true,
   'Fill from candidate_profiles.notice_period_text and earliest_start_text'),

  ('years_experience_total',
   array['years of experience', 'how many years of experience', 'total years of relevant experience'],
   'number', null, array[]::text[], 'global', false,
   'Fill from candidate_profiles.years_experience (the CV''s number, rounded down)'),

  ('linkedin_url',
   array['linkedin profile', 'linkedin url', 'linkedin'],
   'url', null, array[]::text[], 'global', false,
   'Fill from candidate_profiles.linkedin_url'),

  ('phone',
   array['phone number', 'mobile number', 'contact number'],
   'text', null, array[]::text[], 'global', false,
   'Fill from candidate_profiles.phone_text; leave null when the profile says no phone on forms (then optional fields stay blank, required ones escalate)'),

  ('location_current',
   array['where are you located', 'current location', 'city', 'country of residence'],
   'text', null, array[]::text[], 'global', false,
   'Fill from candidate_profiles.location_text'),

  ('how_did_you_hear',
   array['how did you hear about this role', 'how did you hear about us', 'source'],
   'choice', 'the platform the listing was found on; otherwise "Job board"',
   array['LinkedIn', 'Indeed', 'Job board', 'Company website', 'Other'], 'global', true,
   'Prefer the sighting''s platform'),

  ('eeo_gender',
   array['gender', 'gender identity'],
   'choice', 'Prefer not to say', array['Prefer not to say', 'Decline to self-identify', 'I don''t wish to answer'], 'global', false,
   'Fixed for every user (ANSWER-AND-COPY-RULES.md §9)'),

  ('eeo_ethnicity',
   array['race', 'ethnicity', 'race/ethnicity'],
   'choice', 'Prefer not to say', array['Prefer not to say', 'Decline to self-identify', 'I don''t wish to answer'], 'global', false,
   'Fixed for every user'),

  ('eeo_disability',
   array['disability status', 'do you have a disability'],
   'choice', 'Prefer not to say', array['I don''t wish to answer', 'Prefer not to say', 'Decline to self-identify'], 'global', false,
   'Fixed for every user'),

  ('eeo_veteran',
   array['veteran status', 'protected veteran'],
   'choice', 'Prefer not to say', array['I don''t wish to answer', 'Prefer not to say', 'I am not a protected veteran'], 'global', false,
   'Fixed for every user; "not a protected veteran" only when the profile makes it plainly true'),

  ('over_18',
   array['are you over 18', 'are you at least 18 years of age', 'legally of age'],
   'boolean', 'yes', array[]::text[], 'global', false,
   'When the profile makes it true'),

  ('consent_data_processing',
   array['i consent to the processing of my data', 'privacy policy', 'i agree to the privacy notice', 'data retention'],
   'boolean', 'yes', array[]::text[], 'global', false,
   'Yes for this application''s own privacy notice only'),

  ('consent_marketing',
   array['keep me informed about other roles', 'join our talent community', 'receive updates', 'talent pool'],
   'boolean', 'no', array[]::text[], 'global', false,
   'No unless the user''s bank says otherwise'),

  ('previously_employed_here',
   array['have you previously worked for', 'former employee', 'previously applied'],
   'boolean', null, array[]::text[], 'global', false,
   'Derivable: yes only when the company is in the profile''s employers list or Supabase holds a prior application'),

  ('referral_name',
   array['were you referred by an employee', 'referral', 'employee referral name'],
   'text', '', array[]::text[], 'global', false,
   'Blank unless the opportunity''s source is a referral with a named person'),

  ('why_us',
   array['why do you want to work at', 'why are you interested in our company', 'why this company'],
   'text', 'RULE: one true, specific thing from the posting or the company''s own site; then one sentence of fit from the proof list. No praise. If nothing specific is found in five minutes, use the role-family answer alone and log it.',
   array[]::text[], 'global', true,
   'ANSWER-AND-COPY-RULES.md §6'),

  ('cover_letter',
   array['cover letter', 'covering letter', 'letter of motivation', 'why should we hire you'],
   'text', 'RULE: four short paragraphs under 220 words: the role and where it was seen; one real thing about the company; the relevant scope from the proof list matched to the posting''s responsibilities; a plain close with availability and "my CV is attached".',
   array[]::text[], 'global', true,
   'ANSWER-AND-COPY-RULES.md §7');
