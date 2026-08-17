# Apple place-label audit findings

Date: 2026-08-05
Status: completed bounded off-bike spike
Scope: public synthetic coordinates, macOS command-line `CLGeocoder`, requested locale `en_GB`. This is not a legal-boundary survey, a route recommendation, a product wording review or iPhone evidence.

## Decision summary

Apple offers no documented API that exhaustively enumerates its regional locality catalogue. The practical evidence method is therefore a small, cached, adaptive corpus: official geography selects the comparison; Apple responses show the observed service tuple; RideHorizon’s `Address` shows the current derived hierarchy.

The `Address` premise in the original question was stale. `Address.init(placemark:)` already retains both `subLocality` and `locality`, and derives `town` by preferring a valid `subLocality`. There is no `subLocality` loss to fix in the current domain model. The observed risk is semantic: Apple sometimes supplies a broad locality alongside a narrower sublocality, and the app currently always selects the latter.

Do not change the app in this spike. Defer a production migration from `CLGeocoder` to MapKit: the installed SDK deprecates Core Location geocoding from iOS/macOS 26, but this audit deliberately characterises the released `CLGeocoder` path first. Shape a separate availability-gated comparison when iPhone evidence can be collected.

## Sources and method

- [Apple API capabilities note](2026-08-05-apple-geocoding-api-capabilities.md) records the Apple-primary evidence: individual lookup APIs, not enumeration; `CLGeocoder`'s one-request-per-minute guidance; Maps Server API token requirement; and the iOS/macOS 26 migration boundary.
- [OS Boundary-Line](https://www.ordnancesurvey.co.uk/products/boundary-line) is the authoritative future source for validating an administrative crossing. No bulk geographic dataset was downloaded in this spike; the manifest records that fact, source version status and licence for every prospective source.
- [ONS Elmbridge profile](https://www.ons.gov.uk/explore-local-statistics/areas/E07000207-elmbridge), [Kingston profile](https://www.ons.gov.uk/explore-local-statistics/areas/E09000021-kingston-upon-thames), and [Richmond profile](https://www.ons.gov.uk/explore-local-statistics/areas/E09000027-richmond-upon-thames) provide the local-authority names/codes used as official comparison context.
- The canonical public-synthetic [manifest](../../fixtures/geography/apple-place-audit/manifest-2026-08-05-v1.json), cached [raw results](../../fixtures/geography/apple-place-audit/results-2026-08-05-v1.json), and generated [comparison](../../fixtures/geography/apple-place-audit/comparison-2026-08-05-v1.md) are the reproducible evidence.

Requests were sequential, cached and at least 60 seconds apart. The final cache has 27 successful requests: six boundary candidates, eight forward-then-reverse settlement checks (16 requests), four initial higher-level points and one Wales replacement. The runner safely resumed after interrupted processes, skipping completed rows.

## Apple API answer

`CLGeocoder` and `CLPlacemark` return individual forward/reverse candidates. `MKGeocodingRequest` and `MKReverseGeocodingRequest` respectively return relevant `MKMapItem` values for one address string or coordinate. `MKLocalSearch` with `MKAddressFilter` filters a natural-language query; it does not enumerate a geographic catalogue. Apple Maps Server API has geocoding/search operations but needs a JWT token derived from an Apple Developer Maps ID and private key, so it was deliberately not used. None is documented as an exhaustive enumerator of `locality`, `subLocality` or `subAdministrativeArea` values. See the API note for direct Apple references.

The installed Xcode 26.3 / SDK 26.2 headers deprecate `CLGeocoder` from iOS/macOS 26 and direct forward and reverse calls to `MKGeocodingRequest` and `MKReverseGeocodingRequest`. MapKit's new address model is not documented as a component-for-component `CLPlacemark` replacement. A migration now would confound the current comparison and is out of scope.

## Observed results

All results below are a versioned macOS observation on `2026-08-05`, not permanent Apple behaviour or an official-geography claim.

### Lovelace Road candidate set

All three public candidate points returned the same relevant tuple: `locality = Surbiton`, `subLocality = Kingston upon Thames`, `subAdministrativeArea = London`, `administrativeArea = England`, country `United Kingdom` / `GB`. The current `Address` derives `town = Kingston upon Thames`.

This does **not** prove the candidates cross the Kingston/Elmbridge boundary; rather, it proves they do not yet bracket an observed Apple tuple change. Do not retain them as an administrative regression fixture until a dated Boundary-Line intersection produces verified points on each side.

### Hampton Court Bridge candidate set

The two southern/candidate points returned `locality = East Molesey`, `subLocality = Molesey East`, `subAdministrativeArea = Surrey`; `Address.town` therefore becomes `Molesey East`. The northern point returned `locality = East Molesey`, `subLocality = Richmond upon Thames`, `subAdministrativeArea = London`; `Address.town` becomes `Richmond upon Thames`.

This is useful empirical evidence of an Apple tuple change across the documented Elmbridge/Richmond crossing class. It remains a candidate fixture until the coordinates are validated against a dated OS polygon.

### Settlement forward/reverse consistency

For this single platform/locale observation, the first forward candidate and reverse lookup were internally consistent:

| Requested settlement | Apple locality | Apple sublocality | Current `Address.town` |
| --- | --- | --- | --- |
| Long Ditton | Surbiton | Long Ditton | Long Ditton |
| Thames Ditton | Thames Ditton | Thames Ditton | Thames Ditton |
| Hinchley Wood | Esher | Hinchley Wood | Hinchley Wood |
| Esher | Esher | Esher | Esher |
| Claygate | Esher | Claygate | Claygate |
| East Molesey | East Molesey | Molesey East on reverse result | Molesey East |
| Surbiton | Surbiton | Kingston upon Thames | Kingston upon Thames |
| Kingston upon Thames | Kingston Upon Thames | Kingston upon Thames | Kingston upon Thames |

This shows why product semantics must remain separate from the raw hierarchy. `subLocality` may be a useful rider-facing place (Long Ditton, Claygate, Hinchley Wood); it can also use a form that differs from the named settlement (Molesey East), or select Kingston upon Thames for a Surbiton query. The evidence does not decide which wording is best.

### Higher-level points

The England candidate returned `administrativeArea = England`, whereas the initial intended Wales candidate returned `administrativeArea = England` and `subLocality = Tidenham`; it was correctly retained as a failed side-selection candidate. A bounded replacement returned `Chepstow`, `Monmouthshire`, `Wales`. The Dover and Calais points returned `United Kingdom` / `GB` and `France` / `FR` respectively.

The retained country/nation examples are therefore useful for current hierarchy transformation, but they are not a substitute for verified near-boundary transects.

## Device and locale scope

No iPhone or alternate-locale request was made. There is therefore no evidence of macOS/iPhone or locale equivalence or difference. Apple does not document such an equivalence guarantee. A follow-up should run a small paired subset—Hampton Court north/south, Long Ditton, Surbiton and the England/Wales pair—on the physical iPhone using the release app locale and an intentionally different requested locale where the API permits it.

## Recommended retained fixtures and next gate

Retain the dated raw Apple observations and the following *candidate* replay order: Hampton Court south → bridge candidate → north; Long Ditton; Hinchley Wood; Claygate; East Molesey; Surbiton; Kingston upon Thames; England → Wales replacement; Dover → Calais. The raw results are evidence, not permanently asserted live-service unit-test values.

Before promoting a boundary candidate to a deterministic application fixture:

1. Download and record a dated OS Boundary-Line release and OGL attribution.
2. Intersect the actual public road or synthetic transect with the polygon.
3. Generate two points safely inside each verified side and one near the intersection.
4. Run only the new points through the existing cache/rate-limit runner.
5. Freeze the observed `CLPlacemark` tuple and `Address` tuple separately for deterministic policy/display tests.

## Recommendation

Do **not** add `subLocality` to the RideHorizon domain model: it is already present and already drives `town`. A future product decision may add a distinct display/announcement selection policy if riders find an Apple-selected `subLocality` misleading, but that should be shaped against this corpus and human review rather than treated as a missing-field defect.

Defer the MapKit migration. It is required planning work because of the SDK deprecation, but it should be a separate narrow increment that runs the same small corpus through both APIs, preserves MapKit-native address representations and proves availability behaviour on the supported OS range. No migration is justified by this audit alone.

## Deliberately deferred work

- OS Boundary-Line download/intersection and promotion of candidate points to official boundary fixtures.
- Paired iPhone and locale observations.
- MapKit request implementation/comparison.
- Any change to `Address`, product wording, facts, TestFlight build or road-test protocol.
