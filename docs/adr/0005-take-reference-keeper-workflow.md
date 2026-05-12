# ADR-0005: Take, Reference, Keeper, and Region Workflow

## Status

Accepted

## Context

Lock & Ring is for serious quartets and vocal harmony ensembles. Most takes may already be reasonably in tune and reasonably locked. The product value is not a generic score or a fake coach; it is helping singers understand what changed between takes and whether those changes affected the musical evidence they care about.

Earlier workflow language treated saved takes and comparison references too loosely. The revised product direction needs durable vocabulary so future implementation work does not drift back toward disconnected modes, generic meters, or one-off comparison screens.

## Decision

Lock & Ring is organized around takes, not rehearsal modes.

The core live rehearsal loop is:

```text
Record/import take → inspect current take → compare to reference → adjust region → listen A/B → mark keeper or record again
```

The app uses three separate concepts:

- **Current take**: the take being inspected right now.
- **Reference take**: the take, saved take, previous take, keeper, or imported file used as the comparison target.
- **Keeper**: the best-so-far take/region for the current song, section, or musical target.

The first take in a run becomes the initial reference automatically. Later takes compare against the active reference/keeper by default, not necessarily the immediately previous take.

Users must be able to compare against:

- active keeper/reference
- previous take
- any saved take
- imported file

Marking a new keeper replaces the previous keeper for that song/section/region. The app may prompt for optional title, section, and free-text note, but metadata must not block the live rehearsal loop.

## Regions

The app should report both whole-take and selected-region analysis.

The selected region may be a chord, target vowel, release, tag, phrase section, or the full sung phrase. MVP only needs one active selected region at a time.

The app should auto-detect the likely sung region and attempt to align comparable regions across takes. Users must be able to adjust region handles by ear before trusting a comparison.

Changing region handles should require an explicit update action, such as Analyze Selected Region or Update Comparison, rather than constantly recalculating while the user drags.

Stacked waveforms for current and reference takes are the preferred UI direction for region alignment.

## Comparison and scoring

Comparison should explain metric-specific change, not produce a single overall take score.

Useful comparison claims include:

- Lock arrived sooner.
- Ring duration increased.
- Peak ring was similar.
- Roughness decreased slightly.
- Release timing changed; review by ear.
- Comparison confidence is low because one take clipped.

The app should stay neutral. It can describe evidence and change, but singers decide whether the result is musically better.

Quality language should be metric-specific. Avoid combined take grades, singer-level accusations, and negative adjectives.

## Export

Export supports real singer use outside rehearsal: sharing clips, singing against a good region in the car or at home, or assembling a reference track later in another audio tool.

MVP should support exporting selected keeper-region audio in a convenient format such as MP3-style audio. In-app stitched reference-track assembly is a future possibility, not an MVP requirement.

The app should preserve whatever internal audio and metadata are needed for future comparison, even if exported audio is compressed.

## Consequences

Implementation issues should preserve the rehearsal loop first. Live rehearsal should stay fast, with Record Next Take as the dominant follow-up action after review.

Feature work should identify how it supports takes, references, keepers, selected regions, comparison, playback, confidence, or export.

Future Codex tasks should not introduce top-level rehearsal modes unless they are clearly subordinate to the take-based workflow.
