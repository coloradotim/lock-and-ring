# MVP Scope

## Product Thesis

Lock & Ring helps a quartet or vocal ensemble answer one rehearsal question:

```text
Did this take become more locked, less rough, more stable, and more ring-forward after an adjustment?
```

The MVP is not an automatic vocal coach and not a generic spectrum-analysis lab. It is a take-based,
single-microphone rehearsal analysis tool.

## Core Workflow

The long-term product model is:

```text
Ready -> Record or Import Take -> Analyze Take -> Save / Compare / Try Again / Discard
```

The primary object is a **take**. A take can be recorded through the microphone or imported from an audio file. Once the
take exists, the app should show **Take Analysis** rather than sending the user into separate mode-first destinations.

Take Analysis should include or eventually include:

- overall summary
- signal quality and confidence
- Lock, Ring, Roughness, and Stability
- timing / chord behavior
- phrase segmentation
- timeline and visual evidence
- comparison to another take

## Target User

The first target user is a barbershop quartet, small vocal ensemble, coach, or musically curious singer using a Mac in a
rehearsal room.

They need:

- quick setup with the built-in or an external microphone
- an obvious path to record or import a take
- feedback that is readable from a few feet away
- a way to compare two short attempts
- language that supports musical decisions instead of technical rabbit holes

They do not need a studio workflow, accounts, collaboration features, or singer-by-singer diagnosis in the MVP.

## First Rehearsal Workflow

1. Open Lock & Ring.
2. Select or confirm the microphone.
3. Check that the input level is healthy and not clipping.
4. Record or import a short take.
5. Review Take Analysis.
6. Make one musical adjustment, such as vowel alignment, interval tuning, balance, or breath timing.
7. Record or import another take.
8. Compare takes.
9. Save, try again, or discard.

The first comparison should emphasize direction, not judgment. Useful answers sound like:

- Roughness decreased.
- Ring increased.
- Stability improved.
- The second take looked less confident because the signal clipped.
- Chord timing showed ring arrived later than lock.

## Take Analysis Sections

### Capture / Import

Purpose: create the take.

Must support:

- recording a short take through the selected microphone
- importing an audio file and treating it as a take
- showing input level, clipping, mono/stereo status, and signal confidence
- discarding and trying again

### Overall Summary

Purpose: answer what happened in singer-friendly language.

Must show:

- whether the take had enough confidence to interpret
- headline Lock, Ring, Roughness, and Stability results
- whether comparison to another take is available

### Timing / Chord Behavior

Purpose: explain how a sustained chord developed over time.

Must show, when available:

- consonant/onset duration
- analyzable vowel start
- time to lock
- time to ring
- best lock and best ring attempts

Chord timing is a section inside Take Analysis, not a separate user-facing destination.

### Phrase Segmentation

Purpose: eventually split longer takes into useful regions.

This is not required for the current MVP, but when implemented it should feed a Phrase section inside Take Analysis.

### Timeline / Visual Evidence

Purpose: let singers see why the summary says what it says.

May include:

- spectrum and spectrogram evidence
- metric curves
- chord timing markers
- phrase region overlays

Visualizations should support Take Analysis rather than becoming a separate product mode.

### Compare

Purpose: answer whether a musical adjustment helped.

Must show:

- before/after summary for Lock, Ring, Roughness, and Stability
- timing or phrase differences when available
- simple directional language
- enough detail to see whether confidence or clipping affected the result

## Basic Terminology

Take:
A recorded or imported audio attempt that can be analyzed, saved, compared, retried, or discarded.

Take Analysis:
The user-facing analysis surface for one take. Timing, phrase, visualization, scoring, and comparison features should
appear as sections or actions here.

Lock:
Pitch and harmonic alignment around simple relationships. The MVP should present this as "more locked" or "less locked,"
not as exact singer-level correction.

Ring:
An observable proxy for reinforced upper partials and spectral organization. The MVP should say "more ring-forward" or
"less ring-forward," not claim to measure ring as a mystical truth.

Roughness:
Beating, competing partials, and dissonance-like spectral interaction. The MVP should report whether roughness increased
or decreased.

Stability:
How consistently the sound stays organized over time. The MVP should distinguish a stable sustained chord from a
drifting or noisy one.

Confidence:
How much the app trusts the signal and analysis. Low input, clipping, high noise, or unstable peak detection should
lower confidence.

## MVP Feature Boundaries

In scope:

- macOS-native app
- single microphone input
- imported audio treated as takes
- built-in and external microphone selection
- signal-quality monitoring
- Take Analysis for Lock, Ring, Roughness, and Stability
- chord timing inside Take Analysis when available
- take comparison
- synthetic fixture tests for DSP behavior
- clear documentation of scoring limitations

Out of scope:

- singer-specific correction
- full song transcription
- automatic chord recognition as a dependency
- multi-mic workflows
- cloud accounts
- social or sharing features
- mobile or web versions
- AI coaching claims
- polished studio production tools
- separate Chord Lab or Phrase Lab destinations as primary user workflows

## Success Criteria

The MVP is successful when a quartet can use it during rehearsal to record or import a take, understand the take, make
one focused adjustment, and decide what to do next.

Concrete success criteria:

- A fresh checkout builds and tests in CI.
- The app opens quickly and makes record/import obvious.
- Take Analysis appears after a take exists.
- Short takes can be recorded or imported.
- Comparison shows directionally useful changes.
- Warnings make bad input obvious.
- The app avoids overclaiming what a single microphone can know.

## Future Ideas, Not MVP Scope

Capture these ideas for later without pulling them into the first usable workflow:

- chord-aware interpretation
- root selection or pitch reference
- singer-specific diagnosis
- multi-microphone capture
- rehearsal take library
- trend history across sessions
- coach annotations
- exportable reports
- real recording calibration sets
- advanced harmonic entropy or temporal partial tracking

Every feature should serve the unified Take Analysis workflow until that workflow feels useful with real singers.
