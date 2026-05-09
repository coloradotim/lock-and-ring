# Signal Quality Confidence

Issue #11 adds a shared signal-quality gate before metric snapshots reach the UI.
The gate does not rewrite metric scores. It reduces confidence and annotates the
metric contract so the app can show when analysis should not be trusted.

## Assessment Inputs

`SignalQualityAnalyzer` estimates:

- input level adequacy from frame RMS
- clipping from input instrumentation
- signal-to-noise ratio from RMS versus estimated noise floor
- spectral stability by comparing current and previous spectral peaks
- transient cleanliness from crest factor

These dimensions produce a continuous `confidenceMultiplier` and one primary
`SignalQualityState`.

## Metric Integration

Every `MetricSnapshot` keeps its score and receives:

- gated confidence: metric confidence times signal-quality confidence
- signal-quality state
- signal-quality factors and raw measurements

This keeps “how good did it sound?” separate from “how much should we trust the
measurement?” A high roughness score can still appear with low confidence, and a
moderate ring score can remain high confidence when the signal is clean.

## UI Behavior

The live meters show the primary signal-quality state, average confidence, and a
per-metric confidence value. Low-confidence metrics are visually muted so poor
input conditions do not look like authoritative feedback.

User-facing Take Analysis copy should use the shared confidence display state:

- reliable: present direct musical interpretation
- low confidence: explain the uncertainty before showing any observed scores
- unavailable: ask the user to record or import a take first

Low-confidence wording should avoid hard claims such as "this take did not
lock" or "no ring" unless the analysis is reliable enough to support them.
Primary summaries should consolidate repeated metric warnings into one concise
message. Debug and inspector views may still show raw scores.
