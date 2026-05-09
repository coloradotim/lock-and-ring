# Signal Quality

Signal quality tells you whether the app trusts the current input.

- Signal too quiet: move closer or sing louder.
- Input clipping: reduce input level or move farther from the microphone.
- Excessive background noise: reduce room noise or move closer.
- Channel imbalance: check stereo microphone placement.
- Low confidence: wait for a steadier sung tone or fix the input.
- No signal detected: check microphone permission, input selection, and level.

When signal quality is poor, Lock & Ring keeps raw values available for
debugging but avoids strong singer-facing labels such as Locked, Strong, or
Stable.

Confidence is different from score. A take may show a high or low observed
metric value while still being too uncertain to interpret musically. In those
cases the app should say what made the analysis uncertain instead of claiming
that the take did or did not lock, ring, or stabilize.

For example, prefer "Could not reliably evaluate lock because the signal was
too quiet" over "This take did not lock" when confidence is low.
