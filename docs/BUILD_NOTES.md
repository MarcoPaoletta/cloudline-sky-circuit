# Cloudline design delivery notes

17 October 2026. Design package revision 1.0.

This delivery creates a GDD, concept art, a public design website, source evidence and the freshly pulled game-dev skill snapshot. It does not implement gameplay, change renderer settings, create gameplay scenes or claim a playable game.

## Existing project inspected

Xogot 1.7.3, Godot 4.7.2, project `Xogot Course`. Existing renderer is Mobile. No authored `.tscn` or `.gd` gameplay files were found. Imported robot has 14 clips and a separate unskinned head; hands use skinning. Prior six prop load-checks retained.

## Skill

Fresh clone followed by `git pull --ff-only`: already up to date at `22fe20ab13670b63b8c8326916ec4a6bdc2453d5`, game-dev 1.9.0. Read before GDD authoring, with camera, concept matching, launch, props and UI references. User explicitly authorized public publication of this project copy, overriding its private-distribution default.

## Scope decisions

Three levels, four chosen mechanics. Motion Bank and Echo Shift excluded. Ground pads give automatic entry into a perspective overview, Left/Right controls one configured group along one axis, E/Escape exits. No gameplay implementation or exports requested in this turn.

## Implementation evidence to add later

Do not mark the game done until runtime concept comparisons, meaningful mechanic tests, reset/pause/save tests, camera transitions, moving-platform riding, all routes to flags, UI aspect matrix and level-three performance have been captured. `comparison-final.png` is a future build gate; the concepts themselves are not runtime evidence.

## Arena/paint steering and final source update

Marco added bowling-head combat, three arena finales with gradual portal waves, one/two summoning bosses and 30–65 second target clears. He confirmed every level starts with platforming. Camera reference is the THREE QUICK WAVES panel: low perspective behind the robot. Circular overview is planning-only. Added 21 final concept images and GDD superseding sections 20–21.

Skill re-pulled after Marco announced update: 22fe20ab13670b63b8c8326916ec4a6bdc2453d5, 1.9.0. Read the full paint-splash reference, adapted it to visual death splashes without copying paint-gun gravity-bypass mechanics into the bowling head.

Cute monster source Drive downloads returned quota-exceeded HTML, so downloaded Quaternius's own OpenGameArt ZIP. Five FBXs and five PNG maps transferred. All meshes/clips instantiated in Xogot; Mushroom has Idle only, not the pack's common 10-clip set. Current raw-FBX material inspection found no bound albedo texture, so wrapper material setup remains explicitly documented. No false texture-ready/gameplay-ready claim.

## Final skill refresh

Fresh pull after Marco's second update: 1f54afc4cd24f163eb11d8a65ce8950eedaa1edd, 1.9.0, 14:44:00 Argentina time. Read full updated paint-splash document and inspected three source screenshots. GDD §22 gives the puddle/decal itself priority, and excludes irrelevant Splatwalk docking/ink/paint-platform mechanics. All 21 monster models and original maps are now available in the local asset bank; the active gameplay roster remains curated.


## Implementation notes (the built game)

17 October 2026. The sections above are the design delivery history and stay as written. Everything below describes the game that now exists in this project, built from saved scenes through `xo`.

### What was built

- **Title and menus.** Living-world title (camera cuts through a diorama of the opening vista, robot waving), Continue / New Game / Worlds / Settings / Quit, a Ready screen when Continue resumes a pending arena, a campaign-complete panel, the pause menu (Controls, Hint Log, Restart from checkpoint, Restart world or Retry arena, Settings, Return to title) and a Settings panel with sliders, toggles and key remapping that swaps clashing keys. F1 opens a development panel (coins, level and arena select, checkpoint teleport, puzzle reset, return parts, invulnerability, unlock all, 1x/2x/4x speed, Erase Save with confirmation); it is hidden at boot and removes itself in release builds. The game boots muted; M toggles on every screen.
- **Three platform worlds** (saved scenes composed of saved scenes; nothing is built at runtime): Sunrise Junction (27 fixed islands + 1 balance island), Cargo Gardens (42 fixed islands + 1 balance island), Crown Circuit (61 fixed islands + 3 balance islands). World two has three routes (Low Canal: relay-powered cargo door, crate, balance island, shuttle; High Orchard: two lifts, a jump pad and a one-way drop back to the hub; Console Terrace: orbit console and a vertical slide lift bridge). World three has Low, Mid and High rings that rise to a plaza at the Crown Approach, two final lanes (head-powered bridge or moving-platform lane) and the Flag Crown under a ring of rock spires. Worlds one and three have a cyan return pad that carries the robot back to an earlier hub once the late checkpoint is active.
- **Three circular arenas** (Opening Burst, The Summoner, Twin Paintstorm) reached by a fade from each flag, with portal waves, the Yeti bosses, surface paint, results and retry that never touches the platform world.
- **Campaign state.** Flag and arena progress are separate saved fields; a quit during the flag-to-arena handoff resumes on the arena's Ready screen; checkpoints, flags, arena clears, close and pause bank the save (temp file plus backup); erase keeps comfort settings.

