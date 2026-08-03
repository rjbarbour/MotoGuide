# RideHorizon Business Validation Plan

Date: 2026-07-02

## Purpose

Use MiroFish and adjacent validation tools to test whether RideHorizon is worth building beyond the current prototype.

The goal is not to prove the idea from simulated evidence. The goal is to find likely objections, sharper personas, stronger positioning, and the smallest real-world tests that can falsify or strengthen the idea.

Commercial thesis: RideHorizon is not only MVP1 county/town announcements. The larger product is a rider-controlled tour guide that can range from silent display-only mode to sparse boundary announcements to adaptive always-on guidance. It should learn preferred topics and detail level, answer questions, suggest worthwhile stops, and hand chosen destinations to existing navigation apps.

MVP1 validation role: use MVP1 as a private-beta proof of function, trust, and repeat intent. Do not expect MVP1 alone to prove willingness to pay. Test payment intent against both the current MVP1 feature set and the richer tour-guide promise, then compare the gap.

## PMF Factory And 100 Tasks Reference

Use `docs/product/strategy/PMF_FACTORY_100_TASKS_REVIEW.md` as the RideHorizon-specific filter over the local PMF Factory and 100 Tasks material.

Use `docs/product/strategy/TWO_WEEK_MARKET_VALIDATION_PLAN.md` as the current operating plan for turning the market research into interviews, landing-page tests, community posts, private beta recruitment, and pricing/package signals.

Deep-research source report:

```text
/Users/rob_dev/DocsLocal/motoguide/resources/RideHorizon_market_deep-research-report.md
```

Current interpretation:

- RideHorizon is between PMF Factory **MVP Design**, **Build**, and **Launch and Measure**.
- The relevant 100 Tasks now are customer discovery, proof of concept, lean validation loop, MVP specification/build, simple online footprint, and early KPI definition.
- Funding, org design, hiring, physical operations, heavy PR, payment setup, CAC/CLV optimization, and scale tasks are out of scope until real ride and TestFlight evidence justify them.

Expected result: validation work stays focused on physical feasibility, rider usefulness, repeat intent, and willingness to try or pay.

## Deep-Research Summary

The 2026-07-03 deep-research report supports validation, but not a demand conclusion.

Key signals:

- Strong adjacent demand exists around scenic/touring route tools, helmet audio, route-app frustration, and subscription fatigue.
- Direct evidence for RideHorizon's exact MVP1 wedge, sparse spoken place awareness, is weak until riders try it.
- The clearest first position is a quiet companion that works with existing navigation and adds sparse place context.
- The full adaptive tour-guide vision should stay visible, but broad always-on AI should not be the first safety-facing pitch.

Expected result: use the report to sharpen copy, channels, interview prompts, and package tests; do not treat it as product-market fit evidence.

## Validation Question Strategy

Do not try to answer every RideHorizon question in one campaign. Use one coherent public story, but separate the learning questions.

Primary question for the next cycle:

```text
Can RideHorizon run safely and usefully on a real ride, and do touring riders want to try it again?
```

Secondary questions to test in parallel, but not treat as blockers for MVP1:

- Does the full adaptive tour-guide vision create stronger interest than MVP1 boundary/fact announcements?
- Which mode feels most valuable: silent display, boundary announcements, short facts, richer guide, POI suggestions, or voice questions?
- Which safety controls are required before riders accept richer or always-on guidance?
- Which package sounds plausible: free beta, one-month touring pass, offline touring pack, annual subscription, or premium subscription?

Recommended campaign structure:

- Use one RideHorizon landing page, not two unrelated brands.
- Make the landing page present the range: `silent → boundary alerts → short facts → adaptive tour guide`.
- Use segmented calls to action: `Join private beta`, `Tell me when touring packs are available`, and `I want the full AI tour guide`.
- Keep the first survey short and route respondents based on interest. Do not force every respondent through every feature question.
- Use different posts in different channels to test angles, then collate results under the same evidence log.

Do not split into two landing pages unless the first traffic is large enough to compare meaningfully or the positioning is genuinely incompatible. At this stage, interviews and channel-specific posts will teach more than a statistically weak A/B test.

