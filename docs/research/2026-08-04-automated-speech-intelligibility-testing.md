# Automated speech-intelligibility testing research

Date: 2026-08-04

Status: Research and proposed experiment design only. No application code, test harness, build, deployment or production profile has been changed.

## Bottom line

RideHorizon can automate useful intelligibility screening, including progressively raising a motorcycle/music masker and estimating the signal-to-noise ratio at which recognition fails. No single objective metric proves what a rider will understand, however. The recommended evidence stack is:

1. deterministic signal and safety measurements;
2. intrusive intelligibility metrics such as ESTOI against the clean reference;
3. word error rate from a frozen automatic speech-recognition model across a signal-to-noise ladder;
4. a fitted proxy speech-reception threshold and curve;
5. human transcription and real-ride validation for the finalists.

Use an automated optimiser only after the evaluation harness, held-out corpus and rejection constraints are frozen. For the small numerical parameter space expected here, design-of-experiments followed by constrained Bayesian optimisation is more appropriate than a genetic algorithm or an unconstrained self-modifying agent.

## What can be measured automatically

For each clean announcement, processing profile and masker:

1. Render the processed speech once.
2. Measure active speech level and set the masker to controlled relative levels, for example `+12, +9, +6, +3, 0, −3, −6 and −9 dB` speech-to-masker ratio.
3. Retain the clean processed reference and every aligned masked result.
4. Calculate objective intelligibility, loudness, peak, distortion and dynamics measurements.
5. Transcribe every masked result with the same frozen ASR model and configuration.
6. Compare the transcript with the known announcement text using word error rate or normalised edit distance.
7. Fit a psychometric curve and estimate the SNR producing 50% word recovery.

The resulting value must be labelled **ASR proxy SRT50** until it has been correlated with human listeners. A machine recogniser and a motorcyclist do not have the same frequency selectivity, linguistic priors, hearing, helmet or attention.

## Standards and validated methods

### Human TTS intelligibility

