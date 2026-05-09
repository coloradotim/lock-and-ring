# Roughness Scoring Research Note

## Goal

The first roughness score should help singers notice when an ensemble sound becomes more or less tense. It should not
pretend to identify individual singers or name a chord from one microphone.

## Candidate Methods

### Sethares / Plomp-Levelt Pairwise Roughness

This approach estimates roughness from interactions between nearby spectral partials. Pairs that sit close enough to
compete inside a critical band contribute more roughness, while octave and fifth relationships usually contribute less.

Tradeoffs:

- Useful without knowing the chord name.
- Cheap enough for real-time use because the scorer can limit itself to the strongest FFT peaks.
- Sensitive to FFT peak quality, room noise, vowel shape, vibrato, and microphone placement.
- Needs calibration against actual rehearsal recordings before the displayed value should be treated as a coaching cue.

### Harmonic Entropy

Harmonic entropy estimates how clearly a spectrum supports simple harmonic ratios. It is promising for "organized vs.
unorganized" sound, but it tends to need more assumptions about tuning systems, ratio windows, and peak confidence.

Tradeoffs:

- Potentially good for lock/ring interpretation later.
- More expensive and more parameter-heavy than pairwise roughness.
- Less direct as an initial "roughness increased/decreased" meter.

### Partial Beating / Temporal Stability

This approach tracks changes in partial frequencies and amplitudes over time. Beating or unstable partials can indicate
tension even when a single FFT frame looks acceptable.

Tradeoffs:

- Musically useful for sustained barbershop chords.
- Requires stable peak tracking across frames.
- Better suited as a follow-up layer once pitch/partial tracking is more mature.

## Prototype Choice

The current prototype uses a Sethares-style pairwise roughness curve over the strongest FFT peaks:

```text
roughness_pair = amplitude_a * amplitude_b * (e^(-3.5sd) - e^(-5.75sd))
s = 0.24 / (0.021 * min_frequency + 19)
d = abs(frequency_b - frequency_a)
```

The raw pair interactions are compressed into a 0...1 meter with an exponential saturation curve. The scorer currently
uses only partial frequency and normalized magnitude, which keeps it easy to test and cheap enough for live updates.

## Expected Rehearsal Usefulness

The score should rise for close semitone clusters and beating intervals, and fall for cleaner octave/fifth
relationships. That makes it useful as a relative meter: "did that tuning adjustment reduce roughness?"

It should not yet be read as an absolute quality grade. A loud room reflection, breath noise, vowel mismatch, or strong
vibrato may move the score even when the quartet is singing well.

## Computational Cost

The scorer considers a capped set of strong peaks and compares all pairs. With 10 partials, that is only 45 pair
interactions per audio frame, which is trivial compared with the FFT itself.

## Limitations

- FFT peaks are not the same as stable sung partials.
- The score is chord-agnostic, so it cannot distinguish deliberate dissonance from tuning trouble.
- Normalization constants are provisional.
- Live microphone behavior needs rehearsal-room validation.
- Future versions should combine this with temporal partial tracking and signal-confidence gates.
