# Audio speech calibration follow-up research

> **Superseded implementation snapshot:** The Current A descriptions below record the peak-only production pipeline inspected before legacy RH-004G was authorised later on 2026-08-04. Backlog.md task RH-004.07 preserves the subsequently implemented phase-one production baseline; doc-001 preserves the original detailed evidence.

Date: 2026-08-04

Status: Historical research and implementation plan. At the time of this inspection no application code, build, deployment or production profile had been changed; RH-004G subsequently superseded the Current A implementation snapshot.

## Bottom line

- The output-volume observer uses the API Apple documents as key-value observable, but the physical-device result shows that this implementation is not delivering live values in the calibration lifecycle. A visible `MPVolumeView` is the strongest supported fallback because Apple explicitly documents that its slider follows hardware-button changes while sound is playing. Keep the numeric KVO value only as a diagnostic until the device behaviour is reproduced and explained.
- Candidate B is not raw ElevenLabs audio. With any edited Candidate B setting, the current chain is: decoded ElevenLabs fixture → 100 Hz high-pass → optional 2.8 kHz presence EQ → optional compressor → bounded peak normalisation → output gain → sample limiter. Current A decodes the same fixture and applies bounded peak normalisation, but no high-pass, presence EQ, compressor or limiter. The automatic normalisation is variable—between 0 and +6.02 dB—not a fixed +6 dB baseline. Candidate B’s output-gain control is already additional gain after that same calculation.
- The current Strong compressor is already a 4:1 soft-knee compressor at −24 dBFS with 10 ms attack and 120 ms release. The app does not report how often or how deeply it reduces gain, and it applies no explicit compressor make-up gain. Those omissions make “Strong” impossible to assess from the label alone and can make a material waveform change sound subtle.
- The rider’s `+12 dB / Strong / +6 dB` result is consistent with the implementation: extra gain drives the final limiter, so more gain can create flattening or distortion without producing a corresponding loudness advantage over dense music.
- Simulated road noise is useful as a repeatable stationary screen, but it cannot replace an actual ride because helmet aerodynamics, speaker coupling, earplugs and the specific Bluetooth headset all change the result. Preserve signal-to-noise ratio at a safe absolute playback level; do not reproduce real motorway sound pressure at the ears.

## 1. System output-volume reporting

### What Apple supports

