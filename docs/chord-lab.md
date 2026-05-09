# Chord Timing

Chord timing is a Take Analysis capability for sustained chord events. It asks how quickly the sound got through onset,
became analyzable, locked, and developed ring.

## MVP Scope

The MVP works on one sustained chord from an existing analyzed frame sequence, such as a recorded or imported take. It
does not try to analyze a full phrase, identify the chord name, read notation, or assign blame to individual singers.

This should be presented as a section inside Take Analysis, not as a separate user-facing lab or destination.

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

If a chord never locks or never rings, the timing remains blank for that event, but best lock and best ring attempts
are still reported.

## Timeline

The timeline uses simple segments:

- silence
- consonant/onset
- searching
- stable
- locked
- ringing
- low confidence

Markers show sound onset, analyzable vowel start, lock achieved, ring achieved, best lock, and best ring when those
events are detected.

## Detection Rules

The MVP uses provisional confidence-aware thresholds:

- sound onset begins when average metric confidence rises above a low threshold
- analyzable vowel start begins when confidence and stability evidence become usable for a short sustained period
- lock requires high lock score, enough lock confidence, enough stability, and acceptable roughness
- ring requires high ring score, enough ring confidence, and acceptable roughness
- lock and ring must hold for a short sustained duration before being reported as achieved

These rules are intentionally explainable and easy to calibrate. They are not final consonant or vowel classifiers.

## Caveats

Consonant time is visible, but it is not automatically bad. Good barbershop still needs clear consonants; chord timing
helps show whether onset, tuning/searching, lock, or ring development consumed the most time.

The analysis is ensemble-level and single-microphone. It should guide rehearsal experiments, not produce
singer-specific diagnosis.
