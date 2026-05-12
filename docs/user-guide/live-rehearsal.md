# Recording a Take

Recording a take starts the core Lock & Ring workflow. The app should help you confirm signal quality, capture one short attempt, inspect the current take, compare it to a reference, and quickly record again.

The app opens in a simple Ready state with two primary choices:

- Record Take
- Import Take

The selected microphone is remembered locally. On launch, Lock & Ring tries the saved device first, then prefers a built-in or internal Mac microphone before an iPhone or Continuity microphone. Changing the Mic menu saves that choice immediately.

While recording, the screen stays intentionally quiet. It shows elapsed time, signal quality, and a Stop action. The full Lock, Ring, Roughness, Stability, timing, phrase, region, comparison, and visual evidence sections appear after the take exists.

Most rehearsal recordings are expected to be phrase-length takes, often around 15-45 seconds, but the app should not block longer takes without a specific technical reason.

After recording stops, Take Analysis describes the completed take, not the live microphone feed. The quality metrics are frozen from the recorded frames until you record, import, or select another take. Playback appears with play/pause, elapsed time, duration, and scrubbing so you can listen before saving or recording again.

The first take in a run becomes the initial reference automatically. After that, the current take should be shown first, then compared against the active reference or keeper by default. The user should be able to compare against the previous take, any saved take, or an imported file when needed.

The review screen keeps the next decision near the summary: listen back, compare to reference, adjust the selected region, mark keeper, record again, or discard the unsaved take. Low-confidence takes show concrete recovery steps before the quality metrics so the next recording can be stronger.

Live rehearsal should require as little handling as possible. After a take is reviewed, the dominant next action should usually be Record Next Take.

When signal confidence is low, the app avoids strong claims. It may show one summary such as "Not enough usable signal to evaluate changes yet" instead of listing repeated metric warnings.

Use Take Analysis as a coaching clue. Descriptions such as "Lock arrived sooner," "Ring duration increased," or "Roughness was similar" should guide the next musical experiment, not become a score to chase. The main decision is what to do with the take after it exists: compare, adjust region, mark keeper, record again, export later, or discard.

Saved recorded takes include replayable local audio and appear in the Saved Takes list on the Ready screen. From there they can be played, reopened for Take Analysis, renamed, deleted, selected as a comparison reference, or used as keeper/reference material.
