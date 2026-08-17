# Apple place labels and UK boundary-test data

Date: 2026-08-05

## Bottom line

Apple does not document a public API that enumerates every `locality`, `subLocality` or `subAdministrativeArea` in a region, or one that supplies Apple's administrative boundary polygons. This conclusion is an inference from the documented API surface: Apple's reverse geocoders accept supplied coordinates, while local search requires a query and returns matches rather than a complete place hierarchy. [Apple `CLGeocoder`](https://developer.apple.com/documentation/corelocation/clgeocoder) [Apple `MKReverseGeocodingRequest`](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest) [Apple `MKLocalSearch.Request`](https://developer.apple.com/documentation/mapkit/mklocalsearch/request)

Do not use a dense coordinate grid against `CLGeocoder`. Apple says the service is rate-limited, advises significant movement and elapsed time between automatic requests, and gives one request per minute as the typical rule of thumb. [Apple `CLGeocoder` usage guidance](https://developer.apple.com/documentation/corelocation/clgeocoder)

The useful approach for RideHorizon is therefore:

1. Use an authoritative UK boundary dataset to select known administrative crossings.
2. Create a small number of coordinates on each side of each boundary, preferably on the real road or GPX path.
3. Reverse-geocode those coordinates through the same Apple API and locale used by the app.
4. Record Apple's returned place tuple and probe more closely only where the tuple changes.
5. Replay the captured fixtures off-bike. Reserve the ride test for GPS behaviour, timing, networking, background operation and audio interoperability.

This distinguishes two questions that should not be conflated:

- **Where is the official administrative boundary?** Use authoritative UK polygons.
- **What labels will Apple's geocoder return at a coordinate?** Measure Apple's service empirically.

## What Apple provides

### Reverse geocoding

The existing Core Location API is:

```swift
func reverseGeocodeLocation(
    _ location: CLLocation,
    preferredLocale: Locale?,
    completionHandler: @escaping ([CLPlacemark]?, (any Error)?) -> Void
)
```

`CLPlacemark` exposes `locality`, `subLocality` and `subAdministrativeArea`. Apple defines these loosely as a city, additional city-level information such as a neighbourhood or common name, and additional administrative-area information. They are descriptive placemark fields, not a published UK administrative ontology. [Apple `CLGeocoder`](https://developer.apple.com/documentation/corelocation/clgeocoder) [Apple `locality`](https://developer.apple.com/documentation/corelocation/clplacemark/locality) [Apple `subLocality`](https://developer.apple.com/documentation/corelocation/clplacemark/sublocality) [Apple `subAdministrativeArea`](https://developer.apple.com/documentation/corelocation/clplacemark/subadministrativearea)

The current RideHorizon `Address.init(placemark:)` maps `thoroughfare`, `locality`, `subAdministrativeArea`, `administrativeArea` and `country`; it does not retain `subLocality`. Therefore an Apple response that places “Surbiton” or another neighbourhood only in `subLocality` cannot currently be displayed or announced by RideHorizon. The proposed fixture must retain both the raw Apple tuple and the derived RideHorizon address so this loss is visible before deciding whether the product model should change.

Apple's newer MapKit API, introduced in 2025, is `MKReverseGeocodingRequest(location:)`; the request returns `MKMapItem` results for the supplied location. It is still coordinate-driven, not an area-enumeration API. [Apple `MKReverseGeocodingRequest`](https://developer.apple.com/documentation/mapkit/mkreversegeocodingrequest) [Apple MapKit updates](https://developer.apple.com/documentation/updates/mapkit)

### Search is not enumeration

`MKLocalSearch.Request` takes a natural-language query and a map region. The region narrows or prioritises the query; it does not ask Apple to return every named division in the region. `MKAddressFilter.Options` can constrain results to types including `.locality`, `.subLocality` and `.subAdministrativeArea`, but the result remains a set of search matches. [Apple `MKLocalSearch.Request`](https://developer.apple.com/documentation/mapkit/mklocalsearch/request) [Apple `MKAddressFilter.Options`](https://developer.apple.com/documentation/mapkit/mkaddressfilter/options)

Apple Maps Server API likewise documents search and reverse-geocoding services, not an administrative-place catalogue or boundary export. [Apple Maps Server API](https://developer.apple.com/documentation/applemapsserverapi)

## Authoritative UK sources

### Administrative boundary polygons

Use Ordnance Survey **Boundary-Line** for automated administrative-transition fixtures. OS describes it as mapping every administrative and electoral boundary in Great Britain. It is free, updated twice yearly, mapped at 1:10,000 and available as Shapefile, GeoPackage, GML, MapInfo TAB and vector tiles. [OS Boundary-Line](https://www.ordnancesurvey.co.uk/products/boundary-line) [Boundary-Line product information](https://www.ordnancesurvey.co.uk/documents/product-support/user-guide/boundary-line-product-information-v5.0.pdf)

ONS's Open Geography Portal is also an authoritative route to current statistical-geography boundary products and provides a catalogue API. It is useful where fixtures need ONS geography codes and versioned statistical boundary releases. [ONS Open Geography Portal Search API](https://geoportal.statistics.gov.uk/api/search/definition/)

### Settlement names and extents

Use **OS Open Names** to seed recognised settlement names and representative coordinates. The OS Names API covers nearly 44,000 settlements and supports string lookup or nearest-feature lookup. It is a gazetteer, not a settlement-boundary service. OS's technical specification explains that settlement geometry is a notional centre or a point generated from a major road junction. [OS Names API](https://www.ordnancesurvey.co.uk/products/os-names-api) [OS Open Names technical specification](https://www.ordnancesurvey.co.uk/documents/product-support/tech-spec/os-open-names-technical-specification-v2.2.pdf)

**OS Open Built Up Areas** provides polygons for built-up extents and is useful for statistical settlement coverage, but those extents should not be treated as predictions of Apple's `locality` or `subLocality` values. OS says the dataset represents built-up areas and was designed to underpin statistical analysis and public policy. [OS Open Built Up Areas](https://www.ordnancesurvey.co.uk/products/os-open-built-up-areas)

## Elmbridge, Kingston and Richmond

The relevant official local-authority relationships are:

- Elmbridge (`E07000207`) is a non-metropolitan district in Surrey. [ONS Elmbridge profile](https://www.ons.gov.uk/explore-local-statistics/areas/E07000207-elmbridge)
- Kingston upon Thames (`E09000021`) is a borough in London. [ONS Kingston upon Thames profile](https://www.ons.gov.uk/explore-local-statistics/areas/E09000021-kingston-upon-thames)
- Richmond upon Thames (`E09000027`) is a borough in London. [ONS Richmond upon Thames profile](https://www.ons.gov.uk/explore-local-statistics/areas/E09000027-richmond-upon-thames)

Lovelace Road crosses the Kingston–Elmbridge boundary. A Surrey County Council report describes Kingston's controlled parking zone extending along Lovelace Road up to the Elmbridge boundary; the same report covers the adjacent Long Ditton area in Elmbridge. [Surrey County Council Elmbridge Local Committee report](https://mycouncil.surreycc.gov.uk/Data/Elmbridge%20Local%20Committee/20060124/Agenda/item%2011.pdf)

Hampton Court Bridge is not another Kingston–Elmbridge crossing. It links Elmbridge to Richmond upon Thames: the two councils' statement of common ground says Richmond lies north of Elmbridge, the Thames separates them, and Hampton Court Bridge is their only road link. Richmond's conservation-area appraisal also says half of the bridge lies within its conservation area because of the borough boundary. [Elmbridge–Richmond statement of common ground](https://www.elmbridge.gov.uk/sites/default/files/2023-08/CD021%20-%20Statement%20of%20Common%20Ground%20with%20London%20Borough%20of%20Richmond%20upon%20Thames%20-%20July%202023_0.pdf) [Richmond Hampton Court Green appraisal](https://www.richmond.gov.uk/services/planning/conservation_and_urban_design/conservation_areas/hampton_court_green_conservation_area_appraisal)

Therefore Hampton Court Bridge is a useful second **same-class** administrative test—Surrey/Elmbridge to London/Richmond rather than Surrey/Elmbridge to London/Kingston—but it does not add a new hierarchy level. It may still return different Apple locality labels, which must be measured rather than inferred from council boundaries.

## Recommended automated fixture method

For each candidate crossing:

1. Version the source boundary dataset and retain its geography codes.
2. Intersect the boundary with the intended road or GPX polyline.
3. Generate a small transect: for example, two points safely inside each side plus one near the intersection.
4. Reverse-geocode sequentially at a compliant rate using the app's locale.
5. Persist the coordinate, timestamp, OS/iOS version, locale and returned `name`, `thoroughfare`, `subLocality`, `locality`, `subAdministrativeArea`, `administrativeArea` and `country` fields.
6. If a returned tuple changes between samples, use bounded midpoint probing to bracket the transition. Do not sweep the whole borough with a uniform grid.
7. Turn the observed sequence into a replay fixture for announcement-policy and display tests.

The Apple result should be treated as an observed, versioned dependency response, not timeless ground truth. The official polygon identifies the administrative crossing; the Apple sample identifies what RideHorizon will actually receive.

## Implication for ride UAT

Neither locality resolution nor fact quality needs to consume road-test time. Known administrative crossings and Apple-label sequences can be exercised with coordinate fixtures, and fact modes can be compared using GPX replay.

The real ride should test only what static or automated testing cannot reproduce confidently:

- real GPS accuracy, jitter and delayed updates while moving;
- background and locked-phone continuity;
- mobile-network interruption and recovery;
- announcement timing and usefulness at riding speed;
- helmet intelligibility and interaction with music and navigation audio;
- rider distraction, trust and safe operability.