Expected result: MVP1 feasibility, full-vision demand, and pricing intent are separated in analysis even if they are recruited through one campaign.

## Research Best-Practice Notes

Use these rules when interpreting validation evidence:

- Test hypotheses outside the building. Treat product, market, channel, and pricing as assumptions until real riders respond.
- Prefer behaviour over opinion. Ask about the last ride, actual helmet audio use, actual navigation setup, and whether they will join TestFlight.
- Keep each question single-purpose. Do not combine safety, price, and feature preference in one survey item.
- Ask general-to-specific. Start with riding behaviour and current tools, then introduce RideHorizon, then ask about MVP1, MVP2, full guide, and payment.
- Use MVP1 as the minimum learning vehicle. It is not required to contain the whole product vision.
- Treat willingness-to-pay answers as weak until they involve a concrete action, for example joining a paid waitlist, choosing a package, or accepting a real price anchor.

## MiroFish Repo

MiroFish was cloned outside the iOS app checkout:

```text
/Users/rob_dev/DocsLocal/mirofish
```

Upstream:

```text
https://github.com/666ghj/MiroFish.git
```

Current inspected commit:

```text
96096ea Merge pull request #640 from lllopic/fix/add-type-hints-and-helper-method
```

MiroFish is a multi-agent simulation web app. It takes seed material, builds a graph/memory layer, generates agent personas, runs Twitter/Reddit-style simulations, and produces reports. It requires LLM and Zep API keys for real runs.

Do not copy MiroFish code into RideHorizon. It is AGPL-3.0 licensed. Use it as an external research tool only.

## What MiroFish Can Test

MiroFish can help with:

- Simulating how rider communities may react to the idea.
- Finding objections before interviews.
- Comparing positioning: audio companion, AI tour guide, navigation add-on, or motorcycle touring tool.
- Testing content depth: names only, one sentence, richer facts, or quiet mode.
- Testing MVP2 demand: nearby POI suggestions, longer optional descriptions, ask-back through a helmet microphone, and `navigate there` handoff.
- Testing the full-range concept: silent display, boundary announcements, passive facts, adaptive always-on tour guide, and general place questions.
- Stress-testing safety language and distraction concerns.
- Exploring likely channels: rider forums, clubs, YouTube, Facebook groups, Reddit, touring blogs, and motorcycle shows.
- Generating interview prompts and survey hypotheses from simulated discussion.

MiroFish cannot validate:

- Whether helmet audio behaves safely on a real ride.
- Whether riders will keep the app running after novelty fades.
- Whether Apple background location/audio behaviour is reliable.
- Whether riders will pay.
- Whether the spoken timing is acceptable in traffic.
- Whether the product is trusted with live location.

Those need real riders and physical tests.

## Personas To Simulate

Use these as seed personas and as real interview targets.

| Persona | Description | Core question |
|---------|-------------|---------------|
| Touring rider | UK rider doing long weekend rides or European trips, already uses navigation and helmet audio. | Does ambient place awareness add enough value during a ride? |
| Safety-first rider | Experienced rider who dislikes distractions and extra audio. | What speech frequency, timing, and content is acceptable? |
| Tech-enabled adventure rider | Uses Garmin, Calimoto, Scenic, BMW/TomTom, Cardo/Sena, GPX files, and multiple devices. | Can RideHorizon fit alongside an existing navigation stack? |
| Club ride leader | Plans routes for other riders and cares about group experience. | Could RideHorizon improve group touring or pre-planned routes? |
| Casual scenic rider | Rides for enjoyment, not technical touring. | Is the idea understandable without explaining the tech? |
| Privacy cautious rider | Likes the value but worries about location data, tracking, battery, and subscriptions. | What trust promises are required before use? |
| Travel/history enthusiast | Wants local facts, landscapes, borders, and landmarks. | How rich can content be before it becomes too much? |
| Navigation loyalist | Believes Google Maps, Waze, Garmin, or Calimoto already solves enough. | What must RideHorizon avoid competing with? |

## MiroFish Simulation Runs

Run small simulations first. Keep each run narrow and compare outputs.

### Run 1: First Reaction

Seed material:

