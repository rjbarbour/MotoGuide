# RideHorizon market and commercial model

Date: 2026-08-04

Status: coarse planning model. Market-stock inputs are sourced; product relevance, iOS reach, paid penetration, CAC and churn are assumptions until real riders produce behavioural and payment evidence.

## Bottom line

RideHorizon does not need a global mass market to become a viable niche business.

- The raw road-vehicle ceiling across Europe and the core Anglophone markets is **more than 51.3 million powered two-wheelers**. This is not 51.3 million riders or prospects.
- After a 20% touring/unfamiliar-ride relevance filter and region-specific iOS reach proxies, the base serviceable market is about **4.52 million vehicle-equivalent prospects**.
- At a £39.99 annual price, that represents about **£181 million of theoretical annual retail SAM**.
- Capturing **0.5%** of that base SAM would mean about **22,600 paying customers and £905,000 annual retail billings**. Under the base unit economics it would leave about **£396,000 a year after marginal service cost and replacement acquisition, but before fixed costs, development, support and tax**. Comparable evidence indicates that reaching this payer count would be a strong distribution result, not a modest baseline.
- The UK is a sensible validation beachhead but not the whole commercial opportunity. At only 0.5% of the modelled UK SAM, RideHorizon would have about 730 payers and £29,000 annual retail billings.
- A **£39.99 annual plan** can work if most speech remains on-device or uses a cheaper bounded cloud path. An unlimited premium-voice offer cannot be assumed to work at that price.

Recommendation: validate the UK wedge, price at **£39.99/year** with a **£9.99 30-day touring-pass test**, and expand next into the US, Canada, Australia and New Zealand before carrying the cost and content-quality burden of multilingual continental Europe.

## Definitions

This model uses the terms as follows:

- **Raw market ceiling:** registered or licensed vehicle stock. It is useful as a denominator but overstates unique owners, active riders and relevant riders.
- **TAM:** the annual retail value if every vehicle in the stated geographic ceiling bought one subscription. It is mathematically valid but commercially unrealistic.
- **SAM:** vehicle stock filtered for likely touring/unfamiliar-ride relevance and iOS reach. It is still a proxy for people, not a measured audience.
- **SOM:** paying customers at an explicit share of SAM. It is a scenario, not a forecast.
- **CLV:** gross contribution over the expected paying relationship, before fixed costs and tax.

The source note is [MARKET_SIZING_SOURCE_INPUTS_2026-08-04.md](MARKET_SIZING_SOURCE_INPUTS_2026-08-04.md). Marginal usage costs come from [RIDEHORIZON_UNIT_ECONOMICS_MODEL.md](RIDEHORIZON_UNIT_ECONOMICS_MODEL.md). Comparable commercial evidence is assessed in [RIDEHORIZON_COMPETITOR_ECONOMICS_BENCHMARK.md](RIDEHORIZON_COMPETITOR_ECONOMICS_BENCHMARK.md).

## Evidence-backed market ceiling

| Market | Road-vehicle stock anchor | Definition and date |
|---|---:|---|
| UK | 1.355m | Licensed motorcycles, end of 2024 |
| Europe including the UK | More than 40.000m | Powered two-wheelers, 2023; includes mopeds |
| US | 9.261m | Registered motorcycles, 2024 |
| Canada | 0.858m | Active motorcycles and mopeds, 2024 |
| Australia | 0.981m | Registered motorcycles, 2025-01-31 |
| New Zealand | About 0.175m | Rounded government motorcycle-registration anchor, 2023 publication |
| **Europe plus core Anglophone markets, without counting the UK twice** | **More than 51.275m** | Europe including the UK, plus US, Canada, Australia and New Zealand |

At £39.99 per vehicle, the raw mathematical TAM is more than **£2.05 billion a year**. Do not use that figure in an investor or operating plan without the relevance filters below. Europe includes many mopeds used for short urban transport, some riders own several bikes and registration does not prove active use.

### Global market

No current globally comparable road-active motorcycle count was found with consistent definitions. A worldwide total would also be dominated by utility two-wheelers outside RideHorizon's stated target. The [World Health Organization reports](https://www.who.int/news/item/25-11-2024-who-convenes-global-motorcycle-safety-experts-in-viet-nam) that the number of motorcycles on the world's roads nearly tripled in the decade to 2021. That makes a global vehicle TAM very large and strategically unhelpful.

