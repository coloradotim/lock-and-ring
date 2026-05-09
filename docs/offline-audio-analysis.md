# Offline Audio Analysis

## Purpose

Offline analysis lets the app run prerecorded clips through the same FFT and scoring path as live microphone input. This
supports repeatable algorithm checks, real quartet recording review, and debugging without needing a live rehearsal.

## Supported Input

The import UI accepts common audio types exposed by macOS:

- WAV
- AIFF
- M4A
- MP3 when the local system decoder supports it

Imported files are decoded with `AVAudioFile`, normalized into floating-point channel samples, and downmixed to mono
with the same `AudioFrameNormalizer` used by live input.

## Playback Model

The first implementation provides analysis playback rather than a full audio-player experience:

- import a file
- play or pause analysis playback
- scrub the timeline
- publish fixed-size frames into the shared downstream analysis callback

During offline playback, live microphone capture is paused so imported frames do not compete with live input updates.
When playback pauses or ends, live capture resumes.

## Architecture

`OfflineAudioAnalyzer` owns file loading and timeline state. `AppViewModel` wires its `onFrame` callback to the same
private analysis method used by `AudioInputManager`.

That keeps FFT, roughness scoring, ring scoring, spectrum updates, and meter updates shared between live and imported
audio.

## Current Limitations

- Analysis playback does not yet play audible sound through the speakers.
- Very long files are loaded into memory at once.
- Imported clips are not saved as sessions.
- Metrics are not exported.
- Take comparison remains a later MVP workflow.
