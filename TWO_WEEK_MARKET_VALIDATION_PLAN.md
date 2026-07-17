# RideHorizon Two-Week Market Validation Plan

Date: 2026-07-03

## Purpose

Turn the deep-research report into a concrete two-week validation sprint.

Source report:

```text
/Users/rob_dev/DocsLocal/motoguide/resources/RideHorizon_market_deep-research-report.md
```

Related supporting project:

```text
/Users/rob_dev/DocsLocal/landing_page_tool
```

Expected result: by the end of the sprint, RideHorizon has real rider evidence on usefulness, safety, channel response, TestFlight interest, and pricing/package direction.

## Research Interpretation

The report supports validating RideHorizon with real riders, but it does not prove demand.

Strong adjacent signals:

- Riders actively seek scenic/touring route tools.
- Riders already use helmet audio.
- Existing navigation stacks create frustration.
- Subscription fatigue is visible.
- Audio-tour products prove adjacent appetite for GPS-triggered stories.

Weak direct signal:

- Riders are not yet visibly asking for sparse town/county/place-awareness announcements.

Working conclusion:

```text
RideHorizon should validate a quiet companion position first: works with existing navigation, gives sparse place context, can stay silent, and does not replace the route planner.
```

Keep the full adaptive tour-guide vision in the story, but do not lead with noisy always-on AI.

## Sprint Questions

Primary question:

```text
Can RideHorizon work safely and usefully on a real ride, and do riders want to try it again?
```

Secondary questions:

- Does "quiet place awareness" make sense to touring riders?
- Does the fuller adaptive guide vision increase interest or increase safety concerns?
- Which content mode sounds most useful: silent display, boundary announcements, short facts, richer facts, POI suggestions, or voice questions?
- Which package is most plausible: free beta, regional pack, one-month touring pass, or annual subscription?
- Which channels produce useful rider conversations and beta leads?

## Workstreams

### 1. Product Proof

Use the iPhone app as the truth source.

Track:

- Ride started with RideHorizon enabled.
- Helmet audio route used.
- Mode used: quiet, names, short facts, long facts.
- Whether the rider kept audio enabled.
- Battery drain per hour.
- Background location/audio behaviour.
- Whether the rider would use it again.

Expected result: one or more real ride reports, not just concept feedback.

### 2. Landing Page And Survey

Use the landing-page tool project if ready enough:

```text
/Users/rob_dev/DocsLocal/landing_page_tool
```

If the tool is not ready, build the simplest interim landing page that can capture:

- Email.
- Rider type.
- Current navigation stack.
- Helmet audio setup.
- Preferred concept.
- Preferred package.
- Permission to contact for TestFlight.

Landing page positioning:

```text
RideHorizon works with your normal sat-nav and adds quiet spoken place context while you ride.
```

Hero variants to test:

- Hear where you are, without more screen-checking.
- A quiet spoken guide for the roads you already ride.
- Works with your normal sat-nav. Adds the bits it never tells you.

CTA variants:

- Join the rider beta.
- Get TestFlight access.
- Help shape quiet mode.

Expected result: one live or locally testable campaign with segmented CTAs and a short survey.

### 3. Rider Interviews

Run 10 to 12 structured interviews.

Start with behaviour:

- Walk me through your current navigation setup on a day ride.
- Walk me through your setup on a tour.
- What do you listen to in your helmet?
- When does audio help?
- When does audio become annoying?
- What do you use for scenic or interesting routes?
- Have you ever wanted to know more about places you were passing through?

Then test RideHorizon:

- Would sparse town, county, or region announcements be useful, irrelevant, or distracting?
- Would short facts be useful while moving?
- Would POI suggestions be useful?
- Would voice questions be useful while moving, stopped-only, or not at all?
- Would you rather pay for a regional pack, one-month touring pass, annual subscription, or nothing?
- Would you try this on a real ride in the next 14 days?

Expected result: every interview is scored for usefulness, distraction risk, and TestFlight willingness.

### 4. Community And Channel Tests

Post only where useful discussion is plausible. Do not spam groups.

Recommended first channels:

- MotoUK / Reddit.
- UKGSer-style forums.
- IAM or advanced-rider communities.
- Relevant UK touring Facebook groups.
- Personal rider network.

Post angles:

- Safety-led: "Would quiet place audio reduce screen-checking or just add distraction?"
- Touring-led: "Would you want to hear short context about places you pass on a Wales/Scotland/Europe ride?"
- Tool-stack-led: "If you already use Google Maps, Calimoto, Scenic, Kurviger, Garmin, or TomTom, what could a companion app add?"
- Pricing-led: "Would a one-month touring pass be more acceptable than another annual subscription?"

