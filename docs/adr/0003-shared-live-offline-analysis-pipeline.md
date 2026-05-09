# ADR-0003: Shared Live and Offline Analysis Pipeline

## Status

Accepted

## Context

The app supports both live microphone feedback and offline imported audio.
Maintaining separate scoring paths for those sources would make results hard to
compare and would increase the chance of drift between rehearsal and review
modes.

Take comparison also depends on stored analysis snapshots being comparable
regardless of whether they came from the microphone or imported audio playback.

## Decision

Normalize audio into `AudioInputFrame` values and send live and offline frames
through the same downstream analysis path. Emit the same `AnalysisFrame` and
`MetricSnapshot` contracts for both sources.

During offline playback, pause live microphone capture so the two sources do not
compete for the current analysis display.

## Consequences

The UI, take comparison, scoring tests, and future exports can treat analysis
frames consistently. Fixes to scoring or confidence behavior apply to live and
offline use together.

Source-specific behavior should stay near capture or playback boundaries. The
shared analyzer path should remain source-agnostic unless a later ADR documents
a reason to split it.