[ANSI/ASA S3.50-2013 (R2022)](https://webstore.ansi.org/standards/asa/asaansis3502013r2022) directly addresses TTS intelligibility. Human listeners record the words or sentences they hear; word- or segment-level normalised edit distance is the score. This is the most directly relevant final laboratory method, but it is not fully automated.

[ISO 8253-3:2022](https://www.iso.org/standard/74049.html) specifies requirements for speech-recognition testing, including competing noise, test-material validation, presentation and reporting. Speech-in-noise performance is commonly represented as percentage correct at a fixed SNR or the SNR needed for 50% recognition.

### SII and STI

[ANSI/ASA S3.5](https://webstore.ansi.org/standards/asa/asaansis31997r2024) defines the Speech Intelligibility Index from the weighted audibility of speech across frequency bands. SII is useful for explaining which speech bands are masked, but calibrated speech/noise levels and hearing assumptions matter.

[IEC 60268-16:2020](https://webstore.iec.ch/en/publication/26771) defines the Speech Transmission Index. It is primarily a transmission/acoustic-channel measure. The standard explicitly notes limitations for fluctuating noise and systems containing nonlinear processing. Motorcycle wind, compression and limiting make STI useful supporting evidence rather than the principal optimiser score.

### STOI and ESTOI

STOI and extended STOI are intrusive metrics: they compare a time-aligned clean reference with degraded speech and estimate intelligibility from short-time spectral-envelope relationships. They are well suited to quickly ranking large numbers of speech-plus-noise renders. The MIT-licensed [`pystoi`](https://github.com/mpariente/pystoi) implements both metrics and is the appropriate measurement tool. The differentiable [`pytorch_stoi`](https://github.com/mpariente/pytorch_stoi) is intended as a training loss and explicitly does not reproduce the original metrics exactly, so it should not be the reporting reference.

They remain predictors, not proof. They can rank processing differently from human listeners, and an optimiser may exploit their assumptions. Retain a clean-quality constraint and validate their ranking against human results.

### Active level, loudness and true peak

[ITU-T P.56](https://www.itu.int/rec/T-REC-P.56/en) provides a comparable active-speech-level measurement. This is preferable to whole-file RMS for short announcements containing silence.

[ITU-R BS.1770](https://www.itu.int/rec/R-REC-BS.1770/en) provides loudness and true-peak algorithms. These constrain level and clipping but do not themselves measure intelligibility.

### Automatic speech recognition

[OpenAI Whisper](https://github.com/openai/whisper) is an available frozen ASR baseline and reports recognition using word or character error rate. Its training was designed for robustness to varied audio and background noise, which makes it useful for a repeatable proxy but also means it may understand material a rider cannot. Run it deterministically, disable language-model prompting from the reference text, retain insertions/deletions/substitutions separately, and reject hallucinated text rather than treating it as partial understanding.

An ASR ensemble can test sensitivity to one recogniser, but it does not turn machine recognition into a human standard. One stable model is preferable during optimisation; use a second model only as held-out evaluation.

## Recommended RideHorizon corpus

Use a fixed development set and a separate held-out set containing:

- short and confusable UK place names;
- county, nation and country boundary phrases;
- numbers and road-relevant proper nouns;
- typical short facts;
- male/female or voice variants only if they are genuine product candidates;
- quiet, music-dominant, wind-dominant and engine/wind maskers; and
- several unseen excerpts from Rob's privacy-clean in-helmet recordings.

Do not optimise and report on the same phrases and masker excerpts. Preserve exact audio, text, processing revision, masker, SNR, random seed and tool versions for every result.

## Proposed score and rejection constraints

Prefer a Pareto comparison or constrained objective over one opaque weighted score.

Optimise:

- lower ASR proxy SRT50 across maskers;
- lower held-out word error rate across the useful SNR band;
- higher median and worst-decile ESTOI; and
- consistent results across place names and facts rather than a high overall mean that hides failures.

Constrain:

- true peak at or below the accepted ceiling;
- zero clipped samples after every encode/decode boundary;
- active speech loudness within the accepted calibration band;
- bounded compressor and limiter gain reduction;
- bounded clean-reference degradation;
- no lost word onsets or excessive duration change;
- processing time within the playback budget; and
- human rejection for harshness, pumping, discomfort or unsafe stopped-condition loudness.

A candidate that improves ASR or ESTOI but violates a rejection constraint loses. Do not allow the optimiser to trade hearing safety or distortion for its headline score.

## Optimisation approach

The likely adjustable space is small: loudness target, maximum gain, compressor threshold/ratio/attack/release, presence frequency/gain/bandwidth, high-pass frequency and limiter behaviour.

Recommended sequence:

1. Establish the unprocessed and current-production baselines.
2. Run a coarse factorial or Latin-hypercube design to expose main effects and interactions.
3. Remove parameters with little measurable effect and reject unsafe regions.
4. Use constrained Bayesian optimisation on the remaining continuous parameters.
5. Re-run finalists on the frozen held-out phrases, maskers and second ASR.
6. Take no more than the top three non-dominated candidates to blinded human transcription and helmet tests.

A genetic algorithm is possible, but it is less sample-efficient and harder to interpret for this low-dimensional problem. It becomes more attractive only if the parameter space grows large, discontinuous or strongly combinatorial.

## Karpathy-style automated research loop

[Karpathy's `autoresearch`](https://github.com/karpathy/autoresearch) demonstrates a useful pattern: a mutable experiment target, immutable preparation/evaluation code, fixed time budget, one mechanical metric and keep/discard logging. The pattern can be adapted, but its single-metric greedy loop should not be copied literally.

For RideHorizon:

- the agent may propose a processing profile or experiment;
- the renderer and evaluation harness must be immutable during a run;
- the development and held-out corpora must be immutable;
- safety and distortion constraints must be non-negotiable;
- all trials, including failures, must be retained in an append-only result ledger;
- repeated trials must be deterministic before unattended iteration; and
- the loop must stop before changing app production defaults or replacing human validation.

The optimiser must never edit the score, test audio, transcripts, SNR calculation or rejection thresholds. Otherwise it can improve the reported number without improving rider intelligibility.

## Recommended bounded probe

Build the first harness offline, outside the iOS production binary:

1. Freeze 30–50 RideHorizon announcement texts and several privacy-clean maskers.
2. Render raw ElevenLabs fixtures once with provenance.
3. Implement the exact app processing profile in a deterministic command-line renderer or invoke a shared processing library.
4. Produce the SNR ladder and calculate P.56 active level, BS.1770 loudness/true peak, ESTOI and ASR WER.
5. Fit an ASR proxy SRT50 for each phrase/profile/masker and report distributions, not only averages.
6. Compare the automated ranking with a small blinded human transcription set.
7. Proceed to optimisation only if the automated metrics correctly rank the human baseline conditions.

The stop condition is evidence that the automated ranking correlates sufficiently with Rob/human transcription to screen candidates. If it does not, retain the harness for signal diagnostics but do not use it to optimise the production profile.
