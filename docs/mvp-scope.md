# MVP Scope

## Product Thesis

Lock & Ring helps a quartet or vocal ensemble answer one rehearsal question:

```text
Did the ensemble sound become more locked, less rough, more stable, and more ring-forward after an adjustment?
```

The MVP is not an automatic vocal coach and not a generic spectrum-analysis lab. It is a single-microphone rehearsal
comparison tool for sustained ensemble sounds.

## Target User

The first target user is a barbershop quartet, small vocal ensemble, coach, or musically curious singer using a Mac in a
rehearsal room.

They need:

- quick setup with the built-in or an external microphone
- feedback that is readable from a few feet away
- a way to compare two short attempts
- language that supports musical decisions instead of technical rabbit holes

They do not need a studio workflow, accounts, collaboration features, or singer-by-singer diagnosis in the MVP.

## First Rehearsal Workflow

1. Open Lock & Ring.
2. Select or confirm the microphone.
3. Check that the input level is healthy and not clipping.
4. Sing a sustained chord or short target passage.
5. Watch live Lock, Ring, Roughness, and Stability feedback.
6. Record a short Take A.
7. Make one musical adjustment, such as vowel alignment, interval tuning, balance, or breath timing.
8. Record a short Take B.
9. Compare Take A and Take B.
10. Decide whether the adjustment helped.

The first comparison should emphasize direction, not judgment. Useful answers sound like:

- Roughness decreased.
- Ring increased.
- Stability improved.
- The second take looked less confident because the signal clipped.

## Core Screens

### Live Monitor

Purpose: confirm that the app is listening and give immediate ensemble feedback.

Must show:

- selected input device
- input level and clipping state
- mono/stereo status
- Lock, Ring, Roughness, and Stability meters
- spectrum or spectrogram context
- signal confidence or quality warning when available

### Take Recorder

Purpose: capture short rehearsal attempts for comparison.

Must support:

- recording a short Take A
- recording a short Take B
- labeling the takes with timestamp and duration
- showing whether the take had signal, clipping, or low-confidence analysis

### Take Comparison

Purpose: answer whether the musical adjustment helped.

Must show:

- before/after summary for Lock, Ring, Roughness, and Stability
- simple directional language
- enough detail to see whether confidence or clipping affected the result
- an option to clear and try again

## Basic Terminology

Lock:
Pitch and harmonic alignment around simple relationships. The MVP should present this as "more locked" or "less locked,"
not as exact singer-level correction.

Ring:
An observable proxy for reinforced upper partials and spectral organization. The MVP should say "more ring-forward" or
"less ring-forward," not claim to measure ring as a mystical truth.

Roughness:
Beating, competing partials, and dissonance-like spectral interaction. The MVP should report whether roughness increased
or decreased.

Stability:
How consistently the sound stays organized over time. The MVP should distinguish a stable sustained chord from a
drifting or noisy one.

Confidence:
How much the app trusts the signal and analysis. Low input, clipping, high noise, or unstable peak detection should
lower confidence.

## MVP Feature Boundaries

In scope:

- macOS-native app
- single microphone input
- built-in and external microphone selection
- live level and signal-quality monitoring
- live Lock, Ring, Roughness, and Stability meters
- short take recording
- Take A vs Take B comparison
- synthetic fixture tests for DSP behavior
- clear documentation of scoring limitations

Out of scope:

- singer-specific correction
- full song transcription
- automatic chord recognition as a dependency
- multi-mic workflows
- cloud accounts
- social or sharing features
- mobile or web versions
- AI coaching claims
- polished studio production tools

## Success Criteria

The MVP is successful when a quartet can use it during rehearsal to make one focused adjustment and understand whether
the combined sound moved in a better direction.

Concrete success criteria:

- A fresh checkout builds and tests in CI.
- The app opens quickly and starts listening with minimal setup.
- Live meters update without distracting latency.
- Short takes can be recorded and compared.
- The comparison shows directionally useful changes.
- Warnings make bad input obvious.
- The app avoids overclaiming what a single microphone can know.

## Future Ideas, Not MVP Scope

Capture these ideas for later without pulling them into the first usable workflow:

- chord-aware interpretation
- root selection or pitch reference
- singer-specific diagnosis
- multi-microphone capture
- rehearsal clip library
- trend history across sessions
- coach annotations
- exportable reports
- real recording calibration sets
- advanced harmonic entropy or temporal partial tracking

The MVP should stay small enough to test with real singers early. Every feature should serve the Take A vs Take B
rehearsal comparison until that workflow feels useful.
