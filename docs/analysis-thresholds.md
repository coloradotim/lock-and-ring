# Analysis Thresholds And Tuning Notes

Lock & Ring uses provisional thresholds in `AnalysisConfiguration.default`.
They are named so tuning can happen deliberately as real singer recordings are
collected. They are not final musical truth.

## Confidence

- Reliable analysis threshold: controls when the UI can make plain-language
  claims. Higher values make the app more conservative.
- Aggregate low-confidence frame threshold: controls whether many weak frames
  make a take-level confidence warning. Higher values make warnings more likely.
- Clipping frame ratio: controls when repeated clipping becomes the dominant
  confidence reason. Lower values make clipping warnings more sensitive.
- Problem frame ratio: controls when noisy, unstable, imbalanced, or otherwise
  problematic frames affect the aggregate signal state.

## Chord Timing

- Sound onset confidence: first point where the app considers sound present.
  Higher values ignore softer starts.
- Analyzable confidence: first point where the vowel can be analyzed. Higher
  values make vowel-start detection more conservative.
- Minimum metric confidence: per-metric confidence required before lock, ring,
  stability, or best-moment logic trusts a frame.
- Minimum sustained duration: how long a condition must persist before the app
  says it was achieved.
- Stability score: threshold for a stable region.
- Minimum stability for lock: stability gate required before lock can be claimed.
- Lock score: harmonic-alignment threshold for lock claims.
- Ring score: upper-harmonic threshold for ring claims.
- Maximum roughness for lock/ring: roughness gates that prevent strong claims
  when beating or instability is too high.

## Trends And Comparison

- Trend minimum confidence: recent and previous windows must both meet this
  before live trend copy can claim a change.
- Trend meaningful delta: ignores tiny score changes so the UI does not chatter.
- Stable frame score: take-summary threshold for counting stable duration.
- Reliable take confidence: comparison warning threshold. If either take falls
  below it, comparison copy avoids strong claims.
- Comparison meaningful delta: minimum A/B change before a metric is counted as
  improved or regressed.

## Tuning Rule

Future tuning should compare threshold behavior against real quartet and chorus
recordings, coach annotations, and blind listening judgments. Raise thresholds
when claims feel too eager. Lower thresholds only when the app misses clear,
repeatable lock or ring moments in clean recordings.
