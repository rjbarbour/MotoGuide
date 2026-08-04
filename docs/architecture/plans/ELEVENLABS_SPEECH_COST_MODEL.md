# ElevenLabs Speech Cost Model

Date: 2026-07-03

Status: Planning note. Use this to shape premium speech, credits, and default fallback behaviour.

> Pricing warning (2026-08-04): this note's `$0.05 per 1,000 characters` assumption matches current ElevenLabs Flash/Turbo, not RideHorizon's configured `eleven_multilingual_v2`, which is currently published at `$0.10 per 1,000 characters`. Use [RIDEHORIZON_UNIT_ECONOMICS_MODEL.md](../../product/strategy/RIDEHORIZON_UNIT_ECONOMICS_MODEL.md) for current commercial planning.

## Summary

ElevenLabs speech looks viable as a premium feature.

At `$0.05` per `1,000` characters, even a rich full-day ride is likely to cost only a few dollars in generated speech for one rider if every spoken segment is generated on demand.

The first product shape should not assume every rider wants dense audio all day. Many riders will lower content frequency, choose short facts, or ride in names-only mode for some sections.

Use Apple text-to-speech as the default fallback. Use ElevenLabs for premium voice quality when the rider has credits, an active subscription, or a higher-capacity plan.

## Product Term

Use `spoken segment` as the working product term.

Avoid `utterance` in rider-facing copy. It is technically correct in speech systems, but sounds unnatural.

Possible internal terms:

- `spokenSegment`
- `speechSegment`
- `announcement`
- `premiumSpeechSegment`

Recommended user-facing language:

- `premium voice`
- `spoken facts`
- `voice credits`
- `premium narration`

## Ride Assumption

Example ride:

```text
Guildford -> Faversham -> Guildford
```

Assumed distance:

```text
250 miles
```

Assumed road style:

```text
B-roads and scenic A-roads across southeast England
```

Likely counties:

```text
4 to 6
```

Likely towns, villages, and notable settlements passed:

```text
35 to 55
```

Likely usable place, landscape, road, and local-history facts:

```text
75 to 150
```

This is enough content for a full day, but not all of it should be spoken. Rider safety and tolerance matter more than maximum fact density.

## Character Estimates

Practical segment lengths:

| Segment type | Typical characters | Use |
| --- | ---: | --- |
| Basic geography | `100` to `180` | Place, county, region, boundary context |
| Short fact | `160` to `260` | One useful sentence |
| Long fact | `450` to `700` | Premium richer narration |
| Transition / intro / outro | `100` to `250` | Sparse route context |

Solid full-day estimate:

| Content | Count | Average characters | Total characters |
| --- | ---: | ---: | ---: |
| Basic geography | `35` | `140` | `4,900` |
| Short facts | `50` | `220` | `11,000` |
| Long facts | `20` | `600` | `12,000` |
| Transitions | `15` | `180` | `2,700` |
| **Total** |  |  | **`30,600`** |

Rich full-day estimate:

| Content | Count | Average characters | Total characters |
| --- | ---: | ---: | ---: |
| Basic geography | `45` | `150` | `6,750` |
| Short facts | `70` | `240` | `16,800` |
| Long facts | `35` | `650` | `22,750` |
| Transitions | `20` | `200` | `4,000` |
| **Total** |  |  | **`50,300`** |

## Cost Estimate

Formula:

```text
cost = characters / 1,000 * $0.05
```

| Usage level | Characters | ElevenLabs cost |
| --- | ---: | ---: |
| Light | `15,000` | `$0.75` |
| Normal | `25,000` | `$1.25` |
| Solid | `30,600` | `$1.53` |
| Rich | `50,300` | `$2.52` |
| Very rich | `80,000` | `$4.00` |
| Maximum planning cap | `120,000` | `$6.00` |

Planning conclusion:

```text
$1.00 to $3.00 is a realistic per-rider full-day range.
$6.00 is a conservative upper planning cap, not the expected normal cost.
```

For a full-day tour guide, even `$6.00` is cheap in absolute value. The product risk is not raw speech cost. The risk is whether riders value premium voice enough to pay, and whether too much speech becomes annoying.

## Packaging Implication

Recommended model:

1. Give every rider a small number of premium spoken segments.
2. Fall back to Apple text-to-speech when premium capacity is exhausted.
3. Let paid riders use more premium voice through credits or subscription tiers.
4. Cache generated speech where legally and technically allowed so repeated facts do not need to be regenerated.

Possible free tier:

```text
First 10 to 25 premium spoken segments included.
Then fall back to Apple text-to-speech.
```

Possible credit unit:

```text
1 credit = 1,000 generated characters
```

This maps directly to provider cost and is easy to reason about internally. Rider-facing copy may be simpler as `voice credits`.

## Tier Sketch

| Tier | Premium voice capacity | Fallback |
| --- | ---: | --- |
| Free | First `10` to `25` premium spoken segments | Apple text-to-speech |
| Day pass | Enough credits for one rich day | Apple text-to-speech after credits |
| Monthly | Higher recurring credit allowance | Apple text-to-speech after credits |
| Touring / annual | Large credit allowance for trips | Apple text-to-speech after credits |

Do not hide core RideHorizon value behind ElevenLabs.

Names-only and basic Apple text-to-speech should keep the product useful. Premium voice should make the ride feel better, not make the app function at all.

## Product Controls

Riders should be able to reduce cost and distraction by setting:

- Content density: sparse, normal, rich.
- Content depth: names only, short facts, long facts.
- Premium voice: on, off, credits only.
- Fallback voice: Apple text-to-speech.

Default should be conservative:

```text
Short facts, normal density, Apple text-to-speech fallback, premium voice only while credits remain.
```

## Open Questions

- What is the right free allowance: `10`, `15`, `25`, or another number of premium spoken segments?
- Should a day pass be sold by credits, ride duration, or simple `premium voice for today` language?
- Can generated audio be cached per fact, voice, and locale under the provider terms?
- Should long facts always require premium capacity, or should Apple text-to-speech read long facts after credits run out?
- What density setting feels acceptable on a real ride through towns, villages, and county boundaries?

## Current Recommendation

Treat ElevenLabs as a premium voice layer, not the core content system.

Build the product so it works with Apple text-to-speech first. Add premium voice credits on top. Budget normal full-day usage at `$1.00` to `$3.00` per rider, with `$6.00` as a conservative cap for a very rich day.
