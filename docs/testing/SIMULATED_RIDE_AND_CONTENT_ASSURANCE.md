# Simulated Ride And Content-Assurance Plan

Date: 2026-08-05
Status: Proposed test-system direction. It does not authorise product GPX import, route planning or microphone work.

## Bottom line

Yes: a Calimoto GPX trace can become a highly useful semi-automated test input. It can replay a whole journey, expose boundary detection and announcement timing, sample generated facts against a consistent rubric, and create a repeatable regression corpus.

It cannot by itself prove live GPS accuracy, Apple’s current reverse-geocoder result, Bluetooth intelligibility, music/navigation coexistence, rider attention or battery use. Those remain physical-device and road-test concerns.

The recommended sequence is:

1. analyse supplied GPX files privately and semi-manually now;
2. build a developer-only deterministic replay harness after the current TestFlight gate; and
3. add a controlled live-service/content audit mode only when the deterministic harness is reliable.

Do not add a customer-facing GPX importer merely to support testing. That is a separate future product decision, already shaped as RH-008.

## Current position

RideHorizon Test Mode currently advances through a fixed 11-waypoint Gloucestershire fixture. It does not import GPX, preserve timestamps/speed/accuracy, replay a trace automatically, or capture a structured route-wide announcement transcript. The harness below is therefore future work, not a statement of present behaviour.

## What a simulated ride can prove

| Question | GPX replay answer | Required supplement |
| --- | --- | --- |
| Did the policy recognise and prioritise the intended town/county/region/country transitions? | Yes, if replay uses frozen place-resolution fixtures and expected event traces. | Periodic live-geocoder comparison to detect platform/data drift. |
| Did a newer location suppress stale fact/speech work? | Yes, with controlled delays, cancellation and reordering. | Device integration for real framework scheduling. |
| Was the final announcement text short, relevant, safe and non-repetitive across a route? | Partly: rules and a structured rubric can score a sample or controlled corpus. | Human factual/relevance review; source checking for material claims. |
| Did Premium Voice return audio that matches the text and stays within engineering bounds? | Partly: duration, decode, leading/trailing silence, clipping/peak ceiling and speech-recognition comparison can be checked. | Helmet listening, music restoration and rider-comfort evidence. |
| Will the exact TestFlight build work on a real ride? | No. | Stationary physical checks and owner road UAT. |

## Stage A — private semi-manual GPX review

When Rob supplies a Calimoto GPX file, analyse it outside source control. First confirm that the file is a test artefact he intends to share; GPX often contains precise route, time and home/work-location information.

1. Keep the original local and uncommitted. Remove or coarsen start/end points, timestamps and any private waypoints before retaining a fixture.
2. Produce a route summary: duration, sample density, distance and significant candidate transitions. Do not publish coordinates in the summary.
3. Select a stratified sample: every country/nation/county change, a representative set of town changes, fast successive changes, pauses, out-and-back segments, poor-sample-density sections and known interesting places.
4. Create a private transition ledger containing only a sequence ID, elapsed-time bucket, expected hierarchy, observed hierarchy, intended boundary, and rationale. The ledger is the review reference; it is not a second source of production truth.
5. Run the resulting transitions through the current announcement policy and controlled fact/speech generators where technically feasible. Record the event trace and proposed announcement text.
6. Apply the route-content rubric below. Investigate failures rather than silently editing the result.

This stage is useful immediately for analysis and content review, but it cannot claim an end-to-end app replay because the current app has no GPX ingestion path.

## Stage B — deterministic developer-only replay harness

Build this as a test asset after the current private-beta release gate. It should be compiled out of normal TestFlight/Release binaries, use no live credentials, and make no product promise about planned-route awareness.

### Inputs

- Sanitised GPX-derived samples: elapsed time, coordinate, speed/course where available and an explicit synthetic horizontal-accuracy value.
- Frozen place-resolution fixture for each selected sample: the known street/town/county/nation/region/country result or deliberate geocoder failure.
- Rider settings, announcement mode, provider choice and ride-session state.
- Deterministic fact and speech fixtures, plus controllable delay/error/cancellation scenarios.

### Outputs

The harness should produce a structured, privacy-safe event trace rather than screenshots or free-text logs. Each entry records only:

- sequence/time offset and input condition;
- resolved hierarchy fixture and selected boundary type;
- policy decision: announce, suppress, replace, cancel, defer or finish;
- correlation ID and pipeline terminal state;
- announcement-text identifier and test-fixture identifier, not raw personal route data; and
- expected versus actual event-trace assertion.

For deterministic tests, use snapshots of these structured events. Do not snapshot a live model’s prose as if it were stable behaviour.

### Failure and edge-case injection

Every representative trace should also be mutated to cover the failures that road testing is poor at reproducing safely:

- duplicate, delayed, stale, inaccurate and out-of-order location samples;
- boundary jitter and street-only geocoder churn;
- rapid successive town/county transitions and an out-and-back route;
- delayed, failed or cancelled reverse geocoding;
- fact/TTS timeouts, transient/permanent HTTP failures, session renewal and provider failure;
- a new higher-priority place while fact/TTS/audio is pending;
- interruption, route change and media-services reset at different pipeline points; and
- manual End ride and inactivity expiry during every pending stage.

### Design constraints

