# Local LLM Facts Fallback Plan

Date: 2026-07-01

Status: Alternative plan. Do not implement before the OpenAI proxy path has been tested on real rides.

## Decision

Use the existing OpenAI-backed fact proxy as the first Short Facts implementation.

Current proxy contract: `FACT_PROXY_OPENAPI.yaml`, with `FACT_PROXY_CONTRACT.md` as the human-readable companion.

Keep this plan as a fallback if OpenAI cost, latency, connectivity, privacy, or reliability becomes a problem during MVP1 field testing.

## Goal

Generate one short, rider-safe place fact without depending on OpenAI for the final wording.

The local model should summarize trusted source text. It should not be treated as the source of truth for place facts.

## Proposed Pipeline

```text
Boundary change
-> reverse-geocoded place name and coordinates
-> Wikimedia lookup
-> candidate ranking and source extract
-> Apple Foundation Models summarization
-> cached spoken sentence
```

## Source Data

Use Wikimedia APIs as the first source candidate:

- Wikipedia page summary for exact town, county, or landmark matches.
- Geosearch around the current coordinate for nearby notable places.
- Wikidata IDs where useful for stable identity and caching.

Do not scrape rendered Wikipedia pages. Use APIs with a clear MotoGuide User-Agent and cache responses.

## Local Model

Use Apple's Foundation Models framework when available on the rider's device.

Expected role:

- Rewrite or summarize supplied source text.
- Keep output to one sentence.
- Remove detail that is not useful while riding.
- Follow strict length and safety instructions.

Do not ask the model to invent facts from a place name alone.

## Prompt Shape

Input:

- Place name.
- Boundary type: town, county, region, country, landmark.
- Trusted source extract.
- Maximum spoken length.

Instruction:

```text
Use only the source text.
Write one factual sentence for a motorcyclist.
Keep it under 20 words.
Do not give route, speed, safety, or navigation advice.
If the source is weak or ambiguous, return no fact.
```

## Quality Expectations

This should work well for:

- UK towns with clear Wikipedia pages.
- Counties and regions.
- Castles, bridges, historic sites, and other notable landmarks.
- Short summaries where the source text is already good.

This will be weaker for:

- Tiny villages.
- Suburbs with ambiguous names.
- Road junctions and unnamed rural areas.
- Places where the nearest Wikipedia page is not actually relevant to the rider.

## Acceptance Criteria

- Names-only fallback remains available at every failure point.
- No spoken sentence exceeds the configured maximum length.
- The app can reject ambiguous or low-confidence Wikimedia matches.
- Facts are cached by stable page identity and source revision where possible.
- The rider hears no attribution text during the ride.
- Attribution and source links are visible in the app log or details view.
- Unit tests cover exact match, ambiguous match, no match, weak source, and offline cache hit.

## When To Revisit

Revisit this plan after OpenAI-backed Short Facts have been tested on real rides if one or more of these happens:

- Network latency makes announcements arrive too late.
- OpenAI cost is material for normal riding.
- Prompted OpenAI facts are not reliable enough.
- Privacy requirements make server-side fact generation undesirable.
- Offline or poor-signal rides become an MVP1 requirement.

## Current Recommendation

Do not implement this yet.

OpenAI has enough capability for reliable short place facts when prompted and constrained correctly. The existing proxy path is simpler for MVP1 because it avoids early work on Wikimedia ranking, attribution UI, local model availability checks, and device-specific quality testing.
