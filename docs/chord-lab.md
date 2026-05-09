# Chord Timing

Chord timing is a Take Analysis capability for sustained chord events. It asks how quickly the sound got through onset,
became analyzable, locked, and developed ring.

## MVP Scope

The MVP works on one sustained chord from an existing analyzed frame sequence, such as a recorded or imported take. It
does not try to analyze a full phrase, identify the chord name, read notation, or assign blame to individual singers.

This should be presented as a section inside Take Analysis, not as a separate user-facing lab or destination.

## Take Analysis Workflow

After a recorded or imported take is analyzed, Take Analysis includes a **Timing / Chord Behavior** section. The section
starts with plain rehearsal language, such as whether the chord locked quickly, locked without developing strong ring, or
did not lock. It then shows the timing metrics, compact timeline, event markers, and any confidence warning for the same
take.

Timing and chord-behavior results are not a separate top-level mode. They are part of the post-take review flow alongside
save, compare, try-again, and discard actions.

## Timing Summary

Chord timing reports:

- sound onset time
- analyzable vowel start time
- consonant/onset duration
- time from vowel to stability
- time from vowel to lock
- time from vowel to ring
- best lock score and when it occurred
- best ring score and when it occurred
- held-lock duration
- held-ring duration
- largest delay contributor

If a chord never locks or never rings, the timing remains blank for that event, but best locked-vowel and best
ringing-vowel attempts are still reported. Those best markers are selected from trusted analyzable vowel frames, not
from onset or consonant artifacts before vowel start.

## Timeline

The timeline uses simple segments:

- silence
- consonant/onset
- searching
- stable
- locked
- ringing
- low confidence

Markers show sound onset, analyzable vowel start, lock achieved, ring achieved, best locked vowel, and best ringing
vowel when those events are detected.

## Detection Rules

The MVP uses provisional confidence-aware thresholds:

- sound onset begins when average metric confidence rises above a low threshold
- analyzable vowel start begins when confidence and stability evidence become usable for a short sustained period
- lock requires high lock score, enough lock confidence, enough stability, and acceptable roughness
- ring requires high ring score, enough ring confidence, and acceptable roughness
- lock and ring must hold for a short sustained duration before being reported as achieved

These rules are intentionally explainable and easy to calibrate. The thresholds are tuned so strong real quartet audio
can register lock and ring in analyzable vowel regions, not only synthetic ideal tones. If a take has strong lock or ring
moments that are too brief to satisfy the sustained-duration rule, Take Analysis should describe them as short moments
rather than saying the chord never locked or rang. These are not final consonant or vowel classifiers.

## Caveats

Consonant time is visible, but it is not automatically bad. Good barbershop still needs clear consonants; chord timing
helps show whether onset, tuning/searching, lock, or ring development consumed the most time.

The analysis is ensemble-level and single-microphone. It should guide rehearsal experiments, not produce
singer-specific diagnosis.
