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


## v2: playtest changes (18 October 2026)

Marco's v2 list, after playing v1, and what changed for each item. Everything is authored through `xo` like v1 (saved scenes and resources, no runtime-built trees). v1 stays available as the `v1` tag and branch.

| Request | What changed |
| --- | --- |
| Music: one for the main menu, one for the platforms, one for the arena battles | Three original looping tracks, generated for the game (`assets/cloudline/audio/music/`): *Sky Lullaby* (title, 70 BPM: pad, music box, flute), *Cloud Hop* (worlds, 100 BPM: plucked bass, off-beat marimba, soft kit, whistle melody) and *Paint Rush* (arenas, 124 BPM: pulse bass, kalimba arpeggio, soft four-on-the-floor kit, bright lead). Each is rendered twice in a row and the second pass is kept, so the loop seam is clean. They play on a new Music bus through two players in `audio.tscn` that crossfade over 1.4 s (`Audio.play_music`). Settings has a Music slider. The game still boots muted; M toggles. |
| Better, more relaxing SFX | A soft set of 51 sounds made for the game (`assets/cloudline/audio/soft/`): warm bells, marimba, kalimba plucks, soft thumps and airy whooshes, with no square waves and no hard clicks. `Audio` prefers a soft sound when one exists for an id, so the pack sounds stay in the project untouched as a fallback. |
| More enemies: 5 to 20 on every platform, by its size | Every island now holds 5 to 20 enemies by size: 4 m: 5, 6 m: 7, 8 m: 10, 12 m: 15, 16 m: 20. The crowd mixes six enemy types: bees (about 30 %), crabs, and four platform monsters made from the arena monster models (alien, cactus, cyclops, and a hopping mushroom). The monsters are `scenes/enemies/*_walker.tscn` and use the crab's patrol, chase and bite behaviour with their own clips. World 1: 278 enemies, world 2: 481, world 3: 680. A planner placed them (`World/Crowd` in each world, authored through `xo`). Each enemy keeps clear of the spawn, checkpoints, the flag, consoles, sockets, pads, movers and props, with 1.25–1.55 m between crabs and 1.9–2.4 m between bees. Every one has its own reward coin. To keep that affordable, enemies more than 32 m from the robot sleep (no AI, no animation), and the level wakes them in a round-robin pass of 90 a frame. Enemy models stop rendering beyond 70 m. Crabs collide with each other (no clipping), but never with the robot. Measured at 60 fps everywhere tried (up to 104 enemies awake at world 3's hub, physics 3–5 ms). |
| Do not darken the head when throwing it | The thrown head (and the fetch arm) used the vendor's original materials, extracted with the mesh, so it went dark the moment it left the body. Both now use the same toon robot materials as the body. |
| Enemies flash white when the head hits them | Every head hit lays a white unshaded overlay on all of the enemy's meshes for 0.07 s, with a 45 ms hit stop (shared by a whole chain, skipped with Reduced Motion). Bosses flash too. |
| No paint on the arena floor | Root cause: the Mobile renderer applies at most 8 decals to one mesh, and every arena floor is a single mesh already carrying 14 dirt-patch decals, so no paint decal ever got a slot. Island tops were fine. Flat ground now gets a flat splat: a toon-lit quad with the same six splat shapes (`paint_splat.tscn`, pool of 96). Slopes and island edges still get the wrapping decal. Arena paint stays vivid for 16 s instead of 4 and the splats are a bit larger, so the floor visibly fills with colour during a fight. The dirt decals no longer tint the splats or the characters. |
| Hit enemies fall back instead of being squeezed | A defeated enemy is thrown back along the head's roll with a small arc, tips over onto its back in its recoil pose, lies there for 0.45 s and then shrinks away evenly. The Yeti takes a short shove on each hit and topples slowly when beaten. |
| Hold Shift to sprint | New `sprint` action (Shift, left stick click), remappable in Settings and listed on the pause menu's Controls page. Sprint is 9.5 m/s (run is 6) with faster footsteps and a 6° wider camera (none with Reduced Motion). |
| Fly mode in the debug panel | F1 → Fly mode: no gravity and no collision. Jump rises, C or Ctrl sinks, Sprint flies fast. |
| Go near the flag and complete arena buttons | F1 → Go to flag lands the robot on solid ground a few metres from the world's flag, facing it. F1 → Complete arena defeats everything on the field and runs the normal victory (clear saved, banner, results). |
| At least 3 places to leave the head in each world | Each world now has 3 sockets, and every new one powers something. World 1: Low Loop island (bridge to a coin pocket with a bee) and the summit's S2 (bridge to a coin pocket with a crab). World 2: the hub's north-west island and Summit 1c, each opening a bridge to a coin pocket. World 3: the Exchange's north-east island, opening a bridge to a coin pocket. The original door and Crown sockets stay. The catch funnel grew from 1.0 to 1.25 m: a head rolled along the floor could touch the pedestal before entering the old sphere and bounce off, depending on frame timing. |
| Bees too high to hit and unable to hurt | Placements stand bees about 3.4 m over the floor. Bees now hover 0.9 m over the floor under their placement, so a rolled head hits them and their hurtbox reaches the ground. During the 0.8 s wind-up they drift toward the robot (inside their leash, stopping 2.2 m away), so the dive connects unless the robot moves. Their dive can now go below the hover height. |
| F2 lighting lab (concept on the left, game on the right) | New development-only overlay (`scenes/core/lighting_lab.tscn`, F2, also on the F1 panel). The concept image for the current scene is on the left, with a cycle through all 21 concepts. The live game is on the right, drawn by a second camera in the same world, so the HUD stays out of the frame. Concept camera snaps to the scene's ConceptCam. Below are live controls: exposure, saturation, contrast, brightness, ambient, glow and fog; sun energy, colour, elevation, azimuth and shadow opacity; sky colours; grass, rock, bush and cloud colours. **Save to project** writes the Environment and toon materials into their `.tres` files (keeping their UIDs) and the Sun into `res://resources/lighting/<scene>.tres`, a `LightingPreset` the scene applies on load in every build. **Copy values** puts a text summary on the clipboard. |

