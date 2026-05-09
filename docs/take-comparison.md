# Take Comparison Workflow

Take comparison is an action inside the broader Take Analysis workflow. The
workflow stays snapshot-based so it can work with microphone-recorded takes or
imported takes without coupling future rehearsal sessions to one capture source.

## Current behavior

- Take A and Take B each store the analyzed `AnalysisFrame` snapshots captured
  between Record and Stop.
- Playback replays stored analysis snapshots through the existing live display.
- Take Analysis starts with the whole take, then lets users select non-destructive
  time regions for focused analysis.
- Saved regions stay attached to saved take metadata when the take is saved.
- Region playback can play or loop the selected window without trimming or
  changing the saved audio.
- The comparison summary averages lock, roughness, ring, and stability scores.
- Directional improvement treats higher lock, ring, and stability duration as
  better, while lower roughness is better.
- Stability duration estimates the share of take duration whose stability score
  is at least 65%.
- Timeline comparison aligns takes at the first detected onset when possible.
  If onset is missing, the comparison falls back to recording start and says so.
- Side-by-side timelines show phrase segments for each take. Overlay mode shows
  lock, ring, roughness, and stability curves on a shared time axis.

## Region Analysis

Whole-take analysis remains the default. Selected-region analysis is useful when a
take includes multiple attempts, silence, talking, or setup noise around the part
the singer actually wants to evaluate. Selecting a region scopes Take Quality,
Timing / Chord Behavior, phrase placeholders, and visual evidence to that time
window.

Regions are metadata on the take. They do not destructively trim audio. Users can
save multiple regions such as "Final chord" or "Second attempt" and return to the
whole take at any time.

Listening should sit beside metrics: users can play the whole take, play a
selected region, or loop a selected region while deciding what to try next.

## Reading The Visual Evidence

Take Analysis shows visual evidence as support for the app's interpretation, not
as a raw-audio test the singer has to decode alone.

- Waveform evidence is best for timing: sound onset, consonants, breaths,
  attacks, and other volume/transient changes.
- Spectrogram evidence is best for harmonic structure: upper partials,
  stability, ring, roughness, and noise.
- Metric curves and colored overlays are the interpretation layer. They are more
  important than raw color intensity because the app combines confidence,
  stability, roughness, lock, and ring evidence before making a claim.

The timeline legend uses these meanings:

- Consonant / onset: transient sound before the target vowel is analyzable.
- Searching: sung sound is present, but stable lock has not been detected.
- Stable: the sound is steadier, but not yet over the lock threshold.
- Locked: harmonic alignment stayed above threshold while roughness remained low.
- Ringing: upper harmonic energy increased while roughness remained low.
- Low confidence: signal quality is too weak, clipped, noisy, unstable, or
  otherwise unreliable for a strong musical claim.

Markers such as sound onset, vowel start, lock, ring, best lock, and best ring
are shown only when the analysis can identify them. Missing markers should be
read as "not enough evidence for that moment," not as a hidden failure.

## Phrase Segmentation

Phrase segmentation appears as a section inside Take Analysis. It is
chord-agnostic: it does not need chord names, lyrics, or a score. It labels each
frame with a deterministic first-pass category:

- Silence / breath
- Low confidence
- Consonant / onset
- Transition
- Tuning / searching
- Stable, not ringing
- Locked
- Ringing

The summary reports phrase duration, consonant/onset time, analyzable vowel
time, locked vowel time, ringing vowel time, tuning/searching time, stable
non-ringing time, breath/silence time, and low-confidence time. Locked and
ringing ratios use analyzable vowel time as the denominator. Consonants and
breaths are visible for efficiency coaching, but they are not scored as failed
lock. Low-confidence regions are excluded from strong musical claims.

## Future take-analysis shape

The `RecordedTake` model keeps the slot, label, timestamps, and immutable frames
separate from `TakeRecorder`, so broader rehearsal sessions can later group many
takes, add singer notes, persist take bundles, or compare imported takes without
changing the scoring contract.
