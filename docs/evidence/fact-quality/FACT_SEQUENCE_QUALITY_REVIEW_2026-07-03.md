# RideHorizon Fact Sequence Quality Review

Date: 2026-07-03

Scope: review the latest generated facts from `docs/evidence/fact-quality/FACT_QUALITY_REVIEW_2026-07-03.md`, especially:

- `length-range-iteration-3-diverse`
- `length-range-iteration-3-gloucestershire`

This document is separate from the raw generation log. Use separate review documents for later prompt or contract loops.

## Verdict

The latest facts are better as isolated place descriptions, but not good enough as a ride sequence.

The main quality problem is repetition across nearby places:

- Gloucestershire, Nailsworth, Minchinhampton, Stroud, and Stonehouse repeatedly mention Cotswolds, limestone, valleys, stone buildings, old routes, mills, wool, and cloth.
- This is locally relevant, but it would sound stale if spoken across several consecutive villages.
- The current proxy treats each place mostly in isolation. It has no route memory, no previous-spoken topic list, and no explicit regional context state.

The prompt can reduce generic filler, but prompt-only changes cannot fully solve ride-sequence repetition.

## Latest Output Review

### What Improved

- Short Facts are now close to the desired spoken size.
- Long Facts are now compact enough for explicit rider-selected mode.
- POI handling improved: Severn Bridge, Tintern Abbey, Gloucester Cathedral, and Minchinhampton Common are mostly described as objects/sites rather than generic towns.
- Roadcraft filler is mostly gone.
- Facts are now more adult and locally grounded than the original road-warning-heavy outputs.

### What Still Fails

Repeated regional language:

- `Cotswolds`, `limestone`, `stone-built`, `old routes`, `valleys`, `mills`, `wool`, and `cloth` recur across the Gloucestershire sequence.
- This is correct regional context, but the rider does not need the same setup for every nearby town.

Weak sequence awareness:

- A first town in a region should introduce the region.
- The next town in the same region should either make a contrast or give one town-specific fact.
- If the next town has nothing genuinely distinct, RideHorizon should say only the town name or stay quiet.

Familiarity gap:

- Existing rider context supports home country, home region, familiar regions, and custom fact focus.
- It does not support a local quiet radius or "near home, names only" behavior.
- A rider near their home area probably does not want basic facts about neighboring towns.

Topic drift:

- Even after prompts say "unique", the model often falls back to region-wide motifs.
- This is expected because the model is not told what it already said.

## Product Rule

Use a layered place-awareness policy:

1. Region or geology first.
   - First time entering a meaningful region, explain the regional context.
   - Example: "You are entering the Low Weald, a clay vale of wooded lanes and market villages."

2. Subsequent towns in the same region.
   - Do not restate the same geology or regional story.
   - Use a distinct local anchor, contrast, or one specific town fact.
   - If no distinct anchor is available, use names-only.

3. POIs.
   - Describe the object or site directly.
   - Do not turn it into a generic town or county fact.

4. Familiar places.
   - If close to home or inside familiar local territory, default to silence or names-only.
   - Only speak a fact if it is unusually specific or rider-requested.

## Required Context Change

The fact proxy needs optional ride context.

Current proxy input is roughly:

```text
placeName
boundary
factMode
placeHierarchy
riderContext
```

Recommended added input:

```json
{
  "rideContext": {
    "sequenceIndex": 4,
    "currentRegionalContext": "Cotswolds escarpment and Stroud Valleys textile landscape",
    "previousSpokenPlaces": [
      {"placeName": "Gloucestershire", "boundary": "county", "topics": ["Cotswolds", "limestone", "Severn", "wool"]},
      {"placeName": "Nailsworth", "boundary": "town", "topics": ["Stroud Valleys", "mills", "textiles"]},
      {"placeName": "Minchinhampton", "boundary": "town", "topics": ["common land", "Cotswold stone"]}
    ],
    "avoidTopics": ["Cotswolds", "limestone", "stone buildings", "wool", "cloth", "old routes"],
    "desiredNovelty": "town-specific",
    "familiarityPolicy": "normal"
  }
}
```

Do not send raw coordinates or home addresses.

## Familiarity And Silence Policy

Add a device-side policy before calling the proxy:

| Situation | Behavior |
|---|---|
| Inside home quiet radius | Silent or names-only |
| Familiar town or familiar local area | Names-only unless rider asked for facts |
| Familiar county but unfamiliar town | One short town-specific fact only |
| New region or county | Short regional context allowed |
| Same region as last announcement | Avoid repeated region/geology setup |

Possible setting:

```text
Home quiet radius: Off, 5 miles, 10 miles, 25 miles
```

Expected behavior:

```text
If the rider is inside the selected quiet radius, RideHorizon does not request facts and either stays silent or speaks only place names based on user setting.
```

## Prompt Policy For Ride Context

When `rideContext` exists, the server prompt should add:

