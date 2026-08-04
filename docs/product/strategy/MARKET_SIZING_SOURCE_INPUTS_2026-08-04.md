# RideHorizon market-sizing source inputs

**Research date:** 2026-08-04
**Purpose:** defensible inputs for a UK-first, iOS-only commercial model. These figures are market ceilings, not forecasts of RideHorizon users.

## Recommended vehicle-stock anchors

| Market | Stock anchor | Date and definition | Source and interpretation |
|---|---:|---|---|
| UK | **1,355,000** | End of 2024; motorcycles licensed for road use, UK | [Department for Transport accredited official statistics](https://www.gov.uk/government/statistics/vehicle-licensing-statistics-2024/vehicle-licensing-statistics-united-kingdom-2024). This excludes motorcycles on SORN and is the cleanest UK road-active stock proxy. A registered keeper is not necessarily the rider. |
| Europe, including the UK | **More than 40,000,000** | 2023; powered two-wheelers | [ACEM, *The safe ride to the future 3.0*, pp. 6 and 34](https://www.ancma.it/wp-content/uploads/2025/05/ACEM_SafetyStrategy_3.0.pdf). ACEM describes growth from 28.3 million in 2000 to more than 40 million in 2023. This is a rounded industry estimate, includes mopeds, and does not publish a country reconciliation in this document. Treat the UK as included: do not add the UK again. |
| United States | **9,261,249** | 2024; state-reported registered motorcycles, private/commercial plus public | [Federal Highway Administration, Highway Statistics 2024, table MV-1](https://www.fhwa.dot.gov/policyinformation/statistics/2024/pdf/mv1.pdf). The table notes that some states did not report one or more publicly owned vehicle types; the effect is immaterial for this consumer ceiling. |
| Canada | **857,861** | 2024; active motorcycles and mopeds | [Statistics Canada table 23-10-0308-01](https://doi.org/10.25318/2310030801-eng), with the [downloadable source dataset](https://www150.statcan.gc.ca/n1/tbl/csv/23100308-eng.zip). The table is compiled from provincial and territorial administrative files. Motorcycles and mopeds are combined. |
| Australia | **981,068** | 2025-01-31; motorcycles registered for road use | [BITRE, *Road Vehicles Australia, January 2025*, table 1](https://www.bitre.gov.au/sites/default/files/documents/BITRE-Road-vehicles-Australia-January-2025--september2025--pdf.pdf). BITRE estimates from the registration fleet; this series replaced the discontinued ABS Motor Vehicle Census. |
| New Zealand | **About 175,000** | Ministry workpaper published 2023; motorcycle registrations | [New Zealand Ministry of Transport, *Domestic Transport Costs and Charges: Road Vehicle Operating Costs*, p. 25](https://www.transport.govt.nz/assets/Uploads/DTCC-WP-C5-Road-VOC-June-2023.pdf). Use only as a rounded anchor. The Ministry's [current annual fleet series](https://www.transport.govt.nz/statistics-and-insights/fleet-statistics/sheet/annual-fleet-statistics) defines motorcycles to include motorcycles and mopeds and excludes off-road-exempt and non-roadworthy/restoration-licensed vehicles, but its current dashboard does not expose a stable headline total in the page HTML. |

### Additive regional ceilings without double counting

- **North America:** 10,119,110 registered motorcycles/mopeds = US + Canada.
- **Australasia:** about 1,156,068 = Australia + rounded New Zealand anchor.
- **Anglophone markets outside Europe:** about 11,275,178 = US + Canada + Australia + New Zealand. The UK is deliberately excluded because it is inside the European anchor.
- **Core Anglophone plus Europe:** **more than 51,275,178 powered two-wheelers** = Europe, including UK, + US + Canada + Australia + New Zealand.

This 51.3 million figure is a broad vehicle ceiling, not a count of unique owners, active riders, tourers, English speakers, smartphone users or likely buyers. Definitions also differ: Europe, Canada and New Zealand include mopeds; other sources use their domestic motorcycle registration classes.

## Rider and touring-intent proxies

Vehicle stock is preferable to licence entitlement for the base model. A licence can remain valid long after someone stops riding, while one rider can own several motorcycles.

- Australia is a useful illustration: BITRE counted **2,463,364 motorcycle licence holders at 2024-06-30**, versus 972,727 registered motorcycles in its 2024 vehicle-stock series. The licence total is therefore an interest/eligibility ceiling, not an active-rider estimate. Source: [BITRE, *Australian Infrastructure and Transport Statistics Yearbook 2024*, table 6.15i](https://www.bitre.gov.au/sites/default/files/documents/australian-infrastructure-and-transport-statistics--yearbook-2024--january-2025.pdf).
- UK new-registration mix gives a practical touring/adventure proxy. MCIA reports **23,394 Adventure** and **2,196 Touring** motorcycles registered in 2024, out of **110,644 motorcycles**: 25,590 combined, or **23.1%**. Source: [MCIA December 2025 report, which provides the 2024 comparators](https://mcia.co.uk/downloads/download/2050). This is a flow mix of new motorcycles, not the installed fleet and not proof that every adventure-bike owner tours.
- As a starting model range, apply a **10% / 20% / 30% touring-or-unfamiliar-ride relevance rate** to road-active stock. The 23.1% UK new-bike proxy supports 20% as a reasonable central assumption, but it should be validated with RideHorizon interviews and landing-page conversion rather than treated as fact.
- Developer-supplied app-store claims show that motorcycle-specific apps can reach meaningful scale: calimoto states **more than 3 million riders**; Scenic states **30 million hours ridden** and **200,000+ user-designed routes**. Sources: [calimoto US App Store listing](https://apps.apple.com/us/app/calimoto-motorcycle-navigation/id1209129603) and [Scenic UK App Store listing](https://apps.apple.com/gb/app/scenic-motorcycle-navigation/id1089668246). These are marketing claims, not audited active-user counts.

## iOS reach: use as a sensitivity, not a hard multiplier

Statcounter's 2026-07 mobile-web-traffic shares are **UK 53.92%**, **Europe 39.54%**, **US 59.58%**, **Canada 65.91%**, **Australia 63.70%**, and **New Zealand 55.86%**. Sources: [UK](https://gs.statcounter.com/os-market-share/mobile/united-kingdom), [Europe](https://gs.statcounter.com/os-market-share/mobile/europe), [US](https://gs.statcounter.com/os-market-share/mobile/united-states-of-america), [Canada](https://gs.statcounter.com/os-market-share/mobile/canada), [Australia](https://gs.statcounter.com/os-market-share/mobile/australia), and [New Zealand](https://gs.statcounter.com/os-market-share/mobile/new-zealand).

Naively applying those shares gives the following iOS-visible stock proxies:

| Market | Naive iOS-visible vehicle proxy |
|---|---:|
| UK | 730,616 |
| Europe, including UK | More than 15,816,000 |
| US | 5,517,852 |
| Canada | 565,416 |
| Australia | 624,940 |
| New Zealand | About 97,755 |
| Core Anglophone plus Europe, with no UK double count | **More than 22,621,964** |

Statcounter measures web requests, not device installed base, unique people or motorcyclists. Touring riders may skew older and wealthier than the general mobile population, so the true rider iOS share could differ materially. Run the commercial model at **35% / 50% / 65% iOS reach** rather than presenting 22.6 million as a measured TAM.

## Comparable consumer pricing

Current App Store list prices put specialised motorcycle apps around **£50 per year** in the UK and **US$25–80 per year** in the US:

- Scenic: **£49.90/year**, £12.90/month or £24.90/quarter. [UK App Store](https://apps.apple.com/gb/app/scenic-motorcycle-navigation/id1089668246).
- Detecht: **£49.99/year**, with monthly offers shown at £6.49–£8.99. [UK App Store](https://apps.apple.com/gb/app/detecht-motorcycle-gps-app/id1373032762).
- Detecht: **US$59.99/year** in the US. [US App Store](https://apps.apple.com/us/app/detecht-motorcycle-app-gps/id1373032762).
- calimoto: **US$79.99/year** is the principal annual price shown, alongside historical/alternative purchases. [US App Store](https://apps.apple.com/us/app/calimoto-motorcycle-navigation/id1209129603).
- Kurviger Tourer+: **US$24.99/year** or US$5.99/month. [US App Store](https://apps.apple.com/us/app/kurviger-motorcycle-navigation/id6473445827).

These products mainly sell route planning/navigation, safety, tracking or community. RideHorizon is an ambient geographic-awareness companion, so the figures establish willingness to pay in the category but not price parity. A defensible initial test is **£29.99–£49.99/year**, with usage-limited AI facts or premium speech priced so variable content/TTS cost cannot create negative gross margin.

## Model caveats and exclusions

- Do not call registered vehicles "riders" or "users".
- Do not add the 1.355 million UK stock to the 40 million European figure.
- Do not add licence holders to registered vehicles. Use licences only as an upper-bound cross-check.
- Do not infer active touring behaviour directly from adventure/touring motorcycle ownership.
- The broad European estimate is the weakest large-market anchor because it is rounded and combines powered two-wheelers. A later investment-grade model should replace it with country-level national registration stocks and reconcile mopeds consistently.
- No defensible, current, globally comparable road-active motorcycle stock was found in the same definitions. A worldwide total would be dominated by Asian utility two-wheelers outside the stated target market and would make RideHorizon's commercial TAM look larger while becoming less decision-useful.
