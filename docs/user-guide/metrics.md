# Metrics

Lock & Ring uses metric-specific evidence. It should not collapse a take into one overall quality score.

Use the metrics to understand what changed, where it changed, and how confident the app is. Singers make the musical decision.

## Lock

Lock describes how organized and stable the chord appears harmonically. Higher usually means the ensemble sound is more aligned. The first-pass scorer looks for simple frequency ratios, harmonic organization, low roughness, and stable spectral peaks. It is best used as a relative rehearsal trend, not as proof that a specific voice is in or out of tune.

Useful lock outputs may include:

- lock level for the whole take
- lock level for the selected region
- time to lock
- best lock moment
- lock duration inside a trusted region

## Ring

Ring estimates organized upper harmonic reinforcement. It is a proxy for the expanded sound singers often hear when a chord lines up.

Ring should not simply mean brightness, loudness, or high-frequency energy. A bright or noisy sound is not automatically a ringing sound. Ring feedback should stay tied to organized overtone reinforcement, roughness, stability, and confidence.

Useful ring outputs may include:

- time to ring
- trusted ring duration
- peak ring
- ring quality/strength by metric-specific label
- ring confidence

## Roughness

Roughness estimates beating, interference, or unstable dissonance. Lower is usually smoother and more useful musically.

Comparison language should treat lower Roughness as improvement without using scolding language. Prefer "Roughness decreased" over "The take was less bad" or similar negative judgment.

## Stability

Stability describes whether the sound stays organized over time. It tracks whether spectral peaks persist, whether those peaks drift, and whether the energy distribution changes from frame to frame. A stable-but-detuned chord may still score well on Stability while scoring lower on Lock.

## Timing

Timing metrics describe when useful musical states arrive and how long they last. For serious quartet work, these may be as important as the raw metric levels.

Useful timing outputs may include:

- first vocal onset
- analyzable vowel start
- time to stable vowel
- time to lock
- time to ring
- trusted ring duration
- release timing

The app should avoid negative adjectives for consonants and releases. Prefer descriptions such as "stable vowel arrived later," "release timing changed," or "ring duration shortened."

## Confidence

Confidence describes how much the app trusts the measurement. Low confidence usually means the signal is too quiet, clipped, noisy, unstable, or affected by microphone placement.

These scores are trend-oriented and provisional. One microphone cannot reliably identify which singer is wrong. Use the app to compare ensemble changes, not to make singer-level accusations.

## Quality labels

Where the UI uses words for quality, they should be metric-specific and plain. Avoid a single overall label for the whole take.

Acceptable examples:

```text
Lock: High
Ring: Moderate
Roughness: Low
Stability: High
Confidence: Usable
```

Avoid:

```text
Overall take score: 87
Bad release
Wrong singer
Poor singing
```

When confidence is low, the app should say the measurement is uncertain instead of implying a musical failure.
