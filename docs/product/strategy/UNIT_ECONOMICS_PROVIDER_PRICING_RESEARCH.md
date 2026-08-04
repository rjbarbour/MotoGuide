# RideHorizon Provider Pricing Research

Date: 2026-08-04

Source access date: 2026-08-04

## Purpose

Provide current variable-cost inputs for a RideHorizon unit-economics model. This note covers provider charges only. It does not yet model rider personas, usage frequency, hosting, App Store commission, tax, support, acquisition cost or revenue.

## Bottom Line

- The exact current cloud path is **`gpt-4o-mini` fact generation → announcement text → `eleven_multilingual_v2` TTS**.
- Apple on-device speech has no metered provider charge. It is the clear cost floor.
- ElevenLabs' current RideHorizon model, `eleven_multilingual_v2`, is published at **$0.10 per 1,000 characters**, approximately **$0.10 per spoken minute**. ElevenLabs Flash/Turbo halves that to **$0.05**.
- Credible cloud alternatives are materially cheaper: OpenAI `tts-1` is **$0.015 per 1,000 characters** and Google Neural2 is **$0.016**. Google Standard/WaveNet is **$0.004**, although voice quality must be tested in a helmet rather than inferred from price.
- Short text-only facts are extremely cheap at current OpenAI token rates: typically much less than **$0.001 per fact** under the explicit assumptions below.
- Live web search changes the cost shape. The tool fee alone is **$0.01 per call**, before any charge for model input and output. Search can therefore cost tens or hundreds of times more than text-only generation.
- RideHorizon currently permits reverse geocoding every 10 seconds, while Apple's `CLGeocoder` guidance says a typical moving app should not send more than one request per minute. Apple publishes no per-call tariff, but throttling and reliability are material risks.

## Currency And Comparison Assumptions

Provider list prices are in US dollars and exclude tax unless the provider says otherwise.

For indicative sterling values, this note uses **$1 = £0.752**. This is derived from the Bank of England's 2026-07-27 reference row of **£1 = $1.3304**. It is a planning conversion, not a guaranteed settlement rate.

For cross-provider speech comparisons:

- **1,000 characters is treated as approximately one spoken minute.** ElevenLabs itself uses this equivalence in its pricing table.
- A **short announcement** is assumed to be 250 characters, approximately 15 seconds.
- A **long announcement** is assumed to be 750 characters, approximately 45 seconds.
- Actual duration varies with language, punctuation, speaking rate and provider. Character-based billing does not vary with duration; tokenised audio billing can.

## Text-To-Speech Comparison

The table uses published paid rates and excludes temporary credits and free tiers from steady-state commercial economics.

| Provider and model | Published billing rate | Normalised $/1,000 characters | Approx. $/spoken minute | Approx. £/spoken minute | Short announcement | Long announcement |
|---|---:|---:|---:|---:|---:|---:|
| Apple `AVSpeechSynthesizer` | No metered tariff; speech generated on-device | $0.000 | $0.000 | £0.000 | $0.000 | $0.000 |
| Google Standard or WaveNet | $4/1M characters | $0.004 | $0.004 | £0.003 | $0.001 | $0.003 |
| OpenAI `tts-1` | $15/1M characters | $0.015 | $0.015 | £0.011 | $0.00375 | $0.01125 |
| Google Neural2 | $16/1M characters | $0.016 | $0.016 | £0.012 | $0.004 | $0.012 |
| Google Chirp 3: HD | $30/1M characters | $0.030 | $0.030 | £0.023 | $0.0075 | $0.0225 |
| OpenAI `tts-1-hd` | $30/1M characters | $0.030 | $0.030 | £0.023 | $0.0075 | $0.0225 |
| ElevenLabs Flash/Turbo | $0.05/1,000 characters | $0.050 | $0.050 | £0.038 | $0.0125 | $0.0375 |
| ElevenLabs Multilingual v2/v3 | $0.10/1,000 characters | $0.100 | $0.100 | £0.075 | $0.025 | $0.075 |

At 1,000 short announcements, the speech charge is approximately:

| Provider and model | 250,000 characters | Approx. sterling |
|---|---:|---:|
| Apple on-device | $0.00 | £0.00 |
| Google Standard/WaveNet | $1.00 | £0.75 |
| OpenAI `tts-1` | $3.75 | £2.82 |
| Google Neural2 | $4.00 | £3.01 |
| Google Chirp 3: HD or OpenAI `tts-1-hd` | $7.50 | £5.64 |
| ElevenLabs Flash/Turbo | $12.50 | £9.40 |
| ElevenLabs Multilingual v2/v3 | $25.00 | £18.80 |

