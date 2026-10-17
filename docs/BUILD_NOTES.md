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
