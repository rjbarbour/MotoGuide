# RideHorizon PMF Factory And 100 Tasks Review

Date: 2026-07-02

## Purpose

Use the local PMF Factory and 100 Tasks material to decide what RideHorizon should do next, without importing the whole 100 Tasks startup process.

RideHorizon is not ready for scale, fundraising, team design, or heavy go-to-market machinery. It is currently in the PMF Factory path between **MVP Design**, **Build**, and **Launch and Measure**. The immediate job is to prove that the motorbike audio experience works on a real ride and that riders want it again.

## Sources

Local source files checked:

- `/Users/rob_dev/DocsLocal/pmf_factory/100tasks_relevance.md`
- `/Users/rob_dev/DocsLocal/pmf_factory/PMF_Factory_process.md`
- `/Users/rob_dev/DocsLocal/general/100tasks_kb/README.md`
- `/Users/rob_dev/DocsLocal/general/100tasks_kb/CONTENTS.md`

The configured Obsidian vault path from the local skill was also checked:

```text
/mnt/d/Obsidian Vault/AI Research/
```

Expected result: Obsidian vault notes are available for cross-checking.

Actual result: the path was not present on this machine, so this review uses the local PMF Factory notes and 100 Tasks knowledge base above.

## Current PMF Factory Stage

| PMF Factory stage | RideHorizon status |
|-------------------|------------------|
| 1. Idea Capture | Done. RideHorizon has an ICB and product definition. |
| 2. AutoVC evaluation | Partial. The use case is clear, but willingness-to-use and willingness-to-pay are unproven. |
| 3. Validation Plan | Started. `BUSINESS_VALIDATION_PLAN.md` defines MiroFish, interviews, ride tests, waitlist, and TestFlight. |
| 4. MVP Design | Mostly done for MVP1. Scope is live location, boundary changes, helmet speech, names/facts/quiet modes. |
| 5. Reusable Primitives | Not the priority. Extract only if repeated across PMF Factory products. |
| 6. Build | In progress. The iOS prototype and fact proxy exist. Field polish remains. |
| 7. Launch and Measure | Not ready. Needs physical ride evidence before broader TestFlight or public funnel. |
| 8. Portfolio Management | Later. Decide continue/kill/reposition after ride and rider evidence. |

## Current Market-Research Inputs

Deep-research report:

```text
/Users/rob_dev/DocsLocal/motoguide/resources/RideHorizon_market_deep-research-report.md
```

Current operating plan:

```text
/Users/rob_dev/DocsLocal/motoguide/repo/TWO_WEEK_MARKET_VALIDATION_PLAN.md
```

Supporting landing-page tool:

```text
/Users/rob_dev/DocsLocal/landing_page_tool
```

Interpretation:

- The report found strong adjacent evidence around scenic/touring tools, helmet audio, navigation-stack frustration, and subscription fatigue.
- It found weak direct evidence that riders already ask for sparse town/county/place-awareness announcements.
- The next validation cycle should test the quiet companion wedge with real riders, while keeping the adaptive tour-guide vision visible as the broader commercial thesis.
- The landing-page tool is relevant as supporting infrastructure, but it should not delay the first ride or first rider conversations.

## Relevant 100 Tasks Now

Use these tasks lightly. Do not run the full framework.

| 100 Tasks item | RideHorizon interpretation | Current action |
|----------------|--------------------------|----------------|
| Task 18: Customer Discovery | Understand whether touring riders actually want ambient place audio. | Run 5 to 8 rider interviews after the first physical ride proves the app can work. |
| Task 20: Proof of Concept | Prove feasibility before scaling product assumptions. | Build, install, and ride-test on the iPhone 17 Pro Max with the Nex Xcom headset. |
| Task 21: Define USPs | Clarify the offer so riders do not mistake RideHorizon for navigation. | Use: "motorbike place-awareness audio that runs alongside your nav app." Avoid: "AI tour guide" as the primary claim. |
| Task 22: Lean Startup Loop | Iterate from evidence, not feature appetite. | After each ride/interview batch, update the next experiment and stop adding speculative features. |
| Task 26: Specify MVP | Keep the MVP narrow. | Keep MVP1 to GPS, town/county/region/country changes, short speech, and quiet/names/facts modes. |
| Task 31: Develop MVP | Finish the smallest rideable version. | Finish M6/M6.5 polish before adding MVP2 listening or POI handoff. |
| Task 33: Online Footprint | Recruit testers only after the demo is credible. | Create a short demo/waitlist after the physical ride works. |
| Task 61: Define KPIs | Decide what evidence matters before TestFlight. | Track ride completion, headset speech success, repeat-use intent, TestFlight yes/no, and safety objections. |
| Task 67: Start KPI Reporting | Start simple reporting at first external validation. | Use a manual validation log before adding analytics. |
| Task 79: Analyze Customer Engagement | PMF evidence is usage and repeat intent, not compliments. | For TestFlight, measure rides completed, mode used, muted sessions, and "would use next ride". |
| Task 99: Achieve Product-Market Fit | PMF is later, but the signal definition starts now. | PMF requires repeated rides, retained testers, and willingness to pay or strongly advocate. |

## Tasks To Defer

These are relevant eventually, but not before the first field trial:

- Task 24: Financial model. Keep only rough pricing hypotheses until riders repeat use.
- Task 34: Design and wireframes. Do only practical field-readiness UI; defer polished design.
- Task 50: Payment service provider. No billing before usefulness is proven.
- Task 56: Sales funnel. Use a waitlist first, not a sales funnel.
- Task 75 to Task 78: reporting and channel optimization. No meaningful channel data yet.
- Task 82 to Task 89: roadmap, scalability, checkout, CAC/CLV. Premature until TestFlight evidence exists.
- Task 96 to Task 98: best practices and knowledge sharing. Capture learnings, but do not formalize process yet.

## Tasks To Skip For RideHorizon MVP1

Skip the 100 Tasks areas that conflict with the PMF Factory filter:

- Funding, investors, seed/growth capital, pitch decks.
- Founder team, org chart, hiring, culture, employee participation.
- Physical operations, facilities, logistics, supply chain.
- Heavy PR, press lists, launch campaigns.
- ESG ceremony beyond normal legal/privacy/safety review.

## What Codex Can Do

- Keep the roadmap and validation docs aligned with this review.
- Finish field-readiness engineering work.
- Build, install, and launch on the physical iPhone when connected.
- Draft ride-test checklists, interview scripts, waitlist copy, demo script, and validation logs.
- Turn ride/interview evidence into small issues or next milestone decisions.
- Keep irrelevant 100 Tasks machinery out of MVP1 planning.

## Decisions Or Actions Needed From Rob

1. Confirm whether the first physical ride target remains `2026-07-03`.
   Expected result: the field-readiness work can be cut to fit the date.

2. Make the iPhone 17 Pro Max and Nex Xcom headset available for install and ride testing.
   Expected result: RideHorizon can be tested through the actual helmet audio path.

3. Pick the first ride route.
   Expected result: one short familiar route can test GPS, background behavior, speech timing, and annoyance level safely.

4. Decide the first validation posture: field-test rough edges now, or polish for another day first.
   Expected result: engineering scope is either "install and ride" or "finish M6/M6.5 polish before ride".

5. After the ride, give direct feedback on usefulness, safety, timing, frequency, and whether you would run it again.
   Expected result: RideHorizon can move through the PMF Factory loop based on evidence, not guesses.

## Next Appropriate Step

Finish M6/M6.5 field readiness, build and install on the phone, then run one real ride. Do not add MVP2 features until that result is recorded.
