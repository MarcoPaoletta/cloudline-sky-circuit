# Build times

How long each version of Cloudline took Claude, measured from the Claude Code session timestamps: from the message that asked for the version to the commit that delivered it. **Active work** leaves out pauses longer than 20 minutes, such as the overnight break and waiting for Marco. **Wall clock** is the full span. Times are Argentina time (UTC-3).

| Version | Branch / tag | Asked | Delivered | Active work | Wall clock |
| --- | --- | --- | --- | --- | --- |
| v1: the complete game | `v1` | 17 Oct 15:04 | 17 Oct 23:13 | 8 h 08 min | 8 h 08 min |
| v2: playtest changes (music, soft SFX, arena paint, hit feedback, sprint, crowds, dev tools, lighting lab) | `v2` | 17 Oct 23:35 | 18 Oct 10:51 | 2 h 26 min | 11 h 16 min (overnight pause) |
| v3: mobile / iPhone (touch controls, phone layout, iOS preset, mobile budget) | `v3` (also `master`) | 18 Oct 10:55 | 18 Oct 11:50, first pass (iPhone test pending) | 55 min | 55 min |

**Total active work across the three versions: about 11 h 29 min** (8 h 08 min + 2 h 26 min + 55 min).

v2's time is its main build (1 h 20 min) plus three follow-ups: the lighting lab load fix, the per-island crowds and the enemy variety. v3's time so far also covers setting up the v1 and v2 recording copies.
