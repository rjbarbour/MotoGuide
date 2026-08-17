# RideHorizon Quality-Risk Coverage Model

Date: 2026-08-05
Status: Active coverage model; it is not a test-run record.

## How to use this model

For a new increment, identify the affected rows, add the required evidence to the work item, and record results in the appropriate operational or code-test location. A blank or untested row is a known evidence gap, not a silent release exception.

| ID | Quality risk and failure question | Primary prevention/detection | Required evidence before external beta | Current authority/evidence home |
| --- | --- | --- | --- | --- |
| QR-01 | **Rider safety and distraction:** Could this ask for interaction while moving, speak at an inappropriate time, or create cognitive/audio overload? | Safety copy and interaction design review; announcement-policy tests; parked and road observation. | No P0/P1 safety defect; exact-build stationary checks and owner road-UAT evidence. | `AGENTS.md`; `RIDE_UAT_PROTOCOL.md`; TestFlight field evidence. |
| QR-02 | **Ride lifecycle/background work:** Does work begin only after Start ride and fully end after End ride or inactivity expiry? | Pure lifecycle tests; cancellation and diagnostic tests; physical location-indicator and background checks. | Exact-build start/end, lock-screen, inactivity and post-end evidence. | `RideSessionLifecycleTests`; `LocationManagerTests`; TestFlight field evidence. |
| QR-03 | **Geographic correctness and freshness:** Is the displayed/spoken hierarchy plausible, priority-correct and still current when delivered? | Address/announcement tests, deterministic route fixture, cancellation/supersession tests, real-ride observation. | Automated policy evidence plus physical place-continuity result. | `AddressTests`; `Announcement*Tests`; `TestRouteFixtureTests`; owner UAT. |
| QR-04 | **Audio coexistence and intelligibility:** Does speech sound clear and release other audio cleanly without a blast, stuck suppression or duplicate restart? | Audio-session ownership/release/interruption tests; stationary music/Bluetooth checks; road headset evidence. | All mandatory exact-build audio checks and at least three real-ride announcement observations. | Audio interoperability plan; speech calibration spec; TestFlight field evidence. |
| QR-05 | **Speech/content safety and quality:** Are announcement text and generated facts bounded, appropriate, useful, non-repetitive and free from unsafe route advice? | Client/proxy sanitisation tests; representative sequence review; human factual/relevance review. | Sanitisation/contract tests plus a reviewed representative content set. | `PlaceFactTests`; proxy `FactSanitizerTest`; `docs/evidence/fact-quality/`. |
| QR-06 | **Service resilience and freshness:** Do timeout, retry, cancellation, fallback and recovery paths remain bounded without late/stale output? | Mocked transient/permanent failure tests; contract tests; controlled live safe-path verification; opportunistic field observations. | Automated resilience evidence; live health/fact/speech checks; no unresolved stale/duplicate failure. | `PlaceFactTests`; proxy tests; TestFlight field evidence. |
| QR-07 | **Privacy and security:** Are consent, data minimisation, Keychain/session boundaries, request validation, retention and public-error handling correct? | Clean-install/UI tests, proxy auth/validation/retention tests, privacy audit and archive review. | Exact-build consent/credential-absence evidence; proxy security tests; current privacy audit. | Privacy audit; fact proxy contract; iOS/proxy tests. |
| QR-08 | **Accessibility and stationary usability:** Can a rider understand setup and recovery while stopped, across supported compact/orientation states and with system accessibility settings? | UI automation, screenshots, manual accessibility review and VoiceOver/Dynamic Type checks. | Clean-install/portrait/landscape evidence; focused accessibility review for changed flows. | `RideHorizonUITests`; current TestFlight evidence; future dedicated accessibility evidence. |
| QR-09 | **Performance, power and thermal behaviour:** Does an active ride remain responsive without abnormal heat, battery drain, memory growth or runaway network work? | Bounded work design, diagnostic review, 60-minute field observation and later measurement baseline. | One exact-build 60-minute owner ride with power/thermal record; no abnormal behaviour. | Ride UAT `RUAT-04`; `TF-POWER-01`. |
| QR-10 | **Compatibility and recovery:** Does the supported iPhone/iOS/headset configuration survive permission changes, Bluetooth route changes, media-services reset and poor network conditions? | Targeted framework tests, parked physical exercises and bounded compatibility matrix. | Primary-device/headset evidence; stated limits for configurations not tested. | `LocationManagerTests`; TestFlight field evidence. |
| QR-11 | **Release and compliance integrity:** Is the submitted binary the one tested, iPhone-only, signed correctly, privacy-manifest compliant and free of internal/test artefacts? | Archive/package validation, App Store review evidence, exact-build tracking. | Tested build equals processed TestFlight build; archive/review checks pass. | Backlog.md tasks RH-001/RH-002; App Store docs; TestFlight field evidence. |
| QR-12 | **Operability and diagnosis:** Can a safe diagnostic trail distinguish lifecycle/pipeline failures without collecting prohibited content? | Typed diagnostics tests, bounded retention/export tests, service request correlation and operator review. | Privacy-safe export available and enough evidence to classify a P0/P1 incident. | `RideDiagnosticsStore`; `LocationManagerTests`; audio plan. |
| QR-13 | **Future interaction and preference control:** Would a spoken question/refinement activate, recognise, ground, answer, cancel and persist safely? | Bounded intent corpus, recognition/grounding tests, privacy tests and physical microphone/audio evaluation. | Not in MVP1. No moving-rider interaction claim without explicit activation, cancellation, privacy and attention evidence. | `INTERACTIVE_TOUR_GUIDE_REFERENCE.md`; simulated-ride plan. |

## Existing automated assets

These are current foundations, not an assertion of complete coverage:

- **iOS unit tests:** address/hierarchy, announcement policy/queue, route fixture, first-run/consent, ride lifecycle, location/audio/diagnostic behaviour, fact/speech client and caching.
- **iOS UI tests:** clean-install onboarding, on-device-only/AI consent, no credential-entry UI, compact layout and landscape scrolling.
- **Fact proxy tests:** controller/validation/auth/session, request sanitisation, rate limits, provider failure mapping, prompt override boundaries and privacy retention.
- **Privacy-site tests:** routing, headers, public page separation and fixed-origin proxying.
- **Contract artefacts:** `FACT_PROXY_OPENAPI.yaml` and its human-readable contract.

## Coverage gaps to shape deliberately

The following need additional evidence as the beta expands; they are not release claims today:

1. GPX-derived deterministic replay and representative sequence-based fact-quality evaluation, including repeat and return-journey behaviour;
2. physical accessibility testing with VoiceOver, Dynamic Type, contrast and common reachability conditions;
3. measured power, memory, network-use and latency baselines over long real rides;
4. a small, disclosed compatibility matrix covering additional iPhone/iOS/headset combinations;
5. deployed service monitoring and alerting for provider capacity, upstream failure and beta degradation (already shaping in RH-033);
6. chaos/recovery exercises for deployment, database and provider outages before public launch; and
7. threat modelling, penetration testing and full App Attest enforcement before wider distribution.