- Make the clock, location source, geocoder, fact generator, speech generator and audio-session observer injectable.
- Separate **place resolution** from **announcement policy** so a frozen Apple-geocoder result can test policy without pretending that it is an authoritative administrative boundary source.
- Keep fixtures small, readable and versioned; give each a provenance and sanitisation note.
- Store raw GPX only outside Git. Commit only deliberately sanitised, minimal fixtures where their retention is justified.
- Run replay in an XCTest target or a developer command, not through tap-driven Test Mode. The existing Gloucestershire Test Mode remains a useful smoke test, not the route-regression engine.

## Stage C — controlled live-service route audit

After Stage B, optionally run selected sanitised transitions against the real proxy in a tightly bounded operator test. This detects contract drift and provider changes, but it is not deterministic and must not be a release-only dependency.

- Use a small, cost-capped sample and the standard safe operational credential path.
- Record request/result category, duration, model/prompt revision and a privacy-safe correlation ID.
- Never save bearer tokens, installation IDs, raw request headers or unredacted private route data.
- Compare outputs to semantic rules and human review, not byte-for-byte expected prose or audio.
- Keep deterministic fixtures as the gating regression suite; treat a live audit as monitoring and sampling evidence.

## Route-content rubric

Score each sampled announcement independently, then review the sequence as a whole. Use **Pass**, **Concern** or **Fail** with a concise reason; a failure becomes a defect or a bounded content/prompt follow-up.

| Dimension | Pass standard | Automatic/semi-automatic support | Human decision remains required |
| --- | --- | --- | --- |
| Geographic fit | Refers to the selected current place/boundary and does not confuse hierarchy levels. | Fixture comparison, boundary/type checks and hierarchy term detection. | Ambiguous places, disputed boundaries and local naming judgement. |
| Freshness | No phrase survives after a newer context supersedes it. | Correlated event trace and cancellation assertions. | Whether a technically current phrase arrived too late to be useful. |
| Safety and scope | No route, speed, hazard or riding instruction; no unnecessary question/invitation while moving. | Forbidden-pattern checks and existing fact sanitiser tests. | Subtle distractibility or misleading implication. |
| Brevity and clarity | Fits the configured mode; one principal idea while moving; names are pronounceable. | Character/sentence/duration bounds and text-shape rules. | Whether the wording is memorable and comprehensible. |
| Relevance | Adds a place-specific reason to care, not generic tourism filler. | Similarity/repetition flags and place-token checks. | Cultural value, rider usefulness and tone. |
| Factual support | Material claims have a credible source or are removed. | Claim extraction can flag review candidates; source-link presence can be checked. | Truth, nuance and source suitability. |
| Sequence quality | Avoids repeated regional setup and gives a varied, coherent journey. | Similarity clustering, repeated-entity detection and sequence summaries. | Narrative value and whether sparse silence was preferable. |

An LLM evaluator may triage likely repetition, unsupported claims or instruction-like text. It is not an authority for truth or safety; a human reviewer makes the final decision for flagged material.

### Sampling policy

Do not read every generated fact by default. Use all deterministic transition events for policy correctness, then risk-based content samples:

- review every country/nation/county transition and every safety/content-sanitiser flag;
- review the first occurrence of each town/region type and all adjacent duplicate/similar outputs;
- sample across different ride phases, return legs, interests and content depths; and
- expand to 100% review when a material factual, safety or repetition issue is found until the affected cause is corrected and shown stable.

Keep the sample frame, selection rule and reviewer decision with the route result. That makes a stated quality claim auditable without retaining the complete private ride trace.

## Speech-audio assurance

Use two layers.

### Automated engineering checks

For fixed speech fixtures, verify that audio decodes, duration is proportionate to the configured content mode, leading/trailing silence stays bounded, samples stay within the configured peak ceiling, and cancellation/release paths hold. A speech-recognition comparison of rendered fixture audio against the expected text can flag gross word loss; name dictionaries and manual review are needed for place names.

These checks detect corrupt, truncated, wildly wrong or technically unsafe output. They do not measure helmet intelligibility or perceived loudness.

### Human listening checks

Keep the existing calibration and audio-interoperability evidence as the authority. Review a stratified fixture set through the target helmet headset at normal music/navigation volume and rate: word/place-name intelligibility, comfort, harshness/pumping, appropriate relative loudness and music restoration. A simulated ride can schedule the phrases; only a physical listener can decide whether they are appropriate to hear.

## Future interactive-guide testing, briefly

Voice questions, “tell me more”, and spoken preference refinement are future capabilities. Start with a narrow intent set—**stop**, **cancel**, **repeat**, **shorter**, **more detail** and **less history today**—not open-ended conversation.

Before implementation, add an interaction test pack containing:

- clean, accented and helmet-noise utterance variants; false activations; silence; interruption and cancellation;
- current-place and last-announcement grounding cases, including ambiguous references and deliberately low confidence;
- response length/latency bounds, explicit stopped/deferred behaviour and no-answer cases;
- proof that session refinements expire at ride end and durable preferences require explicit confirmation;
- privacy tests for microphone permission, transcript minimisation, retention/deletion and no accidental audio capture; and
- physical tests for microphone recognition, listening/TTS/audio coexistence, rider attention and navigation priority.

Always-on listening is not assumed. The default safety hypothesis is explicit, bounded activation and a stopped-only or safely deferred response policy until physical evidence proves more is warranted. See the [interactive tour-guide reference](../product/reference/INTERACTIVE_TOUR_GUIDE_REFERENCE.md) for the product interaction model; it remains non-authorising.
