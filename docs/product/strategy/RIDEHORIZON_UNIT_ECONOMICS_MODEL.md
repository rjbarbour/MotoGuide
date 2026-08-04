# RideHorizon Marginal Unit-Economics Model

Date: 2026-08-04

Status: Early planning model. The usage chain is explicit, but boundary density and app-use rates remain hypotheses until private-beta rides measure them.

## Bottom Line

The earlier assumption of 12 announcements per ride was too blunt. It ignored ride distance, route type and the fact that riders are more likely to use RideHorizon on selected recreational and touring rides than on every journey.

This revision models:

```text
eligible ride-days
    × miles per ride
    × proportion of eligible rides using RideHorizon
    × delivered announcements per 100 miles
    × content and provider cost per announcement
```

Under the base assumptions:

- a 300-mile mixed/scenic day produces about **31 delivered announcements**, not 12;
- a 500-mile European transit day produces about **37** because motorways expose fewer useful locality changes per mile;
- a 1,200 km day produces about **56** at the same European route mix;
- a 5,000-mile European tour produces about **372**; and
- a Rob-like high-mileage profile produces about **947 in a domestic year** or **1,319 in a year that also includes a 5,000-mile tour**.

At the current planning rates, 1,319 short-fact announcements cost approximately **£1.21 with Apple speech**, **£5.67 with OpenAI `tts-1`**, **£16.08 with ElevenLabs Flash** or **£30.96 with the current ElevenLabs Multilingual model**. A £39.99 UK annual purchase provides only about £28.33 after assumed VAT and App Store commission, so unlimited Multilingual speech loses money on this tour-year case before fixed cost, acquisition or support.

A richer guide is more exposed. With longer passive content, 25% searched content and one rider question per two moving hours, the same tour year costs about **£4.23 with Apple speech**, **£10.80 with `tts-1`**, **£26.14 with Flash** or **£48.06 with Multilingual**.

Recommendation: keep the core useful with on-device speech; meter or cap premium speech; treat search and interactive guidance as separate allowances; and calibrate announcements per 100 miles using real routes before setting prices.

## What Is Fact And What Is Assumption

### External evidence

The Department for Transport's motorcycle factsheet reports that, over 2002–2016:

- motorcyclists recorded about 4,148 miles per motorcyclist per year on average;
- riders in the most rural areas recorded about 5,198 miles;
- motorcycles over 500 cc were reported at about 3,800 vehicle miles per year; and
- 52% of motorcycle mileage was commuting/business, 20% was day trips/holidays and 16% was social travel in the available purpose analysis.

The 2018–2019 mileage-band data puts more than 10,000 annual vehicle miles in the upper few per cent directionally. In 2025, Great Britain motorcycle traffic was split 52% minor roads, 42% A roads and only 6% motorways, although the long-distance target segment will not share the all-rider road mix.

