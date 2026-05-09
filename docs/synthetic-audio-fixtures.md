# Synthetic Audio Fixtures

## Why They Exist

Lock & Ring needs repeatable DSP tests that do not require live singers, a microphone, or a particular room. Synthetic
fixtures let tests exercise the FFT, roughness scorer, ring scorer, and future stability logic with known inputs.

Fixtures are generated during tests. No generated audio files are committed.

## Generator

`LockAndRingTests/Fixtures/SyntheticAudioGenerator.swift` creates deterministic sample buffers. It supports:

- sample rate and duration
- one or more simultaneous fundamentals
- harmonic partial stacks
- per-partial amplitude
- detuning in cents
- vibrato depth and rate
- seeded noise
- reusable musical examples

Noise is deterministic by default. If a test needs randomness, pass an explicit seed so the generated buffer remains
repeatable.

## Current Fixture Catalog

- `singleSine`: validates simple FFT peak detection.
- `octave`: smooth interval reference for roughness tests.
- `perfectFifth`: consonant interval reference.
- `justMajorThird`: simple-ratio major third reference.
- `equalTemperedMajorThird`: tempered comparison against just tuning.
- `mistunedMajorThird`: detuned interval fixture for future scoring calibration.
- `closeSemitoneCluster`: roughness and beating stress case.
- `dominantSeventhApproximation`: chord-like barbershop-style stack.
- `reinforcedHarmonicStack`: strong upper partial reinforcement for ring scoring.
- `chaoticUpperPartials`: upper energy that should not be treated as ring.
- `noisyRoomLikeInput`: deterministic noise plus tonal content.

## How To Add A Fixture

Add a method to `SyntheticAudioGenerator` that composes one or more `SyntheticFundamental` values. Prefer building from
small, named musical cases rather than embedding raw sample arrays in tests.

When adding a fixture:

- Keep it deterministic.
- Name the musical or signal behavior it represents.
- Add at least one test that explains why the fixture exists.
- Avoid tuning expectations tighter than the FFT resolution supports.

## Limitations

Synthetic fixtures are clean and controlled. Real quartet recordings include room modes, microphone coloration, vowel
changes, onset scoops, breath noise, vibrato variation, and singers moving around the room. Synthetic tests protect the
math from regressions, but they cannot replace real rehearsal recordings for calibration.
