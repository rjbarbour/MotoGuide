# Motorcycle usage evidence for the RideHorizon cost model

**Research date:** 2026-08-04
**Scope:** UK motorcycle mileage, journey purpose and evidence relevant to long recreational rides and touring.
**Source policy:** UK Department for Transport (DfT) primary statistical releases and workbooks only.

## Bottom line

The official evidence supports a segmented, heavy-tailed usage model rather than one “average rider”:

- An active English motorcyclist has historically ridden roughly 4,000–5,000 miles per year, depending on definition, age and period.
- More than 10,000 miles in a year is well above the active-rider average and appears to sit within the upper few per cent of motorcycles in the latest available mileage-band distribution.
- Only 20% of motorcycle mileage was classified directly as day trips and holidays in the available purpose analysis. Another 16% was visiting friends and other social activity. Neither figure is equivalent to RideHorizon-eligible mileage.
- Current Great Britain road-traffic data is dominated by roads where settlement exposure is likely to differ from motorway riding: 52% of motorcycle miles were on minor roads, 42% on A roads and 6% on motorways in 2025.
- The official sources do not provide a reliable representative distribution of 300-mile ride-days, 500-mile touring days or multi-country tours. Those must remain explicit target-segment assumptions until RideHorizon has rider survey or telemetry data.

## Direct facts

### Annual mileage and the high-mileage tail

The DfT's 2016 motorcycle factsheet reported that people who recorded at least one motorcycle journey during their seven-day National Travel Survey (NTS) diary made about 400 motorcycle trips and travelled about 4,100 miles per year on average over the preceding decade. The 2016 point estimates were 438 trips, 4,838 miles, 11 miles per trip and 28 minutes per trip. The factsheet warns that only about 100–140 motorcyclists appeared in the annual NTS sample, so detailed results aggregate multiple years. [DfT, *Motorcycle use in England*](https://assets.publishing.service.gov.uk/media/5aba5332ed915d78bc2348f2/motorcycle-use-in-england.pdf)

