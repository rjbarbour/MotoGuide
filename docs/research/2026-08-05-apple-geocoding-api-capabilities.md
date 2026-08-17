# Apple geocoding API capabilities — research note

Date: 2026-08-05
Scope: Apple primary documentation and the locally installed Xcode 26.3 SDK only. This note does not make geographic or product-quality claims.

## Decision summary

Apple documents **no client or server API for exhaustively enumerating every `locality`, `subLocality`, `subAdministrativeArea`, or other Apple place label in a geographical region**. The available APIs perform individual forward/reverse lookups or relevance-ranked searches. The Server API search endpoint has pagination, but requires a query and describes its region as a search constraint/hint; its documentation makes no completeness guarantee. It is therefore not a place catalogue or an authoritative-boundary substitute. A small, cached, adaptive coordinate corpus is the appropriate evidence method.

Use the existing `CLGeocoder` path for the current comparison, because that is what the released application uses. Capture its full `CLPlacemark` tuple and the exact `Address` transformation. Run a separate, explicitly labelled MapKit comparison where deployment availability permits; do not assume its `MKMapItem` address representation has field-for-field equivalence with `CLPlacemark`.

## Documented API capability and limitation

| Surface | What Apple documents | Consequence for this spike |
| --- | --- | --- |
| `CLGeocoder` / `CLPlacemark` | A network-backed, single-shot forward/reverse geocoder. Reverse geocoding yields `CLPlacemark`; forward geocoding may yield multiple candidates. `CLPlacemark` exposes street, locality, sublocality, administrative areas, country and related fields. [CLGeocoder](https://developer.apple.com/documentation/corelocation/clgeocoder), [CLPlacemark](https://developer.apple.com/documentation/corelocation/clplacemark) | This is the like-for-like probe for RideHorizon. It can observe labels at selected coordinates, not enumerate labels for a region. |
| `MKGeocodingRequest` | Geocodes one address string to relevant `MKMapItem` values. It has a region setting (world by default), a preferred locale, cancellation and loading state. [MKGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest) | Suitable for forward/reverse consistency experiments, but not a settlement catalogue. Retain MapKit-native address and formatted representations as their own response shape. |
| `MKReverseGeocodingRequest` | Reverse geocodes one `CLLocation` to relevant `MKMapItem` values, with cancellation and `preferredLocale`; `nil` means device locale. [MKReverseGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest) | Suitable for a controlled migration comparison. It is not a bulk or boundary API. |
| `MKLocalSearch` / `MKAddressFilter` | Local Search accepts a natural-language query and returns map-search results. `MKAddressFilter` includes/excludes address classes, including country, administrative area, sub-administrative area, locality, sublocality and postal code. [MKLocalSearch.Request](https://developer.apple.com/documentation/mapkit/mklocalsearch/request), [MKAddressFilter.Options](https://developer.apple.com/documentation/mapkit/mkaddressfilter/options) | This filters a query's results; it cannot list all labels in an area. It may help explore a named candidate, but must not be represented as geographic ground truth. |
| Apple Maps Server API | Provides geocoding, reverse geocoding and search; it requires a JWT Maps token based on an Apple Developer Maps ID and private key. It has a 25,000 calls/day/team quota shared with MapKit JS and returns HTTP 429 over quota. [Server API overview](https://developer.apple.com/documentation/applemapsserverapi), [token requirements](https://developer.apple.com/documentation/applemapsserverapi/creating-and-using-tokens-with-maps-server-api) | Do not use: this spike must not introduce, retrieve or inspect credentials. It is not a credential-free alternative to local framework calls. |

The Server API's [`/v1/search`](https://developer.apple.com/documentation/applemapsserverapi/-v1-search) requires `q`; `searchRegion` is a region the application supplies, `enablePagination` only asks for successive result pages, and the API says results are the best available results for some or all countries when multiple countries are supplied. These documented semantics do not support an inference that the endpoint can exhaustively enumerate Apple's labels.

## Rate, caching and cancellation

Apple says `CLGeocoder` is rate-limited per app. Its rules of thumb are: at most one request for a user action; reuse a result for repeated actions at the same location; automatic updates should occur after significant movement and a reasonable time; and, in a typical case, no more than one request per minute. Exceeding the limit can yield `CLError.Code.network`. It also says not to geocode while the application is inactive or in the background. [CLGeocoder: tips for using a geocoder](https://developer.apple.com/documentation/corelocation/clgeocoder)

Therefore the harness default should remain one sequential request every 60 seconds, cache by API/operation/coordinate/locale, retry only bounded transient failures, and allow cancellation between requests. That is a conservative tooling policy based on the published Core Location guidance; Apple has not published an equivalent numeric client-framework limit for the new MapKit request classes in the cited documentation. Both MapKit request types expose `cancel()`. [MKGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest), [MKReverseGeocodingRequest](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest)

## Deprecation and migration position

Apple now marks `CLGeocoder` and the `CLPlacemark` address properties as deprecated, directing developers to MapKit (or, on relevant platforms, GeoToolbox `PlaceDescriptor`). [CLGeocoder](https://developer.apple.com/documentation/corelocation/clgeocoder), [CLPlacemark locality](https://developer.apple.com/documentation/corelocation/clplacemark/locality), [CLPlacemark sublocality](https://developer.apple.com/documentation/corelocation/clplacemark/sublocality). Apple announced the MapKit geocoding requests, `MKAddress`, and `MKAddressRepresentations` in its June 2025 MapKit update. [MapKit updates](https://developer.apple.com/documentation/updates/mapkit)

The installed SDK is Xcode 26.3 with macOS and iPhoneOS SDK 26.2. Its headers give the precise migration boundary:

- `CLGeocoder` is deprecated from iOS 26.0 and macOS 26.0, with `Use MapKit`; its reverse methods name `MKReverseGeocodingRequest` and its forward methods name `MKGeocodingRequest` as replacements (`CLGeocoder.h`, lines 23–46).
- `CLPlacemark` is marked `API_TO_BE_DEPRECATED`, directing callers to GeoToolbox `PlaceDescriptor` or MapKit (`CLPlacemark.h`, lines 27–28).
- `MKGeocodingRequest` and `MKReverseGeocodingRequest`, plus `MKMapItem`'s new `location`, `address` and `addressRepresentations`, are available from iOS/macOS 26.0 (`MKGeocodingRequest.h`, lines 14–30; `MKReverseGeocodingRequest.h`, lines 13–28; `MKMapItem.h`, lines 28–34).

These paths are under the local `MacOSX26.2.sdk` framework headers. The runner must record the SDK/OS version; any eventual app migration needs an availability-gated dual path if RideHorizon continues to support pre-26 operating systems.

Migration should be **deferred for this spike**: changing the production geocoding path would make the requested empirical comparison less useful and is outside its scope. Shape a later migration only after the corpus demonstrates whether MapKit's `MKMapItem` and `MKAddressRepresentations` preserve the rider-facing distinctions needed by the product. `MKAddress` provides full and short address strings, while `MKAddressRepresentations` offers formatted full-address, city and region forms; neither documentation claims they are a one-to-one replacement for each `CLPlacemark` component. [MKAddress](https://developer.apple.com/documentation/mapkit/mkaddress), [MKAddressRepresentations](https://developer.apple.com/documentation/mapkit/mkaddressrepresentations)

## Locale and device interpretation

Locale is an experimental variable, not metadata to omit. `CLGeocoder` provides preferred-locale overloads for forward and reverse geocoding. `MKGeocodingRequest.preferredLocale` controls the locale used to process forward requests, and `MKReverseGeocodingRequest.preferredLocale` controls returned addresses; when the latter is `nil`, MapKit uses the device locale. [CLGeocoder](https://developer.apple.com/documentation/corelocation/clgeocoder), [MKGeocodingRequest preferredLocale](https://developer.apple.com/documentation/mapkit/mkgeocodingrequest/preferredlocale), [MKReverseGeocodingRequest preferredLocale](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest/preferredlocale)

Apple does not document a guarantee that macOS and iPhone, or different OS releases and device locales, return identical label tuples. The runner should record framework/API, requested locale, effective device locale, OS build and device class. Start with a fixed `en-GB` request where supported, then make a small paired macOS/iPhone and locale comparison rather than assuming a platform difference or sweeping every locale.

## Current RideHorizon transformation: correction to the premise

The checked-in `Address.init(placemark:)` already retains `subLocality`, `locality`, `postalCode`, ISO country code, water, areas of interest, time zone and region identifier. In particular, it derives `town` by preferring a valid `subLocality`, then falling back to `locality`. The values it does not retain from the requested `CLPlacemark` capture set are none of the listed core address fields; it does not separately retain the raw `CLPlacemark` object, candidate ordering, request locale, response timestamp or service/OS provenance. Those must belong to the audit result, not the app domain model.

The implication is not an app change: the harness must show both the raw `subLocality`/`locality` pair and the derived `town`, so any ambiguity is visible. A future domain-model decision should be based on observed fixtures, not on an assumption that `subLocality` is currently discarded.

## Evidence boundaries

Apple's labels are service responses, not official administrative geography. Use official datasets to select and name the sampled sides of a boundary, then record the Apple tuple as dated, versioned observed output. Do not infer administrative truth, place completeness or product wording quality from a particular returned field.

## Sources

All external sources in this note are Apple primary documentation, accessed on 2026-08-05. The source links above are intentionally direct to the owning API documentation.