The sample was small—about 100–140 recorded motorcyclists per year—and the data is old. It is evidence that **10,000-plus miles is a high-use profile**, not a current market-size estimate. It also supports excluding much commuting, shopping and personal-business mileage from RideHorizon usage. See [UNIT_ECONOMICS_MOTORCYCLE_USAGE_RESEARCH.md](UNIT_ECONOMICS_MOTORCYCLE_USAGE_RESEARCH.md) and the [DfT motorcycle factsheet](https://assets.publishing.service.gov.uk/government/uploads/system/uploads/attachment_data/file/694965/motorcycle-use-in-england.pdf).

### User evidence

The high-use case is anchored to the user's historical pattern:

- more than 10,000 miles in a high-mileage year;
- repeated 300-mile all-day rides, typically around six moving hours plus stops;
- occasional European tours of roughly 5,000 miles;
- many 500-plus-mile tour days; and
- an extreme day of about 1,200 km.

This is a valid high-use cost case. It is not assumed to describe the average customer.

### Planning assumptions

There is no reliable external dataset for “RideHorizon announcements per 100 motorcycle miles”. The route-density and app-use values below are explicit priors. They must be replaced with app telemetry.

## How The Current App Produces Cost

The current code does not bill one announcement for every hierarchy level crossed.

- Town, county, nation and country changes detected in the same resolved address are **coalesced into one announcement**.
- The highest-priority change—country, then nation, county and town—determines the fact request.
- Street announcements are off by default.
- The first resolved address in a session does not produce a boundary announcement because there is no previous address to compare.
- A 10-second default cooldown suppresses closely spaced events.
- Newer work can supersede a pending fact or announcement, and lower-priority work can be dropped while higher-priority speech is active.
- In Short Facts mode, a delivered non-street boundary announcement normally creates one fact request and one TTS utterance, subject to cache hits, failures and cancellation.

Therefore the relevant volume is **distinct geocoded transition moments that survive delivery controls**, not a sum of town, county, region and country polygon crossings.

## Usage Chain

### Step 1: Exclude journeys that do not fit the product

The model excludes commuting, errands and short familiar journeys by default. These miles matter only if later evidence shows riders regularly use RideHorizon on them.

An **eligible ride-day** is a recreational day ride, an unfamiliar long journey or a touring day where ambient geographic context has plausible value.

### Step 2: Apply an app-use rate

Even eligible rides do not imply use every time. Familiar routes, battery concerns, weather, group rides and simple lack of interest will reduce activation.

```text
RideHorizon miles per year
    = eligible ride-days
    × average miles per eligible day
    × app-use rate
```

### Step 3: Convert route miles into delivered announcements

The model uses three route classes. “Raw transition moments” means distinct resolved-address changes after simultaneous hierarchy changes are coalesced. The 80% delivery factor is a planning allowance for cooldown, supersession, geocoder failure and other non-delivery. It is not measured.

| Route class | Raw transition moments / 100 miles | Delivery factor | Delivered announcements / 100 miles | Typical moving speed | Delivered announcements / moving hour |
|---|---:|---:|---:|---:|---:|
| Motorway / autoroute | 6 | 80% | **4.8** | 65 mph | 3.1 |
| Mixed trunk and A-road | 12 | 80% | **9.6** | 50 mph | 4.8 |
| Scenic, settlement-rich A/B-road | 18 | 80% | **14.4** | 40 mph | 5.8 |

These priors imply roughly one delivered announcement every 21 motorway miles, 10 mixed-road miles or 7 scenic-road miles. The resulting cadence is about one announcement every 10–19 moving minutes, which is plausible for an ambient guide but still requires a rider-distraction test.

The route-weighted rate is:

```text
delivered announcements / 100 miles
    = motorway share × 4.8
    + mixed-road share × 9.6
    + scenic-road share × 14.4
```

## Bottom-Up Personas

These are cost archetypes, not claims about market share.

| Persona | Eligible pattern | App-use rate | RideHorizon miles / year | Route mix: motorway / mixed / scenic | Delivered announcements / 100 miles | Delivered announcements / year |
|---|---|---:|---:|---:|---:|---:|
| Occasional leisure rider | 10 days × 120 miles | 60% | 720 | 15% / 45% / 40% | 10.8 | **78** |
| Regular weekend explorer | 24 days × 180 miles | 75% | 3,240 | 10% / 40% / 50% | 11.5 | **373** |
| High-mileage domestic rider | 36 days × 300 miles | 85% | 9,180 | 20% / 45% / 35% | 10.3 | **947** |
| 5,000-mile European tour add-on | 15 days averaging 333 miles | 100% | 5,000 | 60% / 25% / 15% | 7.4 | **372** |
| High-mileage tour year | Domestic case plus one tour | — | 14,180 | Weighted | — | **1,319** |

The high-mileage domestic assumption represents 10,800 eligible miles before applying the 85% app-use rate. A rider who takes a 5,000-mile tour every second year would average about **1,133 announcements per year**, but the cash and capacity model must retain the **1,319-announcement tour-year spike**.

### Sanity checks against ride duration

| Ride | Route assumption | Delivered announcements | Interpretation |
|---|---|---:|---|
| 120-mile leisure ride | Occasional persona mix | 13 | The earlier 12-announcement assumption fits a short day ride, not a long one. |
| 180-mile weekend ride | Regular persona mix | 21 | About one every 10–12 moving minutes. |
| 300-mile all-day ride | High-mileage domestic mix | 31 | About 5.2 per moving hour at a 50 mph average. |
| 500-mile European day | European mix | 37 | Longer distance, but motorway-heavy. |
| 1,200 km / 746-mile European day | European mix | 56 | A realistic peak-day cost and capacity case. |
| 5,000-mile European tour | European mix | 372 | About 25 per day across 15 days. |

## Provider Cost Per Delivered Short-Fact Announcement

The detailed provider evidence is in [UNIT_ECONOMICS_PROVIDER_PRICING_RESEARCH.md](UNIT_ECONOMICS_PROVIDER_PRICING_RESEARCH.md).

The MVP Short Facts case assumes:

- 300 characters of announcement text;
- `gpt-4o-mini` generation;
- 10% of facts use one web search;
- no shared-cache saving;
- no repeated TTS generation for replay; and
- $1 = £0.752.

| Provider path | Cost per delivered announcement | Cost per 100 delivered announcements |
|---|---:|---:|
| Apple speech + text/search | £0.00091 | **£0.09** |
| OpenAI `tts-1` + text/search | £0.00430 | **£0.43** |
| ElevenLabs Flash + text/search | £0.01219 | **£1.22** |
| ElevenLabs Multilingual + text/search | £0.02347 | **£2.35** |

## Annual MVP Cost By Persona

| Persona | Apple speech | OpenAI `tts-1` | ElevenLabs Flash | ElevenLabs Multilingual |
|---|---:|---:|---:|---:|
| Occasional leisure rider: 78 | **£0.07** | £0.34 | £0.95 | £1.83 |
| Regular weekend explorer: 373 | **£0.34** | £1.60 | £4.55 | £8.76 |
| High-mileage domestic rider: 947 | **£0.87** | £4.07 | £11.55 | £22.23 |
| 5,000-mile tour add-on: 372 | **£0.34** | £1.60 | £4.54 | £8.73 |
| High-mileage tour year: 1,319 | **£1.21** | £5.67 | £16.08 | £30.96 |

Peak current-Multilingual cost is approximately **£0.73 for a 300-mile domestic day**, **£0.87 for a 500-mile European day** and **£1.31 for a 1,200 km European day**. These are small individual charges, but an unlimited low-priced annual product accumulates them across the season.

## Richer Guide Scenario

The richer-guide case makes the cost expansion explicit instead of hiding it in a larger final estimate.

### Passive content

- 80% short facts at 300 characters.
- 20% long facts at 750 characters.
- 25% of both types use search.
- Weighted TTS length: 390 characters per delivered announcement.

### Interactive content

- One rider-requested answer per two moving hours.
- 500 characters per answer.
- 60% of answers use one search.
- High-mileage domestic case: 92 answers per year.
- High-mileage tour year: 137 answers per year.

| High-use case | Apple speech | OpenAI `tts-1` | ElevenLabs Flash | ElevenLabs Multilingual |
|---|---:|---:|---:|---:|
| Domestic year, MVP Short Facts | £0.87 | £4.07 | £11.55 | £22.23 |
| Domestic year, richer passive + interactive | **£3.00** | **£7.68** | **£18.62** | **£34.23** |
| Tour year, MVP Short Facts | £1.21 | £5.67 | £16.08 | £30.96 |
| Tour year, richer passive + interactive | **£4.23** | **£10.80** | **£26.14** | **£48.06** |

This is still not an unconstrained agent. Multiple searches, retries, tool calls or several generated candidates for one spoken answer would raise cost further and must have a per-request ceiling.

## Search And Context Sensitivity

For short facts using `gpt-4o-mini`, the high-mileage cases cost approximately:

| Search policy | Domestic year: 947 facts | Tour year: 1,319 facts |
|---|---:|---:|
| No searches | £0.07 | £0.10 |
| 10% searched | £0.87 | £1.21 |
| 25% searched | £2.06 | £2.87 |
| Every fact searched | £8.04 | £11.20 |

At the current token rate, another 10,000 text-only input tokens cost about **£0.00113 per request**; another 100,000 cost about **£0.01128**. Ordinary context growth is therefore modest on a cheap model until context becomes very large. A search call or multi-step tool loop is the sharper risk.

Recommended policy:

- do not search every passive announcement;
- search when freshness, ambiguity or a precise claim warrants it;
- cache sourced stable facts and preserve source metadata;
- cap searches, tool calls, retries and generated alternatives per rider request; and
- fall back to a bounded non-search answer or silence when a cost or latency budget is exhausted.

## Revenue And Contribution Tests

Apple states that proceeds are the customer price minus applicable taxes and commission. The planning assumption is UK price divided by 1.20 VAT, then multiplied by 85% under the Small Business Program:

```text
net proceeds = customer price / 1.20 × 0.85
             = customer price × 70.83%
```

| UK retail price | Approximate net proceeds before marginal cost |
|---:|---:|
| £29.99 | £21.24 |
| £39.99 | £28.33 |
| £59.99 | £42.49 |

| Case | Retail | Voice | Marginal cost | Contribution | Contribution / net proceeds |
|---|---:|---|---:|---:|---:|
| Regular weekend explorer, MVP | £29.99 | Multilingual | £8.76 | **£12.48** | 59% |
| High-mileage domestic year, MVP | £39.99 | Multilingual | £22.23 | **£6.10** | 22% |
| High-mileage tour year, MVP | £39.99 | Multilingual | £30.96 | **−£2.63** | −9% |
| High-mileage tour year, MVP | £39.99 | Flash | £16.08 | **£12.25** | 43% |
| High-mileage tour year, MVP | £39.99 | `tts-1` | £5.67 | **£22.66** | 80% |
| High-mileage tour year, richer guide | £59.99 | Multilingual | £48.06 | **−£5.57** | −13% |
| High-mileage tour year, richer guide | £59.99 | Flash | £26.14 | **£16.35** | 38% |
| High-mileage tour year, richer guide | £59.99 | `tts-1` | £10.80 | **£31.69** | 75% |

At a 70% contribution target, marginal cost may consume at most 30% of net proceeds. A £39.99 purchase therefore has an £8.50 usage-cost budget. Under the MVP short-fact assumptions, that buys approximately:

| Provider path | Announcements within £8.50 |
|---|---:|
| Apple speech + text/search | 9,295 |
| OpenAI `tts-1` + text/search | 1,977 |
| ElevenLabs Flash + text/search | 697 |
| ElevenLabs Multilingual + text/search | 362 |

The Multilingual allowance is below the regular-weekend persona and far below the high-mileage personas. Flash is still below the domestic high-use case. `tts-1` covers the modelled high-use cases at this price and contribution target, subject to quality and actual provider billing.

## Current Cost-Exposure Limits

The proxy currently allows, by default:

| Limit | Per verified installation | Global |
|---|---:|---:|
| Fact requests per day | 180 | 2,000 |
| Speech characters per day | 120,000 | 250,000 |

These are abuse and service limits, not commercial budgets. One verified installation can theoretically consume about £9.02 per day of Multilingual speech before facts and search. The modelled 1,200 km day is only about £1.31, so the current cap is much too loose to constrain normal commercial exposure.

Before external scale, add:

- per-installation ride-day and rolling-month monetary budgets;
- global daily and monthly provider-spend budgets;
- separate limits for TTS characters, searches, LLM tokens and retries;
- automatic fallback from premium to cheaper or Apple speech;
- automatic fallback from searched to cached or non-search content;
- alerts at 50%, 75% and 90% of budget; and
- a hard stop that preserves display, Names Only and Apple speech.

## Fixed-Cost Overlay

Fixed and step-fixed costs remain separate:

- Fly compute, database and minimum storage;
- unused provider minimum commitments;
- monitoring, email and operational services;
- Apple Developer Program and domains amortised monthly;
- development, support, administration and compliance labour; and
- insurance, accounting and company overhead.

Do not count included provider usage both as allocated marginal cost and again as a fixed cost. Count the usage at its economic unit rate, then put only unused minimum commitment and non-usage subscription value into the fixed overlay.

```text
weighted contribution per paying user
    = sum(persona share × persona net contribution)

monthly break-even paying users
    = monthly fixed costs / weighted contribution per paying user
```

Run this at average-season and peak touring-season mixes. Do not average tour-year losses away.

## Calibration Plan

The next uncertainty to remove is not provider pricing. It is delivered announcements per 100 miles.

Run at least these route samples with the actual app and default settings:

1. 100-plus motorway miles.
2. 100-plus mixed trunk/A-road miles.
3. 100-plus settlement-rich scenic A/B-road miles.
4. A known 250–300-mile domestic day route.
5. A multi-day UK or European tour segment.

Record privacy-safe aggregates for each ride:

- total and moving miles and hours;
- route-class mix, initially rider-labelled;
- successful reverse-geocode results;
- raw resolved-address changes by field;
- coalesced candidate boundary moments;
- events suppressed by cooldown, priority or supersession;
- fact requests started, cancelled, cached and completed;
- announcements played and characters by provider;
- searches, model tokens, retries and generated content never played; and
- provider-reported billed speech usage.

Report p50, p90 and maximum values for:

```text
delivered announcements / 100 miles
delivered announcements / moving hour
marginal cost / ride-day
marginal cost / active rider-year
marginal cost / tour
```

Map boundary datasets alone are not enough for calibration because the current product reacts to Apple's resolved `locality`, `subAdministrativeArea`, `administrativeArea` and `country` labels. The real app pipeline—including geocoder behaviour, cooldown and cancellation—must be measured.

## Decision

The more defensible model strengthens the commercial warning without implying that every long ride is ruinously expensive:

- **MVP with local speech:** marginal costs remain very low even for high-mileage touring.
- **Cheaper cloud speech:** likely workable, subject to helmet quality and a bounded allowance.
- **Current Multilingual speech:** unsuitable as an unlimited feature in a £39.99 annual product for the customers most likely to value RideHorizon.
- **Richer and interactive guide:** viable only with deliberate search/tool budgets, cheaper speech, caching and product packaging matched to usage.

The immediate product decision is to price and package from the high-use tail, then validate the route-density priors on real rides.