### How v2 was verified

| Check | Result |
| --- | --- |
| v2 world checks, each world: hundreds of enemies (278 / 481 / 680, 5 to 20 per island); 3 sockets, each catching a head rolled along the floor and powering its device; every bee at most 1.2 m over its floor (worst 0.90 m); a rolled head defeats a bee; a bee dive damages the robot; sprint 9.5 m/s and back to 6; fly mode up and collisions restored; Go to flag lands within 6.5 m on the floor; platform music; thrown head uses the toon robot materials | 19 of 19 in each world (57 of 57) |
| v2 arena checks, each arena: arena music; monsters arrive; a head hit flashes white; the monster is thrown back (more than 0.8 m) and tips over (more than 45°); a flat paint splat is laid and visible; the fallen monster is freed; Complete arena runs the victory and clears the field | 10 of 10 in each arena (30 of 30) |
| World one route bots (arrival, relay, balance, orbit, junction lift, high route, slide, summit, low loop) | 31 of 31; the junction bot now waits for a fresh lift arrival (it used to start walking at the end of the lift's bottom pause) |
| Campaign flow bot (flag, fade, all three arenas, results, Finish, title panel) | 25 of 25 |
| Campaign rules (pending arena, atomic save and backup, validated pending arena, bus offsets) | 15 of 15 |
| Return pad / respawn returns the parts | 8 of 8 / 5 of 5 |
| Arena crowd spacing with full waves | arena 1: 1.39 m, arena 3: 1.37 m minimum, no pair under 1.3 m |
| Smoke run of the title, three worlds and three arenas | all 0 new engine errors; 59-60 fps on the development Mac |

### v2 notes and gaps

- The music and the soft sounds were generated for this game from scratch (sine, FM bell and plucked-string synthesis; the generator scripts are not part of the game). No file was downloaded. They are judged here by waveform, spectrum and loudness (about -18 dB average, -5 dB peak, no DC offset), not by ear. If any track or sound doesn't sit right, the ids and file names are stable, so a replacement drops straight in.
- The lighting lab's Sun azimuth does not move the painted sun glow and disc (SkyGlow), which keep their per-world direction.
- The first time a monster type appears, the renderer compiles its shaders, which can cause a one-time hitch. Steady state measured at 60 fps.
- Enemies no longer block console moves (orbit arms, slide platforms): with hundreds of enemies a crab in the sweep could lock a puzzle for good. Players, cargo and the head still block a move, and a swinging part shoves enemies aside.
- Lighting lab saves now keep the `uid=` of every external reference too, not only the header; a no-op save leaves the files byte-identical. The first run after a save recompiles the shaders of the changed materials and can take a few seconds to show the first frame.
- Fixed while adding enemies: the per-world `kill_plane_y` values (-40 / -60 / -70) had been reset to the script default by an editor script reload; they are restored. The key-name lookup no longer calls the keyboard-layout API on the editor-embedded display server, which errored on every dialogue line.
- The music is 32 kHz stereo WAV with QOA compression on import (about 24 MB in the repository). OGG was not used because this machine's ffmpeg has only the experimental Vorbis encoder.

Evidence: `docs/evidence/v2-arena-paint.png`, `v2-hit-flash-and-fall.png`, `v2-thrown-head.png`, `v2-socket-pocket.png`, `v2-lighting-lab.png`, `v2-soft-sfx-waveforms.png`, `v2-music-spectrograms.png`.
