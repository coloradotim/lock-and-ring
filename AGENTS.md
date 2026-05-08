# AGENTS.md

## Project identity

Lock & Ring is a Mac-native rehearsal and analysis tool for barbershop quartets and vocal ensembles. The first product goal is not to identify and correct every individual singer. The first goal is to analyze the combined sound from a single microphone and give useful real-time feedback on:

- **Lock**: pitch stability and alignment around simple harmonic relationships.
- **Ring**: reinforced upper partial energy that appears when the chord becomes more organized.
- **Roughness**: beating, competing partials, and unstable dissonance.
- **Stability**: whether the sound stays organized over time.

This is a musical tool first and a signal-processing sandbox second. Avoid building an academic toy that cannot help a quartet rehearse.

## Operating principles

1. **Single microphone first**
   - The MVP must work from one live audio input.
   - Do not require one microphone per singer.
   - Do not require singer isolation for the first version.
   - Individual singer diagnosis can be a later feature, not an MVP dependency.

2. **Chord-agnostic before chord-aware**
   - First measure the quality of the combined sound: harmonic organization, roughness, overtone reinforcement, and temporal stability.
   - Chord/root selection may be added later to improve interpretation, but the app should provide useful feedback even when it does not know the chord name.

3. **Real-time, low-friction rehearsal use**
   - The app should open quickly, use the default or selected mic, and show feedback immediately.
   - The UI should be usable by singers in rehearsal, not just by developers.
   - Favor clear meters and visual comparisons over dense technical displays.

4. **Scientific humility**
   - Treat “ring” as an observable proxy, not a magical truth meter.
   - Room acoustics, vowel shape, mic placement, singer volume, vibrato, and background noise affect measurements.
   - Make the app honest about confidence and signal quality.

5. **Toolchain maturity from the start**
   - Keep the project buildable from a clean checkout.
   - Add automated tests early.
   - Prefer small issues and small pull requests.
   - Document important decisions as the architecture evolves.

## Preferred initial technical direction

- Platform: macOS native app.
- Language/UI: Swift + SwiftUI unless a strong reason emerges otherwise.
- Audio input: AVAudioEngine / CoreAudio.
- Signal processing: Accelerate/vDSP FFT for spectral analysis.
- Architecture: keep audio capture, analysis, scoring, and UI separated.
- Tests: unit-test scoring and analysis logic with synthetic signals before relying on live microphone behavior.

## Suggested code organization

This may evolve, but start with clear boundaries:

```text
LockAndRing/
  App/
  Audio/
    AudioInputManager.swift
  Analysis/
    SpectrumAnalyzer.swift
    PitchAndPartialTracker.swift
    RoughnessScorer.swift
    RingScorer.swift
    StabilityScorer.swift
  UI/
    LiveMetersView.swift
    SpectrumView.swift
  Models/
    AnalysisFrame.swift
    MeterSnapshot.swift
LockAndRingTests/
  Analysis/
    SpectrumAnalyzerTests.swift
    RoughnessScorerTests.swift
    RingScorerTests.swift
```

## Definition of done for early work

For MVP foundation issues, done means:

- App builds locally on macOS.
- Tests run from command line.
- Core analysis logic is testable without a microphone.
- README explains how to build, run, and test.
- No large, unexplained blobs of code.
- Any signal-processing assumptions are documented in comments or docs.

## UX posture

The app should make the quartet better at rehearsal. Good first UI language:

- “More locked” / “less locked”
- “More ring” / “less ring”
- “Roughness increased” / “roughness decreased”
- “Stable for 2.4 seconds”
- “Input too noisy”
- “Signal too low”

Avoid overclaiming:

- Do not say “baritone is flat” from a single mic unless the app has strong evidence.
- Do not claim exact singer-level diagnosis in MVP.
- Do not treat ring as purely volume. Ring should be measured as upper-partial organization/reinforcement relative to the lower spectrum and recent baseline.

## Development workflow

- Create GitHub issues for meaningful units of work.
- Implement through branches and pull requests.
- Keep PRs reviewable.
- Before merging, run available tests and document manual test notes.
- If a change affects app behavior, include a short “How I tested this” section in the PR.

## Early risk list

- Single-mic analysis may be useful for ensemble feedback but unreliable for individual diagnosis.
- FFT-only approaches can look impressive while missing musical usefulness.
- Room/mic/vowel effects can dominate ring measurements.
- Latency must stay low enough for rehearsal use.
- Visual feedback must not distract singers into chasing meters instead of singing well.