- RideHorizon ICB.
- Current MVP boundary.
- Screenshots or short description of the iOS prototype.
- Example phrases: `Welcome to Wales. You are in Chepstow, Monmouthshire`.
- Alternatives: Google Maps, Waze, Garmin, TomTom, Calimoto, Scenic, Kurviger, REVER, Beeline.

Simulation requirement:

```text
Simulate discussion among UK motorcyclists after seeing a short demo of RideHorizon, an iPhone app that runs alongside normal navigation and speaks short place context through a helmet headset. Focus on adoption interest, safety concerns, trust concerns, competing alternatives, and willingness to try a TestFlight build.
```

Expected result: a report listing strongest positive hooks, strongest objections, misunderstood positioning, and interview questions.

### Run 2: Safety Objections

Simulation requirement:

```text
Simulate critical feedback from experienced touring motorcyclists, riding instructors, safety-conscious commuters, and riders who already use helmet intercoms. Test whether short spoken place announcements are seen as helpful or distracting. Identify rules that would make the product acceptable on a real ride.
```

Expected result: a ranked list of distraction risks and product constraints, especially frequency, quiet mode, interruption, volume, and default settings.

### Run 3: Positioning

Simulation requirement:

```text
Compare four RideHorizon positions: motorbike audio guide, ambient place-awareness companion, AI tour guide, and navigation add-on. Simulate how each position lands with touring riders. Recommend the clearest promise and the phrases that create the least confusion.
```

Expected result: one preferred positioning statement and phrases to avoid.

### Run 4: Content Depth

Simulation requirement:

```text
Simulate rider reactions to four RideHorizon content modes: quiet, names only, one-sentence short facts, and richer spoken facts. Identify when each mode is useful, when it becomes annoying, and what default should be used for a first ride.
```

Expected result: default content recommendation and a list of mode-switch triggers.

### Run 5: Pricing And Packaging

Simulation requirement:

```text
Simulate how UK touring motorcyclists react to RideHorizon pricing options: free prototype, one-time purchase, monthly subscription, annual subscription, and paid country/region packs. Focus on trust, perceived value, objections, and what evidence would make payment feel reasonable.
```

Expected result: pricing hypotheses to test with real riders, not a final price.

### Run 6: MVP2 POI And Voice Handoff

Simulation requirement:

```text
Simulate how UK and Europe touring motorcyclists react to a RideHorizon MVP2 concept: while riding or stopped, RideHorizon may suggest nearby points of interest, give a longer optional description, and let the rider say "navigate there" to hand off the selected destination to Google Maps, Apple Maps, or another navigation app. Test whether riders want this, whether it feels safe, whether voice questions should be stopped-only, what POI types are valuable, and whether this belongs in a paid subscription, monthly touring pass, or offline touring pack.
```

Expected result: decide whether MVP2 prioritises passive POI suggestions, stopped-only ask-back, moving voice commands, or no voice layer until passive use proves repeat value.

### Run 7: Full Adaptive Tour-Guide Vision

Simulation requirement:

```text
Simulate how UK and Europe touring motorcyclists react to the full RideHorizon vision: a rider-controlled guide that can be silent, announce only borders and places, provide short or long facts, run as an always-on tour guide for scenic parts of a ride, learn preferred topics and detail level, answer general place questions, suggest stops, and hand destinations to an existing navigation app. Test perceived value, safety concerns, privacy concerns, battery concerns, AI trust, subscription tolerance, offline touring-pack appeal, and which controls are required before riders would use it.
```

Expected result: determine whether the strongest commercial promise is passive place awareness, adaptive tour guide, interactive POI discovery, offline touring packs, or a combination.

### Run 8: Personalisation And Packaging

Simulation requirement:

```text
Simulate how UK and Europe touring motorcyclists react to two RideHorizon experiences: a cost-efficient standard guide that may reuse shared place facts and speech, and a personalised guide that adapts facts to the rider's interests, familiarity and custom instructions. Do not describe cache hits or AI-generation costs as customer-facing pricing units. Test whether personalisation changes perceived value, whether riders understand a simple package distinction, and whether it supports a touring pass, premium subscription, offline pack or no separate charge. Identify the smallest real-rider test that could distinguish curiosity from willingness to pay.
```

