# ADR-0004: Confidence-Aware Scoring

## Status

Accepted

## Context

Single-microphone ensemble analysis can produce authoritative-looking nonsense
when the signal is too quiet, clipped, noisy, unstable, or dominated by room and
microphone artifacts.

Scores and confidence answer different questions. A roughness score might be
high while confidence is low, and a moderate ring score might be trustworthy
when the input is clean.

## Decision

Every metric uses the shared `MetricSnapshot` contract with separate normalized
`score` and `confidence` values. Signal quality gates confidence across metrics
without rewriting the underlying score.

The UI should surface degraded confidence and signal quality instead of hiding
uncertainty behind precise-looking meters.

## Consequences

The app can keep publishing scores for debugging and comparison while making it
clear when rehearsal feedback should be treated cautiously.

Scorers must continue to expose raw measurements and contributing factors so
confidence can improve over time without changing the meaning of the score.