### The bright toon look (Marco's note: the build lacked the concepts' toony, bright look)

- **Materials.** Every vendor material name is remapped to a toon ShaderMaterial in the glTF import settings (vendor models untouched). `toon_surface.gdshader`: flat facets, soft two-step sun light, warm shade, rim glow, patch noise; rock bodies are tapered, wobbled and facet-jittered; arena grass has a mowed-lawn checker. `toon_cloud.gdshader`: unshaded white faceted cumulus shaded by height, normal and altitude, with a gentle vertex-stage bob (no per-frame script work).
- **Light.** One shadowed sun (energy 1.5, opacity 0.7, 80 m), Linear tonemap, ambient 0.6, exposure 0.9 (tuned per world against the brightness gate), low glow, saturation 1.2-1.3 and a light blue fog. Three times of day, each its own Environment, cloud material, sun tint and SkyGlow direction: Morning (world one), Midday (world two, arenas, title), Golden afternoon (world three). The sun disc and glow are camera-anchored quads, not lights.
- **Clouds and sky.** A cloud sea under the world, a cloud pillow under every island, cumulus mountains around the rim, loose clumps and a far horizon ring; no puff may enter the play volume of any island, so the camera is never inside a cloud and no landing is hidden. 80-120 decorative far islands with bushes and rocks per world, some far below the route, and grass tufts on every island; arenas add tufts and white flowers.
- **Measured against ART-TARGETS.** Runtime frames at each world's overview camera, after the color passes (PIL grayscale mean and mean saturation, the ART-TARGETS method). All three worlds are inside the brightness gate (within 10 of the concept). Images: `docs/evidence/comparison-final.png` (final), `comparison-01.png` to `comparison-03.png` (rounds).

| Target | Concept mean gray | Runtime mean gray | Concept sat | Runtime sat | Concept grass | Runtime grass |
| --- | --- | --- | --- | --- | --- | --- |
| 02 Sunrise Junction | 197.7 | 204.7 | 0.35 | 0.30 | #e7e423 | #e0e606 |
| 03 Cargo Gardens | 195.4 | 202.1 | 0.39 | 0.35 | #eefa47 | #cdf009 |
| 04 Crown Circuit | 186.0 | 189.2 | 0.39 | 0.39 | #f0da35 | #dbe300 |

### How it was verified

Checks drive the real game through input actions, UI focus or the same public methods the flag and checkpoints call; nothing here is claimed beyond the rows below.

| Check | Result |
| --- | --- |
| World one route bots: arrival, relay, balance, orbit, junction lift, high route and jump pad, slide console, summit and flag, low route with shuttle and ramps | 33 of 33 checks pass |
| Campaign flow bot: flag, fade, arena 1, results, world 2, arena 2, world 3, arena 3, Finish, title complete panel | 25 of 25 checks pass |
| Campaign rules: a pending arena survives replaying an earlier world; atomic save with backup and restore; out-of-range pending arena; authored UI/Ambience bus offsets | 15 of 15 checks pass |
| Return pad (world one): locked until the Summit checkpoint, then carries the robot to the Junction with input enabled | 8 of 8 checks pass |
| Respawn with the head seated in a socket returns the head and unpowers the socket | 5 of 5 checks pass |
| Arena crowd: horde monsters never interpenetrate (minimum ground distance between any two monsters, worst case: idle invulnerable player under a full wave) | arena 1: 1.43 m, arena 3: 1.50 m, no pair under 1.3 m |
| Smoke run of title, three worlds and three arenas | all run, 0 new engine errors |

### Performance (editor-embedded run on the development Mac)

| Scene | fps | draw calls | objects |
| --- | --- | --- | --- |
| Title | 60 | 536 | 688 |
| World 1 (spawn view) | 60 | 1334 | 1374 |
| World 2 (spawn view) | 60 | 223 | 223 |
| World 3 (spawn view) | 60 | 154 | 154 |
| Arena 1 (wave) | 60 | 884 | 899 |
| Arena 2 (wave) | 60 | 1059 | 1082 |
| Arena 3 (wave) | 60 | 1092 | 1123 |

Only the development device was measured; no iPad or weakest-device result is claimed.

### Decisions, deviations and gaps

- The game-dev installer from ~/.claude/CLAUDE.md was not run: it would overwrite `skills/README.md` (Marco's public-sharing exception) and add private .gitignore rules. The skill was pulled (HEAD 1f54afc, identical to the project snapshot).
- Overview cameras are not a one-to-one match of the concept compositions: the level graphs of GDD section 9 decide island positions, so the comparisons match palette, light, sky and clouds rather than exact framing.
- Portals are an authored stone arch with a procedural vortex shader; no external portal asset was downloaded.
- Not measured: iPad or weakest-device frame times, human playtests of the arena clear times, an aspect-ratio matrix capture. No music (the supplied audio pack is sound effects only).
- Code review fixes: Return Pad input lock and unlock, pending arena overwrite, save atomicity, respawn returning parts, latched gate closing, audio bus offsets, horde clamp radius in arenas 2 and 3, jump pad vs buffered jump, paint decals on the robot, console prompt restore, socket highlight after a plain bowl, duplicate wave banner.