The operating market should therefore be **Europe plus the core Anglophone countries**, with South America treated as opportunistic later demand rather than included in the base case. Japan, China, India and Africa are excluded from the working SAM.

## Base regional SAM

The base model applies:

```text
serviceable vehicle-equivalent prospects
    = road-vehicle stock
    × 20% touring or unfamiliar-ride relevance
    × region-specific iOS reach proxy
```

The 20% relevance assumption is supported directionally by adventure and touring motorcycles making up 23.1% of UK new registrations in 2024. It is not a measured installed-fleet share. The iOS inputs are 2026-07 mobile-web traffic shares from Statcounter, not installed-device shares among riders.

| Market | iOS proxy | Base SAM prospects | Annual retail SAM at £39.99 |
|---|---:|---:|---:|
| UK, shown as a launch-market memo | 53.92% | 146,000 | £5.84m |
| Europe including the UK | 39.54% | 3.163m | £126.50m |
| US | 59.58% | 1.104m | £44.13m |
| Canada | 65.91% | 113,000 | £4.52m |
| Australia | 63.70% | 125,000 | £5.00m |
| New Zealand | 55.86% | 19,600 | £0.78m |
| **Core combined, without counting the UK twice** | — | **4.524m** | **£180.93m** |

Useful roll-ups from the same base case are:

- **Anglophone markets including the UK:** about 1.507 million prospects and £60.28 million annual retail SAM.
- **Europe including the UK:** about 3.163 million prospects and £126.50 million annual retail SAM.
- **North America:** about 1.217 million prospects and £48.65 million annual retail SAM.
- **Australasia:** about 145,000 prospects and £5.78 million annual retail SAM.

### SAM sensitivity

Because the filters are not observed rider behaviour, the range matters more than the point estimate.

| Case | Relevant-use share | iOS reach | Serviceable prospects | Retail SAM at £39.99 |
|---|---:|---:|---:|---:|
| Conservative | 10% | 35% | 1.795m | £71.77m |
| Mechanical central sensitivity | 20% | 50% | 5.128m | £205.05m |
| Upside | 30% | 65% | 9.999m | £399.85m |

The region-weighted base result of 4.524 million is preferable to the mechanical central sensitivity because Europe's lower iOS proxy is applied to most of the stock.

## SOM and revenue scenarios

These scenarios use the region-weighted base SAM of 4.524 million and a £39.99 annual plan.

Base per-payer economics are:

```text
UK-style App Store proceeds = £39.99 / 1.20 VAT × 85% = £28.33
Marginal service and content cost = £4.50
Annual gross contribution = £23.83
Replacement acquisition at 35% annual churn and £18 CAC = £6.30 per payer-year
Steady-state contribution after replacement acquisition = £17.53 per payer-year
```

Tax treatment varies by country. The UK-style 70.83% proceeds factor is used only to keep the scenarios comparable.

| Paid penetration of SAM | Payers | Annual retail billings | Gross contribution before acquisition | Contribution after replacement acquisition | Interpretation |
|---|---:|---:|---:|---:|---|
| 0.1% | 4,500 | £181,000 | £108,000 | £79,000 | Evidence of a real niche; still a lean operation |
| 0.5% | 22,600 | £905,000 | £539,000 | £396,000 | Strong distribution outcome; supports a small specialist business |
| 2.0% | 90,500 | £3.62m | £2.16m | £1.59m | Strong international category position |

All contribution figures exclude fixed infrastructure, founder/development labour, support, insurance, accounting, refunds, foreign-exchange effects and corporation tax.

## Pricing recommendation

Current specialised motorcycle apps cluster around £50 per year in the UK, while RideHorizon's exact place-awareness proposition is not yet validated. The recommended test is therefore below established navigation-app pricing:

| Offer | Test price | Purpose |
|---|---:|---|
| Annual standard | **£39.99/year** | Core display, names, short facts and bounded speech usage |
| Touring pass | **£9.99/30 days** | Seasonal European trip or occasional-tour buyer; test repeat purchase separately from subscription churn |
| Premium guide, later | **£59.99/year or higher** | Only after richer content, interaction and actual provider usage are measured |