### ElevenLabs Plans, Credits And Excess Usage

RideHorizon currently configures `eleven_multilingual_v2`. ElevenLabs' current public API table shows the same unit rate at every self-serve tier; higher subscriptions mainly buy a larger included pool and plan-level features or limits.

| Monthly tier | Recurring price | Flash/Turbo characters included | Multilingual v2/v3 characters included |
|---|---:|---:|---:|
| Free / PAYG | $0 | 20,000 | 10,000 |
| Starter | $6 | 120,000 | 60,000 |
| Creator | $22 | 440,000 | 220,000 |
| Pro | $99 | 1,980,000 | 990,000 |
| Scale | $299 | 5,980,000 | 2,990,000 |
| Business | $990 | 19,800,000 | 9,900,000 |

Notes:

- The advertised Creator first-month price is $11. The table uses its steady-state $22 price.
- The API pricing page says API usage is billed in US dollars, not credits: $0.05 per 1,000 Flash/Turbo characters and $0.10 per 1,000 Multilingual v2/v3 characters.
- New self-serve accounts use prepaid PAYG top-ups after subscription credits. The minimum top-up is $5; balances expire after 12 months. If the balance reaches zero, service pauses. There is no postpaid overage.
- Legacy self-serve and Enterprise overage prices are not public constants. ElevenLabs says the rate depends on the plan and is displayed before the customer enables usage-based billing.
- Subscription credits can roll over, subject to a cap of two months' allocation. PAYG funds have no monthly rollover cap but expire after 12 months.
- Shared Voice Library voices may apply a custom consumption multiplier. A production cost logger should capture ElevenLabs' response `character-cost` header rather than infer every charge from raw text length.
- ElevenLabs states that paid plans grant commercial rights, while free-plan output is non-commercial with attribution. Confirm the licence treatment of a PAYG-funded free-tier account before relying on it commercially.
- Prices exclude taxes, levies and duties.
- The published Startup Grant offers 33 million characters over 12 months. It can reduce validation spend but should not be included in steady-state gross-margin assumptions.

### OpenAI Speech Ambiguity

OpenAI also publishes `gpt-4o-mini-tts` at $0.60 per million text-input tokens plus $12 per million audio-output tokens. OpenAI does not publish an exact character or minute conversion on the current model page, so it cannot be normalised reliably without measured usage. The current model catalogue marks it deprecated. `tts-1` and `tts-1-hd` therefore provide clearer current character-based comparison points.

### Google Free Usage

Google currently publishes monthly free usage of 4 million characters for Standard and WaveNet, and 1 million characters for Neural2 and Chirp 3: HD. These allowances are useful for prototype testing but excluded from the paid unit-cost table because commercial cost should not depend on a revocable free tier.

Google also publishes Gemini 2.5 Flash TTS at $0.50 per million text-input tokens plus $10 per million audio-output tokens, with 25 audio tokens per second. That implies an audio-output component of **$0.015 per minute**, before the small input-token charge. It should be tested separately because prompted generative TTS is not directly equivalent to fixed-voice character-billed TTS.

## OpenAI Text Generation And Search

### Relevant Published Model Rates

| Model | Why it is relevant | Input per 1M tokens | Cached input | Output per 1M tokens |
|---|---|---:|---:|---:|
| `gpt-4o-mini` | Current RideHorizon fact-proxy default; inexpensive focused tasks | $0.15 | $0.075 | $0.60 |
| `gpt-5.6-luna` | Current high-volume/cost-sensitive family option | $0.20 | $0.02 | $1.20 |
| `gpt-5.4-mini` | Higher-cost comparison for stronger generation and interactive work | $0.75 | $0.075 | $4.50 |

The `gpt-5.6-luna` values above use OpenAI's main API pricing page, which explicitly labels them standard processing for context under 270,000 tokens. OpenAI's Luna model-catalogue page currently displays a contradictory $1 input and $6 output rate. Verify a live account invoice before treating the lower public rate as contractually settled.

OpenAI says Batch API processing is 50% cheaper on input and output. It is relevant to pre-generating touring packs or caching place facts, but not to low-latency ride-time requests because batches may run asynchronously over 24 hours.

