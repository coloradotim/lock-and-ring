# Offline Audio Analysis

## Purpose

Offline analysis lets the app treat prerecorded audio as an imported take and run it through the same FFT and scoring
path as microphone-recorded takes. This supports repeatable algorithm checks, real quartet recording review, and
debugging without needing a live rehearsal.

## Supported Input

The import UI accepts common audio types exposed by macOS:

- WAV
- AIFF
- M4A
- MP3 when the local system decoder supports it

Imported files are decoded with `AVAudioFile`, normalized into floating-point channel samples, and downmixed to mono
with the same `AudioFrameNormalizer` used by live input.

Import diagnostics are attached to each imported take and shown in Take Analysis for debugging. The diagnostics include
source type, file type, channel count, source/analysis sample rate, mono conversion behavior, normalization behavior,
peak level, clipping ratio, and stereo correlation when at least two channels are present.

The current import path does not apply gain normalization or resampling after `AVAudioFile` decoding. Stereo files are
converted to mono with a simple channel average before frames enter the shared analysis path. This is intentional and
visible because wide or phase-altered stereo masters can reduce mono energy or harmonic clarity; that should be diagnosed
as an import-path property, not silently reported as poor singing.

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
- Imported clips are not yet saved as persisted takes or sessions.
- Metrics are not exported.
- Imported-take comparison is still being folded into the unified Take Analysis workflow.