Do not sell unlimited ElevenLabs Multilingual speech inside the £39.99 plan. The existing heavy tour-year model produces about £30.96 of marginal cost for short facts and about £48.06 for richer passive plus interactive use before acquisition or support. On-device speech, cheaper cloud speech, caching and explicit premium allowances are commercially safer.

## CAC, churn and CLV

No RideHorizon acquisition or retention data exists yet. These are explicit planning estimates.

### CAC by channel

| Channel | Cash CAC planning range | Comment |
|---|---:|---|
| Founder-led communities, clubs and referrals | £5–£15 | Cash-light but labour-heavy; do not call it free |
| Partnerships, newsletters and small creators | £15–£30 | Likely best scalable fit if audience quality is high |
| Broad paid social or search | £30–£70 | Too expensive for the base offer unless conversion, retention or price beats the model |

The base blended CAC of **£18** assumes community, referral and partnership acquisition dominates early growth. A paid-only growth plan should use at least £35 until campaigns prove otherwise.

### Unit-economics scenarios

The simple annual-subscription model is:

```text
annual contribution = retail price / 1.20 × 85% - marginal cost
contribution CLV = annual contribution / annual renewal churn
LTV:CAC = contribution CLV / CAC
```

| Case | Retail/year | Marginal cost/year | Annual churn | CAC | Annual contribution | Contribution CLV | LTV:CAC | CAC / annual contribution |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Conservative | £29.99 | £8.50 | 55% | £30 | £12.74 | £23.17 | **0.77×** | 2.35 years |
| Base | £39.99 | £4.50 | 35% | £18 | £23.83 | £68.08 | **3.78×** | 0.76 years |
| Upside | £49.99 | £3.00 | 20% | £12 | £32.41 | £162.05 | **13.50×** | 0.37 years |

Interpretation:

- The conservative case is not viable: expected contribution CLV does not repay CAC.
- The base case is investable enough for controlled testing: the first annual purchase covers CAC and LTV:CAC is above 3×.
- The upside case is possible only with strong organic distribution, high renewal and tightly controlled service cost. It should not be budgeted as the forecast.
- A one-month touring pass has repurchase, not annual-subscription churn. Track the proportion buying another pass within 12 months and calculate a separate transactional CLV.

## Fixed-cost break-even

Under the base case, each retained payer contributes about **£17.53 per year after allowing for acquisition of replacements for 35% annual churn**.

| Illustrative annual fixed-cost base | Paying customers required |
|---|---:|
| £30,000 lean cash operation | 1,700 |
| £100,000 owner-operated business | 5,700 |
| £300,000 small team | 17,100 |

These are economic break-even counts, not staffing budgets. They exclude corporation tax and financing. They also assume the base CAC, churn and marginal cost have already been demonstrated.

## Strategic interpretation by region

- **UK:** right for product validation, community recruitment and safety testing. Too small to assume it supports a substantial standalone business at modest penetration.
- **US:** the largest single English-language revenue opportunity and the next logical commercial market after UK proof.
- **Canada, Australia and New Zealand:** smaller individually but operationally attractive because the current English product needs less localisation.
- **Continental Europe:** the largest stock pool, but the more than 40 million figure includes mopeds and the product needs language, place-data and speech-quality validation country by country. Enter it deliberately, beginning with English-speaking tourers and then selected high-value touring markets.
- **Rest of world:** exclude from the operating plan until inbound use or a local partner justifies country-specific work.

## What must be measured next

The model is most sensitive to behaviour, not raw vehicle stock. Collect these before treating the base case as a forecast:

1. Qualified visitor to beta-install conversion by channel.
2. Install to first real ride, then second real ride within 30 days.
3. Paid conversion at £39.99 annual versus £9.99 touring pass.
4. 30-day, 90-day and annual ride-active retention.
5. Annual renewal churn and 12-month touring-pass repurchase.
6. CAC by channel including cash spend and founder labour reported separately.
7. Marginal cost per active payer at p50, p90 and maximum touring usage.
8. Refund rate, support time per payer and App Store proceeds by market.

The immediate commercial gate is not whether the global TAM looks large. It is whether UK touring riders keep RideHorizon on for repeated real rides and then pay enough to acquire similar riders without destroying contribution margin.
