# Architecture Decision Records

This directory stores lightweight Architecture Decision Records (ADRs) for
technical, DSP, product, and rehearsal workflow choices that should survive
beyond the issue or pull request where they were made.

## Process

- Copy `0000-template.md` when a decision is important enough to remember.
- Use the next four-digit number.
- Keep the record short enough to read during normal development.
- Prefer `Proposed`, `Accepted`, or `Superseded by ADR-XXXX` as status values.
- Document the tradeoff, not every detail of the implementation.

## Records

- [ADR-0001: Single-Microphone-First Analysis](0001-single-microphone-first.md)
- [ADR-0002: macOS Native Swift App](0002-macos-native-swift-app.md)
- [ADR-0003: Shared Live and Offline Analysis Pipeline](0003-shared-live-offline-analysis-pipeline.md)
- [ADR-0004: Confidence-Aware Scoring](0004-confidence-aware-scoring.md)
- [ADR-0005: Take, Reference, Keeper, and Region Workflow](0005-take-reference-keeper-workflow.md)