Expected result: pricing and package hypotheses for real interviews or a paid smoke test. Do not create tiers from simulated evidence alone.

## Other Validation Tooling

### Real-Ride Test Log

Use the existing iPhone build as the primary truth source.

Track:

- Did the app keep running in background?
- Did speech play through the Nex Xcom headset?
- Did speech mix acceptably with navigation?
- Were announcements too early, too late, too frequent, or too sparse?
- Did the rider understand where they were without looking?
- Did the rider want the app on for the next ride?

Do not store private ride logs or location history without explicit opt-in.

### Rider Interviews

Run 8 to 12 calls or in-person interviews before building major new features.

Interview for behaviour, not opinions:

- Tell me about your last long unfamiliar ride.
- What navigation setup did you use?
- Did you know what towns, regions, or borders you passed through?
- Did you use helmet audio?
- What audio was useful or annoying?
- When would you mute non-navigation audio?
- What would make you uninstall this?
- Would you try this on your next ride?
- Would you want RideHorizon to suggest nearby places worth visiting?
- Would you want to ask "anything worth visiting nearby?" through your helmet microphone?
- Should voice questions work while moving, only when stopped, or not at all?
- If RideHorizon suggested a place, would "navigate there" handoff to Google Maps or Apple Maps be useful?
- Which POIs are worth hearing about: castles, viewpoints, cafes, fuel, museums, landmarks, scenic roads, or border points?

Expected result: a decision on whether the first target remains touring motorcyclists, and which objection blocks adoption hardest.

### Wizard-Of-Oz Audio Test

Create a pre-scripted route audio track before building more automation.

Use a real route and manually prepare spoken announcements. Play them through the helmet during a ride or passenger/car simulation.

Expected result: evidence on whether the experience is valuable even before the app is perfect.

### Demo Video And Waitlist

Make a 60 to 90 second demo showing:

- Normal navigation remains separate.
- RideHorizon speaks short place context.
- Quiet/names/facts modes.
- Helmet audio use.
- No route planning promise.

Expected result: waitlist signups, TestFlight volunteers, and objections from real riders.

### Private Beta And Willingness To Pay

Treat MVP1 as a private beta first.

Use MVP1 to test:

- Does it work on real rides with helmet audio?
- Do riders understand and trust it?
- Do they want it on again after novelty fades?
- Which controls are required before broader release?
- Does the current experience make the full tour-guide vision credible?

Use willingness-to-pay tests carefully:

- Ask whether riders would pay for the MVP1-level product if it worked reliably.
- Ask separately whether they would pay for the full adaptive tour guide with voice questions, richer descriptions, POI suggestions, and navigation handoff.
- Test package preference: free beta, one-month touring pass, offline touring pack, annual subscription, or bundled premium features.
- Keep caching invisible to customers. Test payment for useful capabilities such as personalisation or offline availability, not for whether an internal request happens to reuse cached content.
- Treat refusal to pay for MVP1 as useful information, not a rejection of the full product.

Expected result: decide whether MVP1 is enough for a low-priced product, or whether it should remain a private-beta stepping stone toward a higher-value guide.

### Survey

Use a short survey only after interviews identify the right language.

Measure:

- Ride frequency.
- Touring frequency.
- Helmet audio setup.
- Current navigation tools.
- Interest in place-awareness audio.
- Biggest concern.
- Willingness to try TestFlight.
- Willingness to pay if it works reliably.
- Interest in nearby POI suggestions.
- Interest in stopped-only voice questions.
- Interest in "navigate there" handoff to an existing navigation app.
- Preferred package for richer or interactive features: offline touring pack, one-month touring pass, annual subscription, or not interested.
- Interest in the full adaptive tour-guide concept.
- Whether the always-on mode should be default-off, ride-section-only, stopped-only, or user-enabled.

Expected result: directional confidence, not product-market fit proof.

### Review And Forum Mining

Mine reviews and public discussions for Calimoto, Scenic, Kurviger, Garmin, TomTom, Beeline, Cardo, and Sena.

Look for:

