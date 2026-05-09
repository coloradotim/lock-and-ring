# Ring Scoring Research Note

## Goal

The first ring score is a proxy for overtone reinforcement in a combined single-microphone ensemble recording. It should
help answer whether a tuning or vowel adjustment made upper partials more organized, not claim to measure "ring" as a
literal physical object.

## Possible Proxies

### Harmonic Reinforcement

If an ensemble locks into simple relationships, upper partials can become more prominent near integer multiples of a
lower anchor partial. A useful proxy is the amount of spectral energy aligned with those expected harmonic regions.

Strengths:

- Chord-name agnostic.
- Cheap to compute from existing FFT peaks.
- Better than a plain treble meter because detuned upper energy is not rewarded.

Weaknesses:

- The anchor partial may be wrong in noisy rooms or with weak fundamentals.
- Strong vibrato can smear peaks outside the tolerance window.
- Some vowels naturally emphasize or suppress specific formants.

### Harmonic-to-Noise Ratio

Another option is to compare harmonic peak energy with surrounding non-harmonic energy. This can help distinguish
organized overtone reinforcement from broadband brightness.

Strengths:

- Good match for the "organized sound" intuition.
- Can produce a confidence estimate.

Weaknesses:

- Needs careful local noise-floor estimation.
- Sensitive to microphone distance, room reflections, and audience/rehearsal noise.

### Temporal Growth

Ring often feels like it blooms after a chord settles. Tracking the recent trend of harmonic reinforcement may be more
useful than any single-frame score.

Strengths:

- Useful for rehearsal feedback.
- Helps compare before/after tuning adjustments.

Weaknesses:

- Requires smoothing and guardrails so normal vibrato is not shown as instability.
- Latency must stay low enough that singers connect the display with what they just changed.

## Prototype Choice

The current prototype uses the strongest low partial as a provisional anchor, then searches for upper harmonic peaks
near integer multiples of that anchor. The score combines:

- harmonic coverage
- upper-harmonic strength
- alignment within harmonic bands
- a confidence estimate based on harmonic energy ratio and matched harmonic count

This intentionally avoids "more treble = more ring" logic. Upper energy only helps when it is organized around the
provisional harmonic structure.

## UI Experiment

The app now shows a small ring experiment panel:

- recent ring trend
- current ring vs roughness position
- confidence and matched harmonic count

The goal is not a final rehearsal UI. It is a simple way to evaluate whether ring rises while roughness falls during
sustained chords and tuning adjustments.

## Failure Modes

- A room mode can exaggerate one harmonic and look like reinforcement.
- Close microphone placement can over-represent one singer or one vowel.
- Distant microphone placement can blur partials through reflections.
- Vowel changes can move formant energy independently of tuning lock.
- Vibrato and scoops can reduce confidence even when the musical result is good.
- Loud background noise can create false peaks.

## Next Steps

- Calibrate score ranges with real quartet recordings.
- Add local harmonic-to-noise estimates around each matched harmonic.
- Track the anchor and upper partials over time instead of scoring isolated FFT frames.
- Gate the display with signal confidence and clipping/imbalance warnings.
