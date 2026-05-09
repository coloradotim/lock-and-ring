# Lock & Ring

Lock & Ring is a macOS-native rehearsal analysis tool for barbershop quartets and vocal ensembles.

The app listens to a live ensemble through a single microphone and attempts to measure:

- Harmonic lock
- Dissonance / roughness
- Overtone reinforcement (“ring”)
- Chord stability over time

## Vision

The goal is not to create an academic spectrum analyzer.

The goal is to help singers answer questions like:

- “Did that chord lock better?”
- “Did the ring increase after we tuned that interval?”
- “Are we stable or drifting?”
- “Did that vowel alignment reduce roughness?”

The first versions intentionally avoid trying to perfectly identify each singer independently.

Instead, the app analyzes the combined waveform and evaluates the overall harmonic organization of the sound.

## MVP goals

### Initial release target

A macOS app that:

- Captures live microphone audio.
- Runs low-latency FFT/spectral analysis.
- Displays live meters for:
  - Lock
  - Ring
  - Roughness
  - Stability
- Displays a live spectrogram or harmonic spectrum.
- Supports recording short rehearsal clips.
- Compares recent audio windows against prior windows.

## Technical direction

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

## Non-goals for MVP

These may happen later, but should not block early progress:

- Perfect singer separation from one microphone
- Automatic note naming for every singer
- Full music transcription
- Chord recognition for arbitrary music
- AI coaching or singer diagnosis
- Multi-platform support

## Development philosophy

This repo should behave like a mature software project from the beginning.

That means:

- Tests early
- Small pull requests
- Reproducible builds
- Architecture separation
- Clear issue tracking
- Real documentation

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
8. Rehearsal-oriented UI refinement

## Inspiration

Barbershop harmony values:

- Just tuning
- Resonance
- Reinforced overtones
- Ensemble vowel alignment
- Chord stability
- “Expanded sound” beyond the individual voices

This project attempts to measure some of those qualities in real time without destroying the musical experience.

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

The app launches a minimal SwiftUI window with:

- App title
- Audio input selector placeholder
- Empty Lock, Ring, Roughness, and Stability meters
- Placeholder spectrum view

## Test

```sh
swift test
```

## Lint

```sh
swiftlint lint --strict
```

GitHub Actions runs build, tests, and SwiftLint on pull requests.