Expected result: comments, objections, tester leads, and repeated language are captured in the evidence log.

### 5. Pricing And Package Test

Do not treat survey pricing as proof.

Test these options:

- Free private beta.
- £4.99 regional pack.
- £9.99 one-month touring pass.
- Annual subscription only as a comparison, not the lead option.

Expected result: directional preference, not a final price.

## Evidence Log

Create a simple spreadsheet or markdown table with these fields:

| Field | Meaning |
|-------|---------|
| date | ISO-8601 date |
| source | interview, ride, forum, landing page, survey, TestFlight |
| channel | MotoUK, IAM, Facebook, personal network, etc. |
| rider_type | touring, commuter, club leader, privacy/safety sceptic, etc. |
| nav_stack | Google, Apple, Waze, Calimoto, Scenic, Kurviger, Garmin, TomTom, Beeline |
| helmet_audio | Cardo, Sena, Nex Xcom, earbuds, none |
| main_signal | useful, distracting, unclear, pricing objection, technical objection |
| mvp1_interest | high, medium, low |
| full_guide_interest | high, medium, low |
| beta_commitment | yes, maybe, no |
| paid_intent | pack, pass, annual, no, unknown |
| quote | short exact wording |
| follow_up | next action |

Expected result: decisions are based on evidence, not memory.

## Fourteen-Day Schedule

### Days 1-2: Prepare Assets

Work:

- Extract the landing-page brief from this plan.
- Decide whether `/Users/rob_dev/DocsLocal/landing_page_tool` is ready enough to use.
- Draft the short survey.
- Prepare the interview script.
- Prepare the evidence log.
- Confirm MVP1 build readiness and field-test route.

Expected result: campaign copy, survey, interview guide, evidence log, and ride checklist exist.

### Days 3-4: Build Campaign Surface

Work:

- Build or configure the landing page.
- Add segmented CTAs.
- Add survey redirect after signup.
- Add UTM capture if practical.
- Smoke test form submission.

Expected result: a working signup path with one test lead and one test survey response.

### Days 4-7: Recruit And Interview

Work:

- Recruit 15 to 20 riders.
- Run 5 to 8 interviews in this window.
- Prioritise riders with helmet audio and touring/navigation app experience.

Expected result: at least 5 scored interviews and a first pass at repeated objections.

### Days 6-9: Community Posts

Work:

- Post two or three carefully framed validation questions.
- Use different angles in different channels.
- Log every useful objection and phrase.
- Invite promising respondents to TestFlight or interview.

Expected result: at least 10 useful comments or direct responses, or clear evidence that the channel is poor.

### Days 7-11: MVP1 Ride And Private Beta

Work:

- Run the owner field ride if not already done.
- Recruit 3 to 5 private beta riders if build logistics allow.
- Collect post-ride feedback immediately.

Expected result: at least one real ride report, preferably several beta commitments.

### Days 10-12: Pricing Smoke Test

Work:

- Add or show package options.
- Ask interviewees and survey respondents to choose one.
- Do not take payment unless the flow is already safe and compliant.

Expected result: initial preference between free beta, regional pack, one-month pass, and annual subscription.

### Days 13-14: Review And Decide

Work:

- Summarise evidence by signal strength.
- Compare MVP1 interest against full-guide interest.
- Decide next action.

Go forward if:

- At least half of interviewed riders say they would try RideHorizon on a real ride.
- At least 3 riders are credible private-beta candidates.
- Real ride testing does not expose a blocking safety/audio/battery issue.
- Pack or pass pricing is not rejected outright.

Pause or pivot if:

- Riders only want better route planning.
- Riders reject non-navigation audio while moving.
- Helmet audio/background behaviour is unreliable.
- The strongest audience is generic road-trippers rather than motorcyclists.

Expected result: a written decision: continue MVP1 private beta, reposition, build landing tooling first, or pause.

## Human-Operable Next Steps

1. Review this plan and the deep-research report.
   Expected result: the two-week sprint scope is accepted or edited.

2. Identify whether the landing-page tool is ready enough.

```bash
sed -n '1,220p' /Users/rob_dev/DocsLocal/landing_page_tool/MILESTONES.md
```

Expected result: the current landing-page tool milestones are visible.

3. Create the first campaign brief for RideHorizon.
   Expected result: landing page copy, CTAs, survey questions, and tracking fields are ready for implementation.

4. Run the first real ride with RideHorizon.
   Expected result: one ride report captures headset audio, background operation, announcement usefulness, annoyance, and repeat-use intent.

5. Recruit the first 5 rider conversations.
   Expected result: enough real language to improve the landing page and survey before broader posting.
