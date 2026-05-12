# Chord and Phrase Timing

Chord and phrase timing is a Take Analysis capability. It asks how quickly the sound got through onset, became analyzable, locked, developed ring, and released inside a recorded or imported take.

## MVP Scope

The MVP should support phrase-length takes, usually around 15-45 seconds, with one active selected region at a time.

Users may record a phrase and then analyze:

- the whole take
- the auto-detected sung region
- one chord
- a target vowel
- a release
- a tag
- a section of the phrase

The MVP does not need to identify chord names, read notation, analyze multiple selected regions at once, or assign blame to individual singers.

This should be presented as a section inside Take Analysis, not as a separate user-facing lab or destination.

## Take Analysis Workflow

After a recorded or imported take is analyzed, Take Analysis includes a **Timing / Chord Behavior** section. The section starts with plain rehearsal language, such as whether lock arrived sooner, ring lasted longer, roughness decreased, or release timing changed. It then shows timing metrics, compact timeline, event markers, selected-region evidence, and any confidence warning for the same take.

Timing and chord-behavior results are not a separate top-level mode. They are part of the post-take review flow alongside current-take analysis, comparison, selected-region adjustment, mark-keeper, record-again, export, and discard actions.

## Whole Take and Selected Region

The app should report timing for both:

- **Whole take**: the full recorded phrase or imported take.
- **Selected region**: the focused musical moment the quartet is working on.

The app should auto-detect the likely sung region and offer a quick way to use detected singing as the selected analysis region. Users must be able to adjust the region handles by ear.

Changing region handles should require an explicit action such as Analyze Selected Region or Update Comparison.

## Timing Summary

Timing can report:

- sound onset time
- analyzable vowel start time
- consonant/onset duration
- time from vowel to stability
- time from vowel to lock
- time from vowel to ring
- trusted ring duration
- best lock score and when it occurred
- best ring score and when it occurred
- held-lock duration
- held-ring duration
- release timing
- largest delay contributor, when confidence supports that claim

If a region never locks or never rings, the timing remains blank for that event, but best locked-vowel and best ringing-vowel attempts are still reported. Those best markers are selected from trusted analyzable vowel frames, not from onset or consonant artifacts before vowel start.

## Timeline

The timeline uses simple segments:

- silence
- consonant/onset
- searching
- stable
- locked
- ringing
- low confidence

Markers show sound onset, analyzable vowel start, lock achieved, ring achieved, best locked vowel, and best ringing vowel when those events are detected.

## Detection Rules

The MVP uses provisional confidence-aware thresholds:

- sound onset begins when average metric confidence rises above a low threshold
- analyzable vowel start begins when confidence and stability evidence become usable for a short sustained period
- lock requires high lock score, enough lock confidence, enough stability, and acceptable roughness
- ring requires high ring score, enough ring confidence, and acceptable roughness
- lock and ring must hold for a short sustained duration before being reported as achieved

These rules are intentionally explainable and easy to calibrate. The thresholds are tuned so strong real quartet audio can register lock and ring in analyzable vowel regions, not only synthetic ideal tones. If a take has strong lock or ring moments that are too brief to satisfy the sustained-duration rule, Take Analysis should describe them as short moments rather than saying the chord never locked or rang. These are not final consonant or vowel classifiers.

## Comparison

For take-to-take comparison, timing should support both:

- whole take vs whole take
- selected region vs aligned selected region

The app should try to auto-align comparable regions across takes, but users must be able to adjust the current and reference region handles after listening.

Useful comparison language includes:

- lock arrived sooner
- ring arrived sooner
- ring lasted longer
- roughness decreased
- stable vowel arrived later
- release timing changed

Avoid negative adjectives for singers, consonants, or releases. Consonant time is visible, but it is not automatically bad. Good barbershop still needs clear consonants; timing helps show whether onset, tuning/searching, lock, or ring development consumed the most time.

## Caveats

The analysis is ensemble-level and single-microphone. It should guide rehearsal experiments, not produce singer-specific diagnosis.