```text
Use previousSpokenPlaces and avoidTopics to avoid repeating regional setup.
If this place shares the same region/geology as the last spoken place, do not restate it.
Give one locally distinctive fact, a contrast with the previous place, or return a terse names-only-compatible fact.
If no distinctive fact is available, prefer no fact over filler.
```

The proxy response may eventually need:

```json
{
  "fact": "Stonehouse grew around transport links more than the hill-town cloth identity you just heard in Stroud.",
  "topics": ["rail", "canal", "transport"],
  "novelty": "contrasts-with-previous"
}
```

This lets the app build a topic cooldown without parsing natural language.

## Latest Examples

Good enough isolated example:

```text
Severn Bridge carries the main crossing over the River Severn between England and Wales, linking the approach roads to Chepstow in Monmouthshire. Its long, steel suspension span is a defining modern landmark here, reshaping travel along an older river-crossing corridor.
```

Why it works:

- Object/site-specific.
- Not a generic town description.
- Ties visible infrastructure to regional movement.

Weak as sequence example:

```text
Stonehouse in Gloucestershire sits on the edge of the Cotswolds, with the Stroud Valleys’ industrial heritage shaping its streets and mills. The town’s older road pattern reflects its role in regional trade, and stone-built buildings give it a distinct local character.
```

Why it weakens in sequence:

- Repeats Cotswolds, Stroud Valleys, industry, older roads, and stone buildings after nearby towns.
- Needs a more distinct Stonehouse-specific contrast or should be names-only.

Better target:

```text
Stonehouse is the transport-linked valley town after Stroud: its story is less hilltop cloth village and more rail, canal, and working corridor between the Severn side and the Cotswold edge.
```

## Recommended Next Implementation

1. Add an optional `rideContext` object to the fact proxy contract.
2. Add a small app-side topic memory for the last 3-5 spoken facts.
3. Add a `topics` field to the proxy response, or derive coarse topic tags on the client for MVP.
4. Add a home quiet radius setting.
5. Update the prompt to use `avoidTopics` and `previousSpokenPlaces`.
6. Run a sequence-specific evaluation fixture rather than isolated rows.

Exact command to rerun the current diverse fixture:

```bash
cd /Users/rob_dev/DocsLocal/motoguide/repo
uv run --python 3.13 /Users/rob_dev/DocsLocal/motoguide/repo/scripts/review_fact_quality.py --label sequence-baseline --rider-context full --fixture diverse --output docs/evidence/fact-quality/FACT_SEQUENCE_QUALITY_REVIEW_2026-07-03.md --retain-generated-facts
```

Expected result:

```text
Wrote 20 generated fact rows to /Users/rob_dev/DocsLocal/motoguide/repo/docs/evidence/fact-quality/FACT_SEQUENCE_QUALITY_REVIEW_2026-07-03.md
```

That command still tests isolated proxy calls. The next harness should simulate a route and pass previous-place/topic context once the contract supports it.

## Run sequence-baseline-isolated-calls - 2026-07-03T01:16:39Z

- Base URL: `https://ridehorizon.digitalmercenaries.ai`
- Fixture: `sequence`; no live coordinates.
- Sequence fixture is ordered to expose repeated regional wording. It still sends isolated proxy calls until rideContext exists.
- Rider context: UK rider, West Midlands, familiar with England and the Cotswolds; interests in history, landmarks, old roads, landscape, and industry.

