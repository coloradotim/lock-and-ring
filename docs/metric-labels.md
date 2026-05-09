# Metric Labels

## Purpose

Metric labels translate normalized scores into rehearsal language. They are interpretations of the current scoring
model, not ground truth. A label should help singers decide what to try next without implying singer-level diagnosis
from one microphone.

The app should use labels consistently across live rehearsal, take comparison, file analysis, and future exports.
Low-confidence signal states override score labels so the UI does not show authoritative language when the input is
too quiet, clipped, noisy, unstable, or poorly placed.

## Label Bands

All bands use normalized scores from `0...1`. The lower bound is inclusive and the upper bound is exclusive, except
the final band which includes `1.0`.

### Lock

Lock estimates harmonic organization and simple-ratio alignment.

| Score | Label | Intended meaning |
| --- | --- | --- |
| 0.00-0.19 | Not aligned | Peaks are not organizing into simple harmonic relationships. |
| 0.20-0.49 | Searching | Some organization is present, but the chord is not consistently lined up. |
| 0.50-0.74 | Mostly aligned | The ensemble sound is approaching a stable harmonic relationship. |
| 0.75-1.00 | Locked | The scorer sees strong simple-ratio organization with enough confidence to call the sound locked. |

### Ring

Ring estimates organized upper harmonic reinforcement. It should not mean "louder" or "brighter" by itself.

| Score | Label | Intended meaning |
| --- | --- | --- |
| 0.00-0.19 | No ring | Upper harmonic organization is weak or absent. |
| 0.20-0.49 | Developing | Upper harmonic organization is beginning to show. |
| 0.50-0.74 | Present | Reinforced upper partials are meaningfully present. |
| 0.75-1.00 | Strong | Upper harmonic reinforcement is strong under the current proxy. |

### Roughness

Roughness is inverted relative to the other headline metrics: lower is musically smoother, higher is rougher.

| Score | Label | Intended meaning |
| --- | --- | --- |
| 0.00-0.19 | Smooth | Limited competing partial interaction is detected. |
| 0.20-0.49 | Some interference | Beating or partial interaction is noticeable but not severe. |
| 0.50-0.74 | Rough | Competing peaks suggest substantial interference. |
| 0.75-1.00 | Highly unstable | The scorer sees strong roughness or unstable spectral interaction. |

### Stability

Stability estimates whether the spectral pattern holds over time. It is not just volume steadiness.

| Score | Label | Intended meaning |
| --- | --- | --- |
| 0.00-0.19 | Unstable | The spectral pattern is changing too much to trust as stable. |
| 0.20-0.49 | Drifting | Peaks or energy distribution are moving noticeably. |
| 0.50-0.74 | Holding | The sound is holding together, but not strongly enough to call stable. |
| 0.75-1.00 | Stable | Peaks and spectral energy are persisting across frames. |

## Confidence Overrides

When confidence is low, the app should show a signal or confidence label instead of a musical label:

| Condition | Label |
| --- | --- |
| No analysis frame yet | No analysis yet |
| Metric confidence below 0.35 | Low confidence |
| Low input level | Signal too quiet |
| Clipping | Input clipping |
| Noisy input | Noisy input |
| Unstable signal | Unstable signal |
| Microphone or channel imbalance | Check mic placement |

Scores remain available for debugging, but singer-facing feedback should defer to the confidence override. When
confidence is low, summary copy should explain the uncertainty instead of making a hard musical claim.

## Validation Plan

### Phase 1: Synthetic sanity checks

Synthetic fixtures should verify that labels move in the expected direction:

- harmonic stacks label as more locked than close clusters
- close clusters label as rougher than harmonic stacks
- reinforced upper partial fixtures label as ringier than chaotic upper partial fixtures
- quiet input suppresses authoritative labels through confidence overrides

These tests should assert relative behavior rather than exact numeric scores.

### Phase 2: Real quartet lock test

Procedure:

1. Sing intentionally out of tune.
2. Gradually tune into the chord.
3. Mark the moment singers perceive lock.

Check whether the Lock label moves upward near that moment, Roughness drops, and Ring increases. If singer perception
and labels disagree repeatedly under good signal quality, revisit scoring before changing words.

### Phase 3: A/B listening comparison

Record two takes of the same passage:

- Take A: intentionally worse
- Take B: intentionally improved

Run a blind listening comparison with singers or coaches, then compare the human ranking to app labels and metric
direction. The labels should support the perceived trend, not replace human listening.

## Caveats

- Labels are trend-oriented rehearsal language.
- The app cannot identify a specific singer from one microphone.
- Room acoustics, vowel shape, volume balance, mic placement, and background noise can change labels.
- If labels conflict with repeated listening perception under good signal quality, treat that as a scoring calibration
  problem first.
