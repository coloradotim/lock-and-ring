# Lock & Ring

Lock & Ring helps serious vocal harmony ensembles compare rehearsal takes and hear what changed.

Short phrase:

> Better takes. Clearer ears.

Lock & Ring is a macOS-native rehearsal analysis tool for barbershop quartets and vocal ensembles. It helps singers record or import short takes, inspect ensemble-level evidence, compare the current take against a reference, keep the best-so-far region, and export useful audio for practice outside rehearsal.

## Product Direction

Lock & Ring is not a tuner, a fake coach, or a generic spectrum analyzer. It is a take-based rehearsal tool.

The core product loop is:

```text
Record/import take → inspect → compare → adjust region → listen A/B → mark keeper or record again
```

The project starts with single-microphone ensemble analysis, honest confidence labeling, current-take analysis, selected-region analysis, and relative comparison against a reference take. Over time, it can support stronger automatic alignment, richer saved-take organization, deeper validation, and better export workflows for reference-track building.

## Product Principles

- The product is organized around takes, not rehearsal modes.
- The first take in a run should automatically become the initial reference.
- The current take should be analyzed on its own before comparison.
- Comparison should default to the active reference or keeper, not necessarily the immediately previous take.
- Users must be able to compare against the keeper, previous take, any saved take, or an imported file.
- Whole-take analysis and selected-region analysis both matter.
- The app should auto-detect the sung region and help align comparable regions across takes, but users must be able to adjust regions by ear.
- Keeper means best-so-far for the current song/section/region and replaces the previous keeper.
- Notes are optional free text and should never slow down live rehearsal.
- Export should prioritize practical shareable audio, such as MP3-style clips, while retaining whatever internal audio is needed for future comparison.
- The app should not produce a single overall take score.
- The app should not diagnose individual singers from one microphone.

## Vision

The goal is not to create an academic spectrum analyzer.

The goal is to help serious singers answer questions like:

- “What changed in that take?”
- “Did the sound lock sooner?”
- “Did roughness decrease?”
- “Did ring arrive sooner, get stronger, or last longer?”
- “Did the target vowel stabilize more quickly?”
- “Did the release timing change?”
- “Is this the best-so-far region we should keep?”
- “Can we export this clip to sing against later?”

The first versions intentionally avoid trying to identify each singer independently.

Instead, the app analyzes the combined waveform and evaluates ensemble-level harmonic organization, roughness, ring, stability, timing, and confidence.

## MVP Goals

### Initial release target

A macOS app that:

- Records or imports short rehearsal takes, usually phrase-length material around 15-45 seconds.
- Opens on a Ready screen with Record Take and Import Take as the primary actions.
- Shows Take Analysis after a take exists.
- Automatically uses the first take as the initial reference.
- Shows current-take analysis before comparison.
- Lets singers compare the current take to the active reference/keeper, previous take, any saved take, or an imported file.
- Lets singers adjust one active selected region at a time and explicitly update/analyze that region.
- Reports both whole-take and selected-region metrics.
- Supports waveform-based region selection with the current and reference waveforms stacked for alignment.
- Provides playback for current, reference, selected region, and A/B comparison.
- Lets singers mark a best-so-far keeper, replacing the previous keeper for that song/section/region.
- Prompts for optional title/section/note when marking a keeper, without requiring metadata before rehearsal continues.
- Saves takes locally with replayable audio and basic analysis metadata.
- Exports selected keeper-region audio for sharing or assembling outside the app in tools such as Audacity or GarageBand.
- Runs low-latency FFT/spectral analysis.
- Displays take-level and selected-region metrics for:
  - Lock
  - Ring
  - Roughness
  - Stability
  - Time to lock
  - Time to ring
  - Ring duration
- Shows signal confidence and visual evidence.

## Technical Direction

### Platform

- macOS native
- Swift
- SwiftUI

### Audio stack

- AVAudioEngine
- CoreAudio
- Accelerate / vDSP FFT

### Analysis concepts

Potential approaches include:

- Spectral peak analysis
- Harmonic partial tracking
- Psychoacoustic roughness estimation
- Just-intonation proximity scoring
- Harmonic entropy / organization metrics
- Overtone reinforcement estimation
- Temporal stability scoring
- Region detection and alignment
- Take-to-take comparison