### Per-Request Assumptions

These are explicit planning scenarios, not observed RideHorizon token traces:

| Workload | Own input | Model output | Search use | Search content assumed |
|---|---:|---:|---:|---:|
| Short fact | 400 tokens | 60 tokens | None | None |
| Long fact | 1,500 tokens | 200 tokens | None | None |
| Interactive answer | 3,000 tokens | 150 tokens | None | None |
| Search-enriched short fact | 400 tokens | 60 tokens | 1 call | 4,000 tokens |
| Search-enriched long fact | 1,500 tokens | 200 tokens | 2 calls | 8,000 tokens total |
| Search-enriched interactive answer | 3,000 tokens | 150 tokens | 1 call | 6,000 tokens |

The interactive input includes recent dialogue, location hierarchy, rider preferences and system instructions. It is intentionally larger than a passive fact request.

### Estimated Cost Per Fact Or Answer

The following table uses standard token rates. Search scenarios use the conservative detailed-pricing interpretation: **$0.01 per search call plus search-content tokens billed at the selected model's input rate**. For `gpt-4o-mini`, OpenAI specifies a fixed 8,000 search-content input-token block per call, so that model's search calculations use 8,000 tokens for one call and 16,000 for two.

| Workload | `gpt-4o-mini` | `gpt-5.6-luna` | `gpt-5.4-mini` |
|---|---:|---:|---:|
| Short fact | $0.000096 | $0.000152 | $0.000570 |
| Long fact | $0.000345 | $0.000540 | $0.002025 |
| Interactive answer | $0.000540 | $0.000780 | $0.002925 |
| Search-enriched short fact | $0.011296 | $0.010952 | $0.013570 |
| Search-enriched long fact | $0.022745 | $0.022140 | $0.028025 |
| Search-enriched interactive answer | $0.011740 | $0.011980 | $0.017425 |

Indicative sterling costs are the dollar values multiplied by 0.752. For example, a `gpt-5.6-luna` short fact is approximately **£0.00011**, while its one-search equivalent is approximately **£0.00824**.

These estimates show that:

- text-only generation is unlikely to threaten gross margin at normal announcement volumes;
- the search call, not the model output, dominates search-enriched fact cost;
- context growth matters more for interactive use, but remains secondary to search and premium TTS at the assumed lengths;
- observed token and tool-call telemetry is still required because reasoning tokens, retries, safety regeneration and multi-call agent behaviour can expand cost.

### OpenAI Web-Search Pricing Conflict

OpenAI's two current official price pages do not agree completely:

- the main API pricing page says web search is **$10 per 1,000 calls** and that search-content tokens are free;
- the detailed developer pricing page says web search is **$10 per 1,000 calls plus search-content tokens billed at model rates**; it also specifies a fixed 8,000-token block for `gpt-4o-mini` and `gpt-4.1-mini` with the non-preview tool;
- the detailed page separately lists legacy preview pricing of $10 per 1,000 calls for reasoning models with billed content tokens, and $25 per 1,000 calls for non-reasoning models with free content tokens.

Recommendation: budget using the conservative detailed-page calculation above, then validate the exact Responses API route and invoice before launch. Do not mix the current standard tool with preview-tool prices in one model.

## Apple Speech And Geocoding

### Speech

Apple states that AVFoundation speech synthesis occurs on-device and is not sent to a server. Apple publishes no per-character, per-minute or per-request tariff for `AVSpeechSynthesizer`. Treat its marginal provider cost as **$0**, while still accounting for engineering, device energy and quality trade-offs outside this note.

### Reverse Geocoding

`CLGeocoder` is network-based, deprecated in favour of MapKit, and rate-limited per app. Apple does not publish an exact quota. Its documented operating guidance says:

- at most one geocoding request for one user action;
- reuse a result for repeated actions involving the same location;
- for automatic updates while moving, wait for significant distance and reasonable time;
- in a typical situation, do not send more than one request per minute;
- do not initiate a request while the app is inactive or in the background because the user will not see the result immediately.

An accepted Apple Staff answer states that native MapKit has no cost beyond Apple Developer Program membership, although it dates from 2020. Current Apple framework documentation still publishes no native per-request tariff. The safe commercial assumption is therefore **zero marginal charge but an undocumented service limit and no published SLA**.

This is relevant to RideHorizon because its default location interval is 10 seconds. Cost is not the immediate problem; request scheduling, caching and fallback behaviour are.

