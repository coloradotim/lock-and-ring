# ADR-0002: macOS Native Swift App

## Status

Accepted

## Context

The app needs low-latency microphone input, native audio APIs, realtime visual
feedback, and a development loop that can support DSP experiments. Early users
are expected to run it on Macs in rehearsal settings.

Cross-platform frameworks could broaden reach later, but they would add setup
and audio-stack uncertainty before the core analysis is proven.

## Decision

Build the MVP as a macOS-native app using Swift and SwiftUI. Use AVAudioEngine,
CoreAudio, and Accelerate/vDSP for capture and spectral analysis.

## Consequences

The project can lean on mature Apple audio and UI APIs, keep latency work close
to the platform, and ship a Mac app without a web runtime or external audio
bridge.

The initial product is macOS-only. Supporting iOS, Windows, web, or plugin
formats would need separate decisions after the rehearsal workflow and scoring
models prove useful.
