# Take Analysis and Comparison

Take Analysis answers: what happened in the current take?

Comparison answers: what changed against the reference, and is that change useful enough for the singers to act on?

Recommended live workflow:

1. Record or import a take.
2. Review current Take Analysis: signal quality, Lock, Ring, Roughness, Stability, timing, selected region, and visual evidence.
3. Let the first take in a run become the initial reference automatically.
4. Make one musical adjustment.
5. Record or import another take.
6. Compare the current take against the active reference or keeper.
7. Adjust the selected region if the app did not choose the musical moment that matters.
8. Click an explicit action such as Analyze Selected Region or Update Analysis after changing the region.
9. Listen A/B between current and reference regions.
10. Mark keeper if the current selected region is the best-so-far example, or record again.

## Current, reference, and keeper

Lock & Ring uses three related but separate concepts:

- **Current take**: the take being inspected right now.
- **Reference take**: the take or imported file used as the comparison target.
- **Keeper**: the best-so-far take/region for the current song, section, or musical target.

The active reference may be the keeper, the previous take, any saved take, or an imported file. The default should be the active keeper/reference, not necessarily the immediately previous take, because the last few takes may be experiments or throwaways.

Marking a keeper replaces the previous keeper for that song/section/region. The app may prompt for an optional title, section, and note, but metadata should not be required before rehearsal continues.

## Whole take and selected region

The app should report both:

- **Whole-take analysis**, which describes the full recorded phrase or take.
- **Selected-region analysis**, which describes the focused musical moment the quartet is working on.

The selected region may be a chord, target vowel, release, tag, phrase section, or the full sung phrase. The app should auto-detect the likely sung region and help align comparable regions across takes, but users must be able to adjust regions by ear.

Only one selected region needs to be active at a time for MVP.

## Region comparison

When comparing selected regions across takes, the app should try to auto-align the matching region in the reference take. The user should be able to listen and adjust the current and reference region handles before trusting the comparison.

Changing region handles should not constantly recalculate while the user is dragging. Use an explicit action such as Analyze Selected Region or Update Comparison.

Comparison should cover both:

- whole take vs whole take
- selected region vs aligned selected region

## What comparison should say

Comparison should focus on directional change and metric-specific quality. It should not produce a single combined take score.

Useful comparison examples:

```text
Lock arrived sooner.
Ring duration increased.
Peak ring was similar.
Roughness decreased slightly.
Release timing changed; review by ear.
Comparison confidence is low because the reference signal clipped.
```

The app should stay neutral. It may describe changes, but singers decide whether the take is musically better or should become the keeper.

## Timing metrics

When chord or phrase timing is available, Take Analysis should include:

- first vocal onset
- analyzable vowel start
- time to lock
- time to ring
- trusted ring duration
- best lock moment
- best ring moment
- release timing

Timing is not a separate destination the singer needs to choose before recording. It is part of Take Analysis and selected-region comparison.

## Saved takes

Saved takes are local-only for now. A saved take should store replayable audio, source type, duration, created date, confidence, selected-region metadata, and summary metadata so it can be reopened later from the Saved Takes list and compared again.

If future comparison requires analysis-grade audio, the app should preserve that internally even when exported audio uses a more convenient compressed format.

The comparison language treats lower Roughness as a musical improvement, even though the raw roughness score decreases. Higher Lock, Ring, and Stability are usually better.

If one take has low confidence, the comparison may be unreliable. Record again with a steadier signal before making rehearsal decisions.