| Place | Mode | Status | Fact | Score Notes |
|---|---|---|---|---|
| Gloucestershire | `shortFacts` | TimeoutError | The read operation timed out |  |
| Gloucestershire | `longFacts` | ok | Gloucestershire sits where the Cotswolds’ limestone escarpments give way to the broader Severn valley, so the county’s character swings between honey-coloured villages and river-and-estuary landscapes. The River Severn has long shaped trade and industry, linking inland markets to the Bristol Channel. Old routes thread through market towns and former coaching corridors, with stone churches and manor houses reflecting centuries of wool, cloth, and later engineering along waterways. In the Forest of Dean, ironworking heritage and woodland industry add a darker, industrial edge to the county’s scenery. |  |
| Nailsworth | `shortFacts` | ok | Nailsworth sits in the wooded Stroud valley on the edge of the Cotswolds, where steep lanes and old mill sites reflect its long textile and paper-making past. The town’s stone buildings and industrial heritage sit close to the waterways that powered local industry. |  |
| Nailsworth | `longFacts` | ok | Nailsworth sits in a wooded Cotswold landscape where steep lanes drop toward the valleys, giving the town a distinctly “hillside” feel. The area is closely tied to the industrial heritage of the Stroud valleys: mills and workshops grew around water power and cloth production, and you can still read that working past in the older mill buildings and terraces. The town’s older road network threads through the slopes, linking it to the surrounding market centres. Nearby, the countryside and stone-built character make Nailsworth a memorable stop on the Cotswold edge. |  |
| Minchinhampton | `shortFacts` | ok | Minchinhampton sits on the edge of the Cotswolds’ limestone country, with views over the Stroud valleys and the distinctive honey-coloured stone built into its older streets. The area’s long-running wool and cloth trade shaped local industry and churchyard monuments. |  |
| Minchinhampton | `longFacts` | ok | Minchinhampton sits on the edge of the Cotswolds’ high ground, where the landscape shifts from open chalky slopes into wooded valleys. The town’s identity is tied to the old wool and cloth economy, reflected in the stone-built streets and the working heritage of the area’s mills and workshops. Nearby, the distinctive escarpment and limestone outcrops shape the views and the feel of the old routes that link settlements across the hills. The parish church and local stone architecture give the centre a compact, historic character. |  |
| Stroud | `shortFacts` | ok | Stroud in Gloucestershire sits where the Cotswolds’ limestone edge meets the wooded valleys, with the River Frome running through the town’s industrial past. Old mills and stone-built terraces reflect the area’s textile heritage, and the town’s market streets keep that working character. |  |
| Stroud | `longFacts` | ok | Stroud sits in a steep-sided valley landscape of the River Frome and its tributaries, where water power shaped the town’s working life. The area is closely tied to the wool and cloth trade, with old mills and terraces reflecting an industrial past that still reads in the built fabric. Stroud’s older street pattern and market culture give it a distinct character beyond a commuter town, and the surrounding hills frame views across the Cotswold edge. The town’s heritage is also visible in its historic churches and mill buildings. |  |
| Stonehouse | `shortFacts` | ok | Stonehouse in Gloucestershire sits along the route of the old Stroud–Gloucester turnpike, with the town’s character shaped by nearby coal and textile work. You’ll see mill-era brickwork and canal-era industry echoes, while the surrounding hills frame short, historic road links. |  |
| Stonehouse | `longFacts` | ok | Stonehouse sits in the Stroud district of Gloucestershire, where the Cotswolds’ limestone edge gives way to greener, wooded valleys. The town’s character is shaped by the old industrial belt of the area: mills and workshops tied to cloth and engineering, with rail and canal-era connections that helped move goods through the valley. Stonehouse’s built fabric reflects that working past, alongside older stone terraces and local churches that anchor the streetscape. Nearby, the landscape of rolling hills and wooded slopes makes the town feel like a gateway between upland countryside and industrial valleys. |  |
| Painswick | `shortFacts` | ok | Painswick in Gloucestershire sits in the Cotswolds’ wooded hills, with limestone shaping its honey-coloured streets and views. The town is closely tied to the Painswick Rococo Garden and its famous “yew tree” tradition, reflecting centuries of local gentry wealth. |  |
| Painswick | `longFacts` | ok | Painswick sits on the edge of the Cotswolds escarpment in Gloucestershire, where steep limestone slopes and wooded combes shape the town’s compact streets and views. The area’s old stone building tradition is visible in honey-coloured walls and slate roofs, reflecting long-standing quarrying and local craftsmanship. Painswick is closely associated with the historic Painswick Rococo Garden, a distinctive landscaped site that draws visitors with its crafted terraces and stonework. The town’s parish church and older lanes preserve a sense of how trade and travel moved through this upland landscape. |  |
| Dursley | `shortFacts` | ok | Dursley sits in Gloucestershire’s Cotswold edge country, with the Stroudwater area’s industrial past shaping its streets and mills. The town’s older stone-and-brick buildings reflect the region’s manufacturing heritage, and nearby lanes connect into the wider Cotswold road network. |  |
| Dursley | `longFacts` | ok | Dursley sits on the edge of the Cotswolds’ limestone country, where wooded lanes and open fields give way to the town’s older industrial spine. The area’s cloth and paper-making heritage is still felt in the brickwork and mill-style buildings that line parts of the historic road network. Nearby, the Stroudwater Canal system and the broader river valleys shaped how goods moved through this part of Gloucestershire. Dursley’s character is closely tied to those working routes, with local churches and Victorian-era streetscapes reflecting the town’s growth during the industrial period. |  |

## Sequence Baseline Finding

The ordered sequence confirms the repetition risk.

Measured across 13 successful generated rows:

| Topic term | Rows containing it |
|---|---:|
| Cotswolds | 9 / 13 |
| limestone | 8 / 13 |
| stone | 9 / 13 |
| valley | 4 / 13 |
| valleys | 6 / 13 |
| wool | 4 / 13 |
| cloth | 7 / 13 |
| mill | 5 / 13 |
| mills | 6 / 13 |
| industrial | 8 / 13 |
| routes | 3 / 13 |
| canal | 3 / 13 |
| Severn | 1 / 13 |
| Frome | 2 / 13 |

Conclusion:

- The prompt is now good enough for isolated rows.
- It is not good enough for a sequence of nearby villages.
- The next improvement should not be another wording-only prompt tweak.
- The next improvement should add ride memory: previous spoken places, previous topics, current regional/geology context, and rider familiarity/silence policy.