## Non-goals for MVP

These may happen later, but should not block early progress:

- Perfect singer separation from one microphone
- Automatic note naming for every singer
- Full music transcription
- Chord recognition for arbitrary music
- AI coaching or singer diagnosis
- Multi-platform support
- Full DAW-style audio editing
- In-app assembly of stitched reference tracks
- Forced song/session database management before recording

## Development philosophy

This repo should behave like a mature software project from the beginning.

That means:

- Tests early
- Small pull requests
- Reproducible builds
- Architecture separation
- Clear issue tracking
- Real documentation

Architecture Decision Records live in [`docs/adr/`](docs/adr/) for important
technical, DSP, product, and rehearsal workflow decisions.

User-facing help lives in [`docs/user-guide/`](docs/user-guide/). Technical and
scoring notes are indexed in [`docs/technical/`](docs/technical/).

## Proposed architecture

```text
LockAndRing/
  App/
  Audio/
  Analysis/
  UI/
  Models/
LockAndRingTests/
```

## Initial milestone sequence

1. Project bootstrap
2. Live audio capture
3. FFT/spectrum visualization
4. Harmonic peak tracking
5. Roughness scoring
6. Ring scoring
7. Stability scoring
8. Take Analysis workflow refinement
9. Region selection and explicit region analysis
10. Reference/keeper comparison
11. Export selected keeper-region audio

## Inspiration

Barbershop harmony values:

- Just tuning
- Resonance
- Reinforced overtones
- Ensemble vowel alignment
- Chord stability
- “Expanded sound” beyond the individual voices

This project attempts to measure some of those qualities without destroying the musical rehearsal experience.

## Status

Early prototype / research phase.

## Repository layout

```text
LockAndRing/
  App/
  Audio/
  Analysis/
  UI/
  Models/
LockAndRingTests/
```

The first scaffold gives the app a real native shell, a live audio-input pipeline, and a placeholder analysis layer.
DSP scoring and rehearsal-specific interpretation remain focused follow-up issues.

## Audio input

The initial audio pipeline uses `AVAudioEngine` to install a low-latency tap on the selected input and publish
normalized frames for downstream analysis. Each frame includes:

- Sample rate
- Frame size
- Channel count
- Mono samples for MVP scoring
- Preserved per-channel samples
- RMS input level
- Left/right RMS levels for stereo microphones
- Clipping and per-channel clipping state
- Channel imbalance state
- Noise-floor estimate
- Signal present/no signal state

Stereo input is intentionally downmixed for the main analysis path with:

```text
mono = (left + right) / 2
```

The original channel samples and channel metadata remain available for later stereo-aware analysis.

## Spectrum and spectrogram

Live audio frames are converted into FFT snapshots with an Accelerate/vDSP pipeline:

- Hann windowing
- Real FFT
- Frequency-bin conversion
- Magnitude normalization
- Optional frame-to-frame smoothing
- Peak extraction

The SwiftUI spectrum view highlights detected peaks and broad harmonic regions. The spectrogram view keeps a reduced,
scrolling history of recent FFT frames so changing chords can be tracked over time without coupling rendering to the
analysis implementation.

## Requirements

- macOS 14 or newer
- Swift 5.10 or newer
- Xcode or Apple Command Line Tools
- SwiftLint for local linting

Install SwiftLint with Homebrew if it is not already available:

```sh
brew install swiftlint
```

## Build

```sh
swift build
```

## Run

```sh
swift run LockAndRing
```

The app launches a SwiftUI window for the current prototype with:

- App title
- Audio input selection
- Record/import take workflows
- Lock, Ring, Roughness, and Stability analysis
- Spectrum/spectrogram evidence

## Test

```sh
swift test
```

## Lint

```sh
scripts/lint.sh
```

When SwiftLint is installed, `scripts/lint.sh` runs `swiftlint lint --strict`.
Without SwiftLint, it still runs fallback checks for whitespace, long Swift
lines, and oversized `AppViewModel` growth so local verification catches common
CI failures earlier.

GitHub Actions runs build, tests, and SwiftLint on pull requests.

## Durable Rule

> Audio capture creates takes. Analysis explains evidence. Regions focus attention. Comparison explains change. Confidence limits claims. Singers make the musical decision.
