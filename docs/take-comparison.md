# Take Comparison Workflow

Take comparison is an action inside the broader Take Analysis workflow. The
workflow stays snapshot-based so it can work with microphone-recorded takes or
imported takes without coupling future rehearsal sessions to one capture source.

## Current behavior

- Take A and Take B each store the analyzed `AnalysisFrame` snapshots captured
  between Record and Stop.
- Playback replays stored analysis snapshots through the existing live display.
- The comparison summary averages lock, roughness, ring, and stability scores.
- Directional improvement treats higher lock, ring, and stability duration as
  better, while lower roughness is better.
- Stability duration estimates the share of take duration whose stability score
  is at least 65%.

## Future take-analysis shape

The `RecordedTake` model keeps the slot, label, timestamps, and immutable frames
separate from `TakeRecorder`, so broader rehearsal sessions can later group many
takes, add singer notes, persist take bundles, or compare imported takes without
changing the scoring contract.
