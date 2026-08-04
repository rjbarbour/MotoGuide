# Great Britain Wikipedia geographic corpus: storage estimate

Date: 2026-08-04

## Bottom line

A useful Great Britain-only, text-only Wikipedia corpus would probably occupy:

| Form | Practical estimate | Deliberately broad upper case |
|---|---:|---:|
| Extracted UTF-8 article text | 150–600 MB | 0.6–1.1 GB |
| Compressed corpus, not directly full-text searchable | 40–200 MB | 150–350 MB |
| On-device store with coordinates, metadata and full-text search | 300 MB–1.2 GB | 1–2 GB |

These are engineering estimates, not a published Wikimedia dataset size. Wikimedia does not publish a Great Britain geography-only dump, and “geographical article” has no single objective boundary. The estimate therefore depends more on the selection rule than on compression.

The complete corpus could fit on a current iPhone. That does not make bundling it with the app the best first architecture. The recommended approach is a canonical server-side corpus, plus a much smaller on-device geographic index and cache. An optional downloadable offline Great Britain pack could be added later if field testing shows that it is valuable.

## Evidence and method

### Wikimedia baselines

The English Wikipedia API reported 7,219,021 articles and 5,247,874,949 article words on 2026-08-04: an average of about 727 words per article. This is a useful scale check, although British place articles are generally shorter than the English Wikipedia average. [English Wikipedia site statistics API](https://en.wikipedia.org/w/api.php?action=query&meta=siteinfo&siprop=statistics&format=json)

The 2026-07 English Wikipedia current-article dump is 25,452,565,841 bytes in its normal bzip2 form, or 26,564,488,717 bytes in the random-access multistream form. It contains current article content as wikitext inside XML, not cleaned plain text. [Wikimedia English Wikipedia dump index](https://dumps.wikimedia.org/enwiki/latest/) Wikimedia documents `pages-articles` as current subject-page content and explains the XML wrapper and compression formats. [Available dump types](https://meta.wikimedia.org/wiki/Data_dumps/What%27s_available_for_download) [Dump format](https://meta.wikimedia.org/wiki/Data_dumps/Dump_format)

### Geographic upper bound measured from the Wikimedia dump

I downloaded the 2026-07 English Wikipedia `geo_tags` SQL dump and counted unique pages with a primary Earth coordinate inside a broad rectangle covering Great Britain:

- Latitude: 49.8° to 60.9° north.
- Longitude: 8.7° west to 1.8° east.
- Result: 120,099 unique page IDs.

This is an intentionally loose upper bound, not the target corpus. It includes Northern Ireland, much of Ireland, a small continental fringe, buildings, railway stations, schools, constituencies and other coordinate-bearing articles outside the requested product scope. It can also omit geographic articles whose pages lack a primary coordinate. Wikimedia describes `geo_tags` as the dump containing page coordinate information, and its schema identifies the page ID, globe, primary-coordinate flag, latitude, longitude and optional type. [Wikimedia dump catalogue](https://meta.wikimedia.org/wiki/Data_dumps/What%27s_available_for_download#Database_tables) [GeoData `geo_tags` schema](https://www.mediawiki.org/wiki/Extension:GeoData/geo_tags_table)

A deterministic random sample of 393 live main-namespace pages from those 120,099 page IDs had:

- Mean current wikitext length: 9,013 bytes.
- Median: 5,288 bytes.
- Interquartile range: 3,148–9,616 bytes.
- Extrapolated wikitext total for the entire loose rectangle: about 1.01 GiB.

The page lengths came from the official MediaWiki Action API. The sample contains the broad range expected from the upper-bound selection, including settlements, administrative areas, roads, stations, buildings and constituencies. A plain-text extraction removes templates, references, tables and wikitext markup, so its byte size should be lower than this wikitext measurement. MediaWiki's TextExtracts documentation confirms that plain-text extraction strips or transforms page content, although it also documents edge cases. [TextExtracts API](https://www.mediawiki.org/wiki/Extension:TextExtracts)

### Target article-count assumption

For the requested scope—towns, villages, counties, regions, national parks and major named geographic features—I would budget for 30,000–70,000 articles.

This is a product-selection assumption, not a Wikimedia statistic. It represents roughly 25–60% of the 120,099-page geotagged upper bound. The lower end is a curated corpus of recognised settlements, administrative areas, protected landscapes and prominent physical features. The upper end includes hamlets, local landscape areas, rivers, hills, lakes, islands and other features with plausible touring value.

A build pipeline should establish the real count using explicit Wikidata classes and territorial rules, then publish a manifest. Wikidata's query service can select items by stated properties, subclass relationships and English Wikipedia sitelinks, but Wikimedia advises using dumps rather than the public query endpoint for large result sets. [Wikidata data access guidance](https://www.wikidata.org/wiki/Help:Data_access) [Wikidata Query Service](https://www.wikidata.org/wiki/Wikidata:SPARQL_query_service)

## Derivation of the ranges

### Extracted plain text: 150–600 MB

The measured median wikitext page was about 5.3 KB and the mean was about 9 KB. For a narrower geographic corpus, budgeting 5–8 KB of cleaned UTF-8 text per article gives:

- 30,000 × 5 KB ≈ 150 MB.
- 70,000 × 8 KB ≈ 560 MB.

Rounding gives 150–600 MB. Retaining long tables, lists, references or full article structure could push the corpus towards the 0.6–1.1 GB upper case. Retaining only introductory sections or pre-written fact snippets would make it materially smaller.

### Compressed corpus: 40–200 MB

Plain prose commonly compresses substantially because names, markup patterns and phrases repeat. A planning ratio of 3:1 to 5:1 produces approximately 40–200 MB from the target raw-text range. This should be validated on the first real extraction rather than treated as a guaranteed ratio. Wikimedia uses bzip2 for article XML dumps and documents why its block structure supports recovery and random access. [Wikimedia dump FAQ](https://meta.wikimedia.org/wiki/Data_dumps/FAQ)

### Searchable on-device store: 300 MB–1.2 GB

A compressed archive alone is not enough for low-latency lookup. The app would need some combination of:

- Article text or independently decompressible blocks.
- Coordinates and geographic coverage.
- Article-to-place and feature-type metadata.
- A title/alias index.
- Optionally a full-text index.

Allowing roughly 1.5–2 times the extracted-text size for text, metadata and a full-text index, with packaging headroom, gives 300 MB–1.2 GB. A coordinate/title lookup without full-text search could stay much closer to the compressed-corpus range. The exact multiplier is an implementation choice and must be measured using the intended SQLite, FTS or custom index.

## Phone versus server

### Recommended architecture

Keep the canonical Wikipedia-derived corpus and content-generation pipeline on the server. Put the following on the phone:

- A compact place/feature gazetteer with identifiers, coordinates, boundary references, prominence and aliases.
- Previously generated and verified facts.
- Synthesised speech audio needed for replay and normal caching.
- Optionally, a downloadable regional or Great Britain offline pack.

This preserves offline resilience without forcing every installation to carry a large, frequently changing corpus. It also lets the server improve filtering, deduplication, safety and fact generation without shipping an app update.

### Why not bundle the whole corpus first

- Initial app download and backup footprint would increase by hundreds of megabytes.
- Wikipedia changes continuously; delta updates and corpus versioning become an app responsibility.
- Raw articles are not ready-to-speak content. They still require selection, attribution-aware transformation, grounding and short-form generation.
- Geographic selection errors are easier to correct centrally.
- The server already remains useful for TTS and generated-fact workflows, so a full local corpus would not by itself remove the network dependency.

### When a full offline pack becomes worthwhile

A downloadable pack is sensible if field trials show unreliable connectivity on touring routes and riders value offline facts. It should be an optional post-install download, versioned separately from the app. Start with one representative region, measure the actual article count, extracted bytes, index overhead and hit rate, then extrapolate to Great Britain.

## Important non-storage constraints

Wikipedia text is reusable, but Wikimedia states that its text is licensed under CC BY-SA 3.0 and GFDL. The product needs an attribution and licence-compliance design, including source links and corpus-version provenance. [Wikimedia research data and licensing](https://meta.wikimedia.org/wiki/Research:Data)

The corpus manifest should also record:

- Wikipedia page ID and revision ID.
- Wikidata item ID where available.
- Source URL and retrieval date.
- Selection class and reason for inclusion.
- Coordinates or boundary relationship.
- Redirects and aliases.
- Whether stored text is full article, lead only or a derived fact.

## Recommended next measurement

Do not download and integrate the whole English dump yet. Build a throwaway extraction for the Gloucestershire test area using the intended Wikidata class allow-list. Measure:

1. Selected article count.
2. Cleaned lead-only and full-text byte totals.
3. Compression ratio.
4. SQLite/index overhead.
5. Percentage of ride announcements served usefully by the corpus.

That experiment will turn the broad national estimate into an architecture decision based on RideHorizon's actual content policy.