- Audio pain points.
- Battery/background complaints.
- Navigation overload.
- Route discovery desires.
- Touring use cases.
- Trust and subscription objections.

Expected result: a competitor objection map and language riders already use.

### TestFlight Cohort

Recruit 5 riders before broadening.

Minimum cohort:

- 2 touring riders.
- 1 daily rider with helmet audio.
- 1 club/group rider.
- 1 privacy/safety sceptic.

Expected result: at least 3 ride reports with headset audio, background mode, and usefulness feedback.

## Evidence Ladder

| Level | Evidence | Decision it supports |
|-------|----------|----------------------|
| 0 | MiroFish simulations | What to ask and what to test first. |
| 1 | Rider interviews | Whether the problem is real and language is clear. |
| 2 | Demo/waitlist | Whether riders want to try it. |
| 3 | Wizard-of-Oz ride | Whether the experience has value. |
| 4 | Physical iPhone ride | Whether the app can work safely. |
| 5 | TestFlight cohort | Whether riders repeat use. |
| 6 | Paid test | Whether value supports a business. |

Do not move past Level 4 until the real iPhone and headset ride works.

## Suggested First Validation Sprint

Timebox: 7 days.

1. Run MiroFish first-reaction and safety-objection simulations.
   Expected result: top 10 objections and top 10 interview questions.

2. Conduct 5 rider interviews.
   Expected result: confirm or reject the core problem statement.

3. Run one real ride with the iPhone and Nex Xcom headset.
   Expected result: physical feasibility notes.

4. Create one short demo video from the working prototype.
   Expected result: a link that can recruit TestFlight riders.

5. Ask 10 riders for a TestFlight yes/no.
   Expected result: at least 3 qualified testers or a clear positioning problem.

## Exact MiroFish Commands

Check the clone:

```bash
cd /Users/rob_dev/DocsLocal/mirofish && git log -1 --oneline
```

Expected result: prints the latest commit, currently `96096ea Merge pull request #640 from lllopic/fix/add-type-hints-and-helper-method`.

Create local non-secret configuration:

```bash
cd /Users/rob_dev/DocsLocal/mirofish && cp .env.example .env
```

Expected result: `.env` contains Keychain references for `LLM_API_KEY` and `ZEP_API_KEY`, plus non-secret model configuration. Never replace those references with credential values.

Verify the required Keychain items without printing their values:

```bash
security find-generic-password -s MiroFish -a LLM_API_KEY >/dev/null && security find-generic-password -s MiroFish -a ZEP_API_KEY >/dev/null
```

Expected result: no output and exit status `0`.

Install dependencies:

```bash
cd /Users/rob_dev/DocsLocal/mirofish && npm run setup:all
```

Expected result: root/frontend Node dependencies install and backend `uv sync` creates the Python environment.

Start MiroFish:

```bash
cd /Users/rob_dev/DocsLocal/mirofish && npm run dev
```

Expected result: frontend runs at `http://localhost:3000` and backend API runs at `http://localhost:5001`.

## First Upload Pack For MiroFish

Use these as seed material:

- `/Users/rob_dev/DocsLocal/digital-mercenaries-ltd/icb-catalogue/staged_icbs/6a1047a6a591ed37d9fd4e0e.md`
- `/Users/rob_dev/DocsLocal/motoguide/repo/MILESTONES.md`
- `/Users/rob_dev/DocsLocal/motoguide/repo/docs/project/status/ROADMAP_STATUS.md`
- `/Users/rob_dev/DocsLocal/motoguide/repo/docs/product/plans/MVP_POLISH_PLAN.md`
- A short manual note with the target headset, iPhone, example announcement phrases, and competitor list.

Expected result: MiroFish has enough context to generate rider personas, discussion behaviour, and validation reports.

## Decision Gates

Continue MVP1 if:

- Riders understand the product in one sentence.
- Safety objections can be answered with defaults and quiet mode.
- At least 3 riders agree to try TestFlight.
- The physical iPhone/headset ride works.

Pause or reposition if:

- Riders hear it as another navigation app.
- Riders reject non-navigation audio while moving.
- Helmet audio/background behaviour is unreliable.
- The strongest use case is cars or tourism rather than motorbikes.
