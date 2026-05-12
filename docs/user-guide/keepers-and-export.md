# Keepers and Export

A keeper is the best-so-far take or selected region for a song, section, or musical target.

Keepers are for rehearsal decisions, not for judging singers. A keeper means:

```text
This is the current reference we want to beat or sing against.
```

## Keeper behavior

For MVP, there should be one active keeper for a song/section/region target. Marking a new keeper replaces the previous keeper.

When a user marks a keeper, the app should:

- save the current take if needed
- preserve the selected region metadata
- make the keeper available as the default comparison reference
- prompt for optional title, section, and note
- avoid requiring metadata before rehearsal can continue

If no title is provided, the app can create a sensible default title from date/time and available context.

## Reference behavior

The active reference is the take or imported file used for comparison. The reference may be:

- the first take in a run
- the current keeper
- the previous take
- any saved take
- an imported file

The first take in a run should become the initial reference automatically. After a keeper exists, comparison should usually default to the keeper/reference, not necessarily the immediately previous take.

## Notes

Notes should be optional free text for MVP.

Useful notes might include:

- "bari narrowed vowel"
- "bass lighter"
- "lead less spread"
- "cleaner release attempt"
- "faster target vowel"

Do not require structured tags or song database cleanup during live rehearsal.

## Export

Export is for real singer use: sharing clips, singing against a good region in the car or at home, or assembling a reference track later in another tool.

For MVP, export should prioritize convenient audio clips, such as MP3-style files, rather than audiophile workflow complexity.

The app should support exporting selected keeper-region audio. Full-take export may also be useful, but selected-region export is the more important rehearsal use case.

The app does not need to assemble stitched reference tracks in MVP. Users can export individual keeper clips and assemble them later in Audacity, GarageBand, or another audio tool.

## Internal audio preservation

User-facing export can be compressed and convenient, but the app should preserve whatever internal audio is needed for future comparison.

If future comparison requires analysis-grade audio, do not rely only on exported compressed files. Keep source or analysis-grade audio internally, along with selected-region metadata and saved analysis snapshots.

## Non-goals for MVP

- Full DAW-style editing
- Multi-region comping inside the app
- In-app stitched reference-track assembly
- Forced song/session management before recording
- Required notes or structured metadata
