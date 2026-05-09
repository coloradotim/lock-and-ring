# ADR-0001: Single-Microphone-First Analysis

## Status

Accepted

## Context

Lock & Ring is meant for real quartet and ensemble rehearsals. Requiring one
microphone per singer would raise setup cost, add calibration work, and make the
first product feel like a lab tool instead of a rehearsal companion.

A single microphone cannot reliably isolate individual singers. Room acoustics,
vowel shape, relative singer volume, and microphone placement all affect the
combined signal.

## Decision

The MVP analyzes the combined ensemble sound from one live microphone. It scores
ensemble-level qualities such as lock, ring, roughness, and stability before
attempting singer-level diagnosis.

Individual singer attribution, multi-microphone capture, and singer separation
remain future possibilities, not prerequisites for useful feedback.

## Consequences

This keeps the app low-friction and usable in normal rehearsal rooms. It also
keeps early DSP work focused on harmonic organization in the combined waveform.

The app must avoid overclaiming. It should not say which singer is wrong from a
single-mic signal unless later evidence makes that reliable. Confidence and
signal-quality warnings are required to keep feedback honest.
