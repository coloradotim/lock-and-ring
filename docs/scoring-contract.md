# Scoring Contract

## Purpose

All analysis metrics should expose scores consistently so Lock & Ring does not become a set of disconnected DSP
experiments. The UI, take comparison, exports, and future benchmarks should be able to read every metric through the
same shape.

## Core Models

### `AnalysisFrame`

`AnalysisFrame` is the app-level analysis update. It contains:

- `timestamp`
- `meters`
- `spectrum`
- `spectrogram`
- metric-specific history needed by current UI experiments

Frames are emitted from live microphone input and offline imported audio through the same downstream analysis path.

### `MetricSnapshot`

`MetricSnapshot` is the shared metric output contract. Each scorer should be able to produce one.

Fields:

- `kind`: lock, ring, roughness, or stability
- `score`: normalized `0...1` score
- `confidence`: normalized trust estimate plus a short reason
- `contributingFactors`: named normalized factors the UI can use for explanation
- `rawMeasurements`: algorithm-specific numeric values for debugging and benchmarking
- `signalQuality`: signal state at the time of scoring
- `rollingAverage`: optional smoothed score for future trend and take comparison work

### `MetricConfidence`

Confidence answers "how much should the user trust this metric right now?" It is not the same as score. A high ring
score with low confidence should be presented carefully or suppressed.

Confidence range:

- `0`: unusable or not enough evidence
- `0.25`: weak evidence
- `0.50`: plausible but noisy
- `0.75`: usable for rehearsal feedback
- `1.0`: strong evidence under clean input

### `SignalQualityState`

Signal quality captures input problems that should degrade or qualify every metric:

- `nominal`
- `lowSignal`
- `clipping`
- `noisy`
- `unstable`
- `imbalanced`
- `unavailable`

## Score Semantics

Scores are normalized to `0...1`, but the meaning is metric-specific:

- Lock: higher means more harmonically aligned.
- Ring: higher means more ring-forward by the current overtone reinforcement proxy.
- Roughness: higher means rougher or more dissonant.
- Stability: higher means more stable over time.

Do not assume all high scores are good. Roughness is intentionally inverted relative to Lock, Ring, and Stability.

## Normalization Expectations

Scorers should:

- clamp public scores to `0...1`
- document raw measurement units in code or docs
- avoid returning NaN or infinity
- preserve raw values separately from normalized scores
- use monotonic normalization when possible so direction remains meaningful

Normalization constants are allowed to be provisional while the project is in research mode, but they should be visible
in the scorer implementation and covered by synthetic tests.

## Update Cadence

Live and offline analysis should emit metric snapshots once per analyzed audio frame. Current frame sizes are small
enough for live UI updates, but UI views may smooth or downsample display history.

Scorers should not block the audio callback. Heavy work should happen after audio frames are normalized and handed to
the analysis layer.

## Smoothing And Rolling Averages

Each `MetricSnapshot` may include a `rollingAverage`, but this is optional until take comparison is implemented.

Guidelines:

- raw score: current analysis frame
- rolling average: short trend suitable for display
- take summary: aggregate over a captured take

Smoothing should never hide clipping, low signal, or confidence problems.

## Low-Confidence Handling

When confidence is low:

- keep publishing a score so debugging remains possible
- surface confidence or signal quality in the UI
- avoid strong coaching language
- prefer "input too low" or "analysis uncertain" over "the chord got worse"

Confidence should drop when:

- signal is too quiet
- clipping is detected
- channel imbalance is severe
- signal-to-noise ratio is weak
- spectral peaks are unstable between frames
- non-musical transients dominate the frame
- too few partials are available
- harmonic anchors are unreliable
- noise dominates peak extraction

## Signal Quality Gate

`SignalQualityAnalyzer` produces a continuous quality multiplier from input level, clipping, signal-to-noise ratio,
spectral stability, and transient cleanliness. The app applies this multiplier to every metric snapshot's confidence
while leaving the metric score intact.

This keeps score and trust separate: noisy input can show a high roughness or ring value with low confidence instead of
turning uncertainty into fake precision. The UI should visually mute low-confidence metrics and show the primary signal
quality state near the live meters.

## Current Implementations

Roughness:

- score is pairwise partial interaction roughness
- confidence is based on usable partial count
- raw measurements include pair interaction and partial count

Ring:

- score is harmonic reinforcement around a provisional anchor
- confidence is based on harmonic energy ratio and matched harmonic count
- raw measurements include harmonic energy ratio and matched harmonics

Lock and Stability:

- currently represented by placeholder snapshots
- should implement this contract before becoming visible coaching signals

## Future Support

This contract is intended to support:

- metric history
- Take A vs Take B comparison
- exported analysis sessions
- algorithm benchmarking
- multiple scorer implementations behind one UI contract
- explanation panels showing why a metric moved