`AVAudioSession.outputVolume` reports a value from 0.0 to 1.0 and Apple states that changes can be observed through key-value observing. Only the user can set system volume. Apple recommends `MPVolumeView` when an app needs a system-volume control ([Apple: `AVAudioSession.outputVolume`](https://developer.apple.com/documentation/avfaudio/avaudiosession/outputvolume)).

Apple also states that an on-screen `MPVolumeView` slider reflects the current system output volume and moves when the hardware volume buttons are pressed while sound is playing. For an output route that does not support volume control, such as some car head units, it shows the route rather than a slider ([Apple: `MPVolumeView`](https://developer.apple.com/documentation/mediaplayer/mpvolumeview)). This distinction matters for Bluetooth helmet testing: a number is not guaranteed to represent a controllable volume for every route.

Apple documents route-change notifications as the supported way to discover when an output is connected, removed or rerouted; after a change, the app should inspect `currentRoute` again ([Apple: responding to audio route changes](https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes)).

### Current RideHorizon implementation

`SystemSpeechCalibrationOutputVolumeObserver` retains an `NSKeyValueObservation` on the shared session's `outputVolume` and publishes the callback value. The model reads an initial value and starts the observer during initialisation (`RideHorizon/SpeechCalibrationLab.swift`, lines 176–198 and 270–286 at the time of this audit).

That structure is consistent with Apple's documented KVO mechanism. The physical result therefore establishes a real unresolved defect; it should not be dismissed as a screen-refresh problem. Plausible lifecycle variables to isolate are:

- whether RideHorizon’s audio session is active or inactive when the calibration page is idle;
- whether YouTube Music or RideHorizon currently owns active playback;
- whether the value changes during fixture playback but not while the lab is silent;
- whether the Bluetooth route exposes controllable system volume;
- whether route changes, session interruption/deactivation or media-services reset leave the observed session value stale; and
- whether `MPVolumeView` moves even when the KVO callback does not.

Apple’s public documentation does not state that KVO requires an active session, so that must be treated as a test hypothesis, not a fact. Activating RideHorizon’s audio session merely to obtain a display value may itself alter YouTube Music and is not an acceptable first fix.

### Planned correction

1. Add a bounded physical-device diagnostic that records initial value, KVO callback value, route, app foreground state, RideHorizon session active state and whether RideHorizon or external audio is playing. Do not log track identity or other personal media data.
2. Place a normal, visible `MPVolumeView` in the internal lab and compare it with the KVO percentage while pressing the hardware buttons during YouTube Music and during a fixture. Do not inspect private `MPVolumeView` subviews to obtain its slider value.
3. Refresh the numeric diagnostic on foreground entry, route change, interruption end, media-services reset and calibration playback start/stop. Polling is only useful to distinguish a missed KVO callback from a stale `outputVolume`; it is not a production solution.
4. If `MPVolumeView` is live and KVO remains stale, make the native slider the lab’s source of truth and label or remove the percentage. If both are stale only while RideHorizon is inactive, decide whether a short, explicit calibration-session acquisition can be made without changing external playback; otherwise do not claim a live number.
5. Verify on the physical iPhone with the actual helmet route, because Apple states that Simulator cannot control volume or route through `MPVolumeView`.

## 2. What Current A and Candidate B actually process

### Current A

The production profile specifies 0 dB additional output gain, compression off, 0 dB presence, no high-pass, a nominal −2 dBFS sample-peak target and at most 2×/+6.02 dB automatic peak gain (`RideHorizon/PremiumSpeechProcessor.swift`, lines 33–48).

The processor decodes the raw ElevenLabs MP3 fixture, measures the peak across the announcement and applies a non-attenuating gain between 1× and 2×. If the source is already above the nominal target, it is not turned down. Current A does not use Candidate B’s final limiter (`RideHorizon/PremiumSpeechProcessor.swift`, lines 101–155).

Therefore Current A is lightly processed, not raw ElevenLabs audio. Its automatic gain is whatever the source peak permits between 0 and +6.02 dB; it should not be described as always “+6 dB”. The closest raw reference would be a separate internal bypass path that decodes and plays the fixture without peak normalisation; none exists in the current A/B controls.

### Candidate B

Once Candidate B is edited, `calibrationCandidate` adds a fixed 100 Hz high-pass, optional presence gain up to the current 18 dB limit, the selected compressor, the same bounded peak-normalisation calculation, selected output gain and a final sample limiter. The presence filter is a broad peaking EQ centred at 2.8 kHz with Q 0.8. The limiter has a 50 ms release and deliberately lowers its internal sample ceiling to 88% of the nominal −2 dBFS ceiling to leave reconstruction headroom (`RideHorizon/PremiumSpeechProcessor.swift`, lines 50–63, 101–155, 177–245 and 304–335).

At the rider’s tested values, Candidate B therefore applies:

- 100 Hz high-pass;
- +6 dB broad presence at 2.8 kHz;
- Strong compression;
- up to +6.02 dB automatic peak normalisation;
- +12 dB requested output gain; and
- final sample limiting.

The observation that it is tinnier is consistent with the 100 Hz high-pass plus broad +6 dB presence boost. The observation that distortion begins around +12 dB is consistent with driving the sample limiter harder. This is an implementation-grounded inference, not a completed distortion measurement.

## 3. Compression: present numbers and useful measurements

### Present compressor

All non-off presets use a 6 dB soft knee, 10 ms attack and 120 ms release. Their threshold and ratio are:

| Preset | Threshold | Ratio |
| --- | ---: | ---: |
| Light | −18 dBFS | 2:1 |
| Medium | −22 dBFS | 3:1 |
| Strong | −24 dBFS | 4:1 |

Above the knee, Strong’s static gain reduction is 75% of the amount by which the detected envelope exceeds −24 dBFS. For example, an envelope at −12 dBFS implies approximately 9 dB gain reduction; −6 dBFS implies approximately 13.5 dB. The actual fixture result may be much lower because the detector has attack/release smoothing and the code currently records no gain-reduction statistics.

After compression, peak normalisation is limited to +6.02 dB and there is no explicit compressor make-up gain. Extra output gain is then constrained by the final limiter. Consequently, Strong can reduce peaks without raising the active speech level enough to compete with music, while subsequent limiting can obscure the compressor’s perceptual distinction.

Apple’s system Dynamics Processor exposes threshold, headroom, attack, release, input amplitude, output amplitude and compression amount parameters. Those are useful reference dimensions even if RideHorizon retains its deterministic offline processor ([Apple: Dynamics Processor unit parameters](https://developer.apple.com/documentation/audiounit/1389787-dynamics_processor_unit_paramete)).

### Measurement contract before widening the range

Record these values for every fixed Premium Voice fixture and every candidate:

- input and output maximum sample peak;
- input and output true peak according to ITU-R BS.1770-5, not a sample peak labelled as dBTP ([ITU-R BS.1770-5](https://www.itu.int/rec/R-REC-BS.1770/en));
- integrated, short-term and momentary loudness using the BS.1770/EBU mode, plus loudness range where the utterance is long enough ([EBU loudness specifications](https://tech.ebu.ch/loudness/));
- active speech level using ITU-T P.56, which is intended to make speech-level measurements comparable ([ITU-T P.56](https://www.itu.int/rec/T-REC-P.56/en));
- crest factor before and after processing;
- compressor maximum, mean-active and 95th-percentile gain reduction;
- percentage of active speech above 1, 3 and 6 dB gain reduction;
- limiter maximum and 95th-percentile gain reduction, plus percentage of samples or frames under limiting; and
- clipping/overs count after final encoding as well as before it.

BS.1770 loudness and peak values characterise level; they do not by themselves establish intelligibility. ANSI/ASA S3.5 defines the Speech Intelligibility Index from acoustical measurements of speech and noise, while ANSI/ASA S3.50 defines a listener transcription/edit-distance method specifically for TTS systems ([ANSI/ASA S3.5-1997 (R2024)](https://webstore.ansi.org/standards/asa/asaansis31997r2024), [ANSI/ASA S3.50-2013 (R2022)](https://webstore.ansi.org/standards/asa/asaansis3502013r2022)). Those provide better models for the later human gate than asking only which sample sounds louder.

### Proposed bounded range

Do not add arbitrary ratios until the current fixtures have the measurements above. Then add two internal-only presets beyond current Strong, selected to produce meaningfully separated gain-reduction distributions rather than merely larger labels. A reasonable starting hypothesis for offline rendering is:

| Probe preset | Threshold | Ratio | Purpose |
| --- | ---: | ---: | --- |
| Strong | −24 dBFS | 4:1 | Existing reference |
| Stronger | −30 dBFS | 6:1 | Clearly more active gain reduction |
| Extreme | −36 dBFS | 10:1 | Deliberate rejection boundary, not a production candidate |

Keep the current 6 dB knee, 10 ms attack and 120 ms release during this first comparison so only threshold/ratio change. Add measured make-up gain or loudness matching as a separate switch: loudness-matched comparisons test compression character, while make-up-gain comparisons test whether compression creates useful headroom. Reject any preset with lost consonant onsets, pumping, clipped reconstruction peaks or no meaningful gain-reduction separation.

The rider’s clarification supports internal additional-output-gain choices of `0, +6, +9, +12 and +15 dB`. These values remain on top of the variable automatic normalisation shared with Current A. Mark +12 dB as the observed distortion onset and +15 dB as a deliberate rejection-boundary probe, not a presumed safe candidate. Add presence choices `+9 dB` and `+15 dB`, giving `0, +6, +9, +12, +15, +18 dB`, but retain the rejection rule because large boosts at 2.8 kHz can become harsh without improving words masked elsewhere.

## 4. Why dense rock music can remain perceptually louder

The finding is acoustically plausible and does not imply that the phone’s music stream has a higher digital peak:

- Peak level and perceived loudness are different. EBU R 128 was created because peak normalisation produced large loudness differences between programmes; it uses programme loudness and true peak as separate descriptors ([EBU R 128](https://tech.ebu.ch/publications/r128)).
- Densely compressed music sustains energy close to its peaks and therefore has lower crest factor and higher average loudness than sparse speech at a similar peak. RideHorizon’s final peak limiter prevents Candidate B’s peaks rising further; driving it harder mainly flattens the speech waveform.
- Masking is frequency-specific. ANSI/ASA S3.5 calculates speech intelligibility from speech and noise measurements across frequency bands, not from one broadband peak. Rock guitars, snare and vocals concentrate sustained energy in bands that overlap speech cues, so a broad 2.8 kHz boost can make speech thinner yet still leave important cues masked.
- A motorcycle helmet is not spectrally neutral. Published helmet measurements found little attenuation below 250 Hz and increasing attenuation above 500 Hz, reaching about 30 dB at 8 kHz; the authors warn that high-frequency attenuation may reduce speech intelligibility. That study did not include wind generated around the helmet, so it represents a best-condition boundary ([Młyński, Kozłowski and Żera, 2009](https://pubmed.ncbi.nlm.nih.gov/19744370/)).
- The actual result also depends on YouTube Music’s pause/restore or ducking level, the Bluetooth route, the helmet speakers, their placement, earplugs and ambient wind. File-level LUFS cannot capture those downstream effects.

For comparison reports, measure both the isolated speech file and a controlled speech-plus-music-plus-noise mix. Record speech active level, music/noise level, band-by-band speech-to-masker ratio, true peak, integrated/short-term loudness and listener word accuracy. The most decision-relevant result is intelligibility at a stated signal-to-noise ratio, not the largest output-gain number.

## 5. Stationary motorcycle-noise simulation

### What it can and cannot prove

A looped in-helmet road recording can make A/B trials repeatable and expose masking that is absent in a quiet room. It cannot faithfully reproduce the acoustic and tactile path of real riding. The UK Department for Transport’s SHARP programme does not rate helmet acoustics because it is not aware of a reliable, repeatable test process that fairly represents riding noise ([SHARP helmet FAQ](https://sharp.dft.gov.uk/frequently-asked-questions/choosing-a-new-helmet/)). The final decision therefore still requires a real ride.

### Recommended test design

1. Test while stationary, seated safely off the motorcycle, with the normal helmet, earplugs, headset, phone and speaker placement.
2. Use a fixed loop for each condition: urban/low speed, open-road cruise and faster wind-dominant cruise. Include engine and wind together; generic engine pass-bys alone are not representative of sound at the rider’s ear.
3. Use one controlled player/mix for the formal intelligibility comparison: fixed speech, licensed music excerpt and road-noise loop rendered at known relative levels. Keep a separate YouTube Music test for cross-app pause/restoration behaviour. This avoids mistaking changes in YouTube mastering, track section or operating-system mixing for Candidate A/B differences.
4. Compare at several safe relative speech-to-masker levels, initially for example +6, 0 and −6 dB based on active speech level. These are experimental brackets, not acceptance thresholds. Randomise A/B order and use short unseen phrases; record words correctly recovered and confidence.
5. Preserve the relative signal-to-noise ratio while keeping absolute headset level comfortable. Never recreate 95–100 dBA road exposure in the headset merely because the recording represents a motorway.
6. Calibrate acoustic level at the ear with a suitable ear/headset coupler or manikin if the result is to be expressed in dBA SPL. The iOS 0–100% system-volume value is dimensionless and cannot establish sound pressure at the ear.
7. Keep trials short, start low and stop for discomfort, ringing, dull hearing or fatigue. WHO/ITU’s adult personal-audio reference is 80 dBA for 40 hours per week, and NIOSH uses an 85 dBA eight-hour occupational limit with allowable duration halving for every 3 dB increase ([WHO-ITU safe listening standard](https://www.who.int/publications-detail-redirect/9789241515276), [NIOSH noise exposure guidance](https://www.cdc.gov/niosh/blogs/2016/noise.html)). These are exposure safeguards, not targets for the test.

IEC 60268-16 defines Speech Transmission Index methods and test signals, but warns that every method has limitations and does not cover fluctuating noise fully ([IEC 60268-16:2020](https://webstore.iec.ch/en/publication/26771)). Motorcycle wind is fluctuating, so a short listener transcription test remains necessary even if an objective index is added.

### Candidate noise sources and licensing

Recommended order:

1. **A RideHorizon-owned recording made inside Rob’s normal helmet.** Rob already has hours of tour recordings made with a helmet camera and in-helmet microphone. These are likely the best available ecologically representative maskers for the same helmet/bike context, and Digital Mercenaries controls their reuse. They are not calibrated measurements of the noise at the ear: microphone frequency response, placement, wind protection, camera pre-amplifier, automatic gain control, compression, codec, clipping and wind overload may all reshape the spectrum and dynamics. Inspect metadata and waveforms, identify stable speed/road sections, reject speech and clipped or gain-pumping passages, and retain privacy-clean excerpts with provenance. Use them at controlled relative speech-to-masker levels; do not infer original dBA SPL or “correct” the spectrum unless the recording chain can be characterised. A future measurement-microphone or ear-coupler recording can provide a better absolute reference. Use a securely mounted recorder and do not interact with it while riding.
2. **A CC0 in-helmet reference for the first bench probe.** Freesound recording `181161` was captured with binaural microphones worn inside a helmet and is published as Creative Commons Zero by its uploader ([Freesound: in-helmet motorcycle recording](https://freesound.org/s/181161/)). Inspect the complete recording before use and retain source/licence metadata.
3. **FSD50K for supplemental engine/revving material.** FSD50K contains more than 51,000 human-labelled clips and includes “Accelerating, revving, vroom”; every clip carries an individual Creative Commons licence and the dataset is distributed through Zenodo ([FSD50K companion site](https://fsannotator.upf.edu/fsd/release/FSD50K/), [FSD50K Zenodo record](https://zenodo.org/records/4060432)). Filter to CC0 or CC BY for any redistributable fixture and preserve per-clip attribution. It is not a substitute for helmet wind.

Do not use Google AudioSet annotations as if they licensed the underlying YouTube audio. Google distributes annotation files and extracted features, while the segments refer to YouTube videos ([Google AudioSet downloads](https://research.google.com/audioset/download.html)). The recently published MOTOR dataset contains on-road audio but is CC BY-NC 4.0 and therefore unsuitable for a commercial app fixture without separate permission ([MOTOR dataset](https://huggingface.co/datasets/varunpaturkar/MOTOR)).

## Proposed backlog items

These are ordered to keep diagnosis ahead of tuning:

1. **RH-004A — Diagnose live system-volume reporting.** Reproduce KVO versus visible `MPVolumeView` on the physical iPhone across idle, YouTube Music, fixture playback and Bluetooth route change. Acceptance: a live, correctly labelled indicator or an explicit documented limitation; no calibration-only session behaviour that disrupts external audio.
2. **RH-004B — Add offline speech-processing metrics.** Capture P.56 active speech level, BS.1770 loudness/true peak, crest factor, compressor and limiter gain-reduction distributions, and post-encode clipping for all fixed fixtures. Acceptance: a repeatable report that explains how much every stage changes each fixture.
3. **RH-004C — Bound the existing controls from evidence.** Use additional-output-gain choices `0, +6, +9, +12 and +15 dB`; add presence `+9` and `+15 dB`; identify +12 dB as the observed distortion onset and +15 dB as a deliberate rejection boundary. Acceptance: the UI distinguishes automatic normalisation from additional gain, no profile is promoted and all options remain internal-only.
4. **RH-004D — Widen the internal compression probe.** Add measured Stronger and Extreme presets only after RH-004B, with optional loudness-matched/make-up comparisons and explicit limiter metrics. Acceptance: presets have meaningfully separated gain-reduction distributions and no clipping; Extreme is a rejection boundary.
5. **RH-004E — Add a controlled stationary masking fixture.** Use a RideHorizon-owned in-helmet recording where possible, otherwise a licence-verified CC0 probe. Provide fixed safe speech/music/noise mixes at stated relative levels and a short blinded word-recovery worksheet. Acceptance: repeatable stationary results with licence metadata and no claim that simulation replaces a ride.
6. **RH-004F — Repeat the human gate.** Compare Current A and bounded candidates first in controlled stationary noise, then on a real ride. Acceptance: select, revise or reject a candidate using intelligibility, distortion, comfort and cross-app restoration evidence; production remains unchanged until that decision.

## Decisions supported now

- Treat +12 dB as the observed additional-gain distortion onset; retain +15 dB only as a deliberate internal rejection-boundary probe.
- Add +9 dB and +15 dB presence choices during the next implementation increment, but do not infer that more presence means more intelligibility.
- Do not call Candidate B raw ElevenLabs audio.
- Measure compressor and limiter action before adding stronger presets.
- Add safe stationary noise simulation to the backlog, using owned in-helmet audio as the preferred source.
- Make no production-profile decision until the controlled stationary test and subsequent road test are complete.
