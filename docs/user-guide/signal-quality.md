# Signal Quality

Signal quality tells you whether the app trusts the current input.

Mic / Room Readiness appears on the Ready screen and during recording. It is a
technical setup check, not a musical grade. A take can be musically excellent but
technically hard to analyze if the mic is too far away, the input clips, the room
is noisy, or a stereo mic is badly imbalanced. A technically clean take can still
be musically rough.

- Signal too quiet: move closer or sing louder.
- Input clipping: reduce input level or move farther from the microphone.
- Excessive background noise: reduce room noise or move closer.
- Channel imbalance: check stereo microphone placement.
- Low confidence: wait for a steadier sung tone or fix the input.
- No signal detected: check microphone permission, input selection, and level.

When signal quality is poor, Lock & Ring keeps raw values available for
debugging but avoids strong singer-facing labels such as Locked, Strong, or
Stable.

For a single built-in or external mono microphone, place the mic where it hears
the quartet as one ensemble sound rather than one singer dominating. For an
external stereo or XY microphone, point the pair toward the center of the quartet
and keep singers balanced around the stereo image. If the app reports a left- or
right-heavy signal, reposition the mic or the singers before recording.

Use Check Mic Setup by singing or speaking at rehearsal volume for about 3
seconds. The result tells you whether setup looks usable or gives a concrete fix:
move closer, lower input gain, reduce background noise, or rebalance a stereo mic.

Confidence is different from score. A take may show a high or low observed
metric value while still being too uncertain to interpret musically. In those
cases the app should say what made the analysis uncertain instead of claiming
that the take did or did not lock, ring, or stabilize.

For example, prefer "Could not reliably evaluate lock because the signal was
too quiet" over "This take did not lock" when confidence is low.
