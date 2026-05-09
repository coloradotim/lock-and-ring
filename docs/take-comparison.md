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

## Future take-analysis shape

The `RecordedTake` model keeps the slot, label, timestamps, and immutable frames
separate from `TakeRecorder`, so broader rehearsal sessions can later group many
takes, add singer notes, persist take bundles, or compare imported takes without
changing the scoring contract.