A later DfT workbook aggregates 2002–2023. Among male respondents who rode during their diary week, estimated annual distance was 4,819 miles for ages 30–39, 4,730 miles for ages 40–49 and 4,703 miles for ages 50–59. The workbook explicitly warns that the number of motorcycle users is relatively small and defines a rider by recorded use during one diary week. [DfT NTSQ09064 workbook](https://assets.publishing.service.gov.uk/media/689b6448ebe5217ba73d0c6a/ntsq09064.ods)

The latest available motorcycle mileage-band table covers 2018–2019 and measures estimated annual mileage per motorcycle or moped. Its published percentages were:

| Annual mileage band | Motorcycles and mopeds |
|---|---:|
| 0–499 miles | 21% |
| 500–999 miles | 7% |
| 1,000–1,999 miles | 20% |
| 2,000–2,999 miles | 16% |
| 3,000–3,999 miles | 13% |
| 4,000–4,999 miles | 7% |
| 5,000–6,999 miles | 12% |
| 7,000–8,999 miles | 3% |
| 9,000–11,999 miles | 1% |
| 12,000–14,999 miles | 1% |
| 15,000–17,999 miles | Less than 0.5% |
| 18,000 miles and over | 0% in the rounded table |

The unweighted sample was 305 motorcycles across two survey years. Mileage was estimated by respondents, the table includes mopeds, and displayed percentages are rounded. [DfT NTSQ09048 workbook](https://assets.publishing.service.gov.uk/media/689b6442eb300a86d83d0c67/ntsq09048.ods)

**Inference:** a rider doing more than 10,000 miles on one motorcycle is plausibly in the upper few per cent of this historical vehicle-mileage distribution and is riding more than twice the roughly 4,700–4,800-mile active-rider benchmark for middle-aged men. This is directional, not a current population percentile: the measures, units and periods differ.

### Journey purpose and potential app-eligible mileage

For 2002–2016, DfT estimated the following shares of motorcycle mileage by purpose:

| Purpose | Share of motorcycle mileage |
|---|---:|
| Commuting and business | 52% |
| Day trips and holidays | 20% |
| Visiting friends and other social activities | 16% |
| Personal business and other | 6% |
| Shopping | 5% |
| Education, including escorting | 2% |

Values are rounded. The analysis used 14,000 unweighted motorcycle stages aggregated across 2002–2016. [DfT NTSQ03002 workbook](https://assets.publishing.service.gov.uk/media/5e1f344d40f0b61142162574/ntsq03002.ods)

**Inference:** 20% is the closest observed baseline for explicitly recreational mileage, but it is not an app-activation rate. Some social rides may be long and unfamiliar; some holiday mileage may be familiar, transport-oriented or unsuitable for audio. Adding all social mileage produces a broad 36% upper reference, not an observed share of RideHorizon-eligible mileage. The target touring segment may have a much higher recreational share than the all-rider population.

### Road-type mix

DfT estimates that motorcycles and scooters travelled 3.0 billion vehicle miles on Great Britain's roads in 2025, 13.1% more than in 2019. The road-type split was 52% minor roads, 42% A roads and 6% motorways. The category includes motorcycles, scooters and mopeds; it does not separate journey purpose or rider type. [DfT, *Road traffic estimates in Great Britain, 2025: Traffic by vehicle type*, published 2026-05-20](https://www.gov.uk/government/statistics/road-traffic-estimates-in-great-britain-2025/road-traffic-estimates-in-great-britain-2025-traffic-in-great-britain-by-vehicle-type)

**Inference:** a UK base persona should not be modelled as predominantly motorway riding. Announcement density should be scenario-weighted by minor-road, A-road and motorway exposure. A European transit day needs a different route mix from the UK aggregate.

### Long trips and touring

The 2023 NTS trip-length cross-tab for England excluding London reported that 10% of motorcycle trips exceeded 25 miles, 3% exceeded 50 miles and 1% exceeded 100 miles. The unweighted motorcycle trip sample rounded to zero thousand in the workbook, so these tail estimates are especially fragile. [DfT NTSQ09071 workbook](https://assets.publishing.service.gov.uk/media/689b644bebe5217ba73d0c6d/ntsq09071.ods)

These figures cannot be treated as ride-day lengths. NTS defines a trip as a one-way course of travel with one main purpose; returns and meaningful intermediate-purpose changes become separate trips. Its diary covers English residents' travel within Great Britain, while the separate respondent estimate of annual vehicle mileage can include travel abroad. [DfT, *NTS 2024: Notes and definitions*, published 2025-08-27](https://www.gov.uk/government/statistics/national-travel-survey-2024/nts-2024-notes-and-definitions) [DfT, *Motorcycle use in England*](https://assets.publishing.service.gov.uk/media/5aba5332ed915d78bc2348f2/motorcycle-use-in-england.pdf)

**Finding:** no DfT source located in this review provides a reliable representative distribution for all-day recreational mileage, European motorcycle-tour distance, touring days per year or peak daily distance. A rider's 300-mile day may also be split into several NTS trips around café, fuel and meal stops.

## Recommended modelling use

Use the evidence as anchors, not as finished personas:

1. Model annual motorcycle miles first.
2. Split those miles by ride purpose and route archetype.
3. Apply the proportion of qualifying rides on which the rider actually starts RideHorizon.
4. Estimate geocoded transition events per 100 miles separately for minor-road/scenic, A-road/mixed and motorway/transit riding.
5. Apply product coalescing, suppression and delivery rates to obtain spoken announcements.
6. Cost the resulting facts, searches and TTS characters.

Suggested evidence-backed anchors:

- **Broad active-rider anchor:** approximately 4,000–5,000 annual motorcycle miles.
- **High-mileage target anchor:** more than 10,000 annual miles, treated as an upper-tail cohort rather than “above average”.
- **Explicit recreational baseline:** 20% of mileage for day trips and holidays in the 2002–2016 all-rider data.
- **Broad leisure-related reference:** up to 36% when all social mileage is added, with a warning that this is not app-eligible mileage.
- **UK road-mix baseline:** 52% minor road, 42% A road and 6% motorway in 2025.
- **Tour-year spike:** model separately from an ordinary year. Do not smooth a multi-thousand-mile European tour evenly over twelve months when testing monthly provider caps or cash exposure.

The reported personal pattern of weekly 300-mile recreational rides, more than 10,000 annual miles and occasional roughly 5,000-mile European tours should therefore be an explicit high-use persona and tour-year stress case. It should not determine the median persona, but it is commercially important because provider cost is driven by the usage tail.

## Dataset limitations

- NTS motorcycle samples are small; several detailed tables pool many years.
- The most useful motorcycle-purpose analysis covers 2002–2016, not current behaviour.
- “Motorcycle” commonly includes scooters and mopeds, and some tables include passengers.
- Rider mileage, vehicle mileage and Great Britain road-traffic totals are different measures and must not be mixed without qualification.
- The NTS travel diary covers residents of England and travel within Great Britain; it does not observe complete European tours.
- Respondent annual vehicle-mileage estimates can include overseas travel but are self-reported.
- Trip statistics describe purpose-defined one-way trips, not complete recreational ride-days.
- Road-traffic estimates cover all purposes and riders and cannot identify the RideHorizon target segment.
- None of these sources measures locality-label changes, administrative-boundary crossings, announcement suppression, app activation or TTS characters. Those require route sampling and RideHorizon telemetry.

## Sources

- [DfT motorcycle-use factsheet](https://assets.publishing.service.gov.uk/media/5aba5332ed915d78bc2348f2/motorcycle-use-in-england.pdf)
- [DfT ad-hoc NTS analysis catalogue, updated 2026-02-05](https://www.gov.uk/government/statistical-data-sets/ad-hoc-national-travel-survey-analysis)
- [DfT 2025 road-traffic motorcycle analysis](https://www.gov.uk/government/statistics/road-traffic-estimates-in-great-britain-2025/road-traffic-estimates-in-great-britain-2025-traffic-in-great-britain-by-vehicle-type)
- [DfT NTS 2024 notes and definitions](https://www.gov.uk/government/statistics/national-travel-survey-2024/nts-2024-notes-and-definitions)

All sources were accessed on 2026-08-04.