## Recommended Inputs For The Persona Cost Model

Use these provider-cost cases when modelling rider personas:

1. **Cost floor:** Apple speech, cached or deterministic facts, throttled Apple geocoding.
2. **Economy cloud voice:** OpenAI `tts-1` or Google Neural2, text-only `gpt-4o-mini` or `gpt-5.6-luna` facts.
3. **Premium voice:** ElevenLabs Flash/Turbo first; Multilingual v2/v3 only if measured helmet quality and willingness to pay justify the extra cost.
4. **Search-enabled guide:** add $0.01 for every search tool call, plus model tokens conservatively. Do not search by default for every passive announcement.
5. **Pre-generated touring content:** use Batch API and cache by place, language, content depth and broad interest profile where freshness requirements allow.

Instrument production-like tests with:

- announcement characters and speech duration;
- TTS provider, model and response-reported billed usage;
- OpenAI input, cached input, reasoning and output tokens;
- search calls and search-content tokens;
- retries, cancellations and abandoned audio;
- cache-hit rate per place and fact variant;
- geocoder attempts, successes, throttles and reused results.

## Primary Sources

All sources were accessed on 2026-08-04.

- [ElevenLabs API pricing](https://elevenlabs.io/pricing/api)
- [ElevenLabs Pay As You Go](https://elevenlabs.io/docs/overview/administration/pay-as-you-go)
- [ElevenLabs billing and rollover](https://elevenlabs.io/docs/overview/administration/billing)
- [ElevenLabs legacy usage-based billing price](https://elevenlabs.io/docs/help-center/account/general/what-is-the-price-for-usage-based-billing)
- [ElevenLabs credit-to-character rules](https://help.elevenlabs.io/hc/en-us/articles/27562020846481-What-are-credits)
- [ElevenLabs API response headers, including `character-cost`](https://elevenlabs.io/docs/api-reference/introduction/)
- [OpenAI main API pricing](https://openai.com/api/pricing/)
- [OpenAI detailed API pricing](https://developers.openai.com/api/docs/pricing)
- [OpenAI `gpt-4o-mini` model pricing](https://developers.openai.com/api/docs/models/gpt-4o-mini)
- [OpenAI `gpt-5.6-luna` model pricing](https://developers.openai.com/api/docs/models/gpt-5.6-luna)
- [OpenAI `gpt-5.4-mini` model pricing](https://developers.openai.com/api/docs/models/gpt-5.4-mini)
- [OpenAI `tts-1` model pricing](https://developers.openai.com/api/docs/models/tts-1)
- [OpenAI `tts-1-hd` model pricing](https://developers.openai.com/api/docs/models/tts-1-hd)
- [OpenAI `gpt-4o-mini-tts` model pricing](https://developers.openai.com/api/docs/models/gpt-4o-mini-tts)
- [OpenAI model catalogue and deprecation status](https://developers.openai.com/api/docs/models/all)
- [Google Cloud Text-to-Speech pricing](https://cloud.google.com/text-to-speech/pricing)
- [Apple AVFoundation speech synthesis](https://developer.apple.com/documentation/avfoundation/speech-synthesis)
- [Apple `CLGeocoder` documentation and operating limits](https://developer.apple.com/documentation/corelocation/clgeocoder)
- [Apple coordinate and placename conversion guidance](https://developer.apple.com/documentation/corelocation/converting-between-coordinates-and-user-friendly-place-names)
- [Apple Staff native MapKit cost statement](https://developer.apple.com/forums/thread/127493)
- [Bank of England daily spot exchange rates against sterling](https://www.bankofengland.co.uk/boeapps/database/Rates.asp?into=GBP&rateview=L)

## Pricing Ambiguities Requiring Validation

- OpenAI's web-search pages conflict on whether current search-content tokens are free.
- OpenAI's main API pricing and model-catalogue page conflict on `gpt-5.6-luna` standard rates.
- OpenAI does not provide a current exact duration conversion for `gpt-4o-mini-tts`, and the catalogue marks it deprecated.
- ElevenLabs legacy and Enterprise overage rates are account-specific rather than publicly tabulated.
- ElevenLabs shared voices can apply custom multipliers.
- Apple publishes operating guidance but no exact native geocoding quota or SLA.
- Google and ElevenLabs free tiers and grants can change and should not support the steady-state margin case.
