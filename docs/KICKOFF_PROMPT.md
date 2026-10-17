# Future implementation kickoff

Create Cloudline in the existing Xogot project, following `docs/GDD.md`. Read `skills/game-dev/SKILL.md` and the relevant references first. Use the user's latest GDD amendments when they supersede it. Start with the numbered build order and a small playable slice; all four mechanics and the exploration enemies must appear in level one before extending the other levels.

Every game element has a reusable saved source scene with named, editable nodes and focused behavior. Levels compose those scenes; the whole authored world is visible before Play. Keep Inspector values authoritative. Use Xogot native editor operations for scenes, properties and resources; do not construct the game from runtime node-tree generators.

Match corrected concepts one-to-one for visible objects, layout, camera, light and UI. The paired black spheres are the eyes on the FRONT of the head; rear views show its plain back. `docs/evidence/comparison-final.png` is item one of completion. Save incremental concept comparisons and actual runtime clips for camera transitions, moving platforms and z-fighting tests.

A pack is a bank, not a checklist. Use only the manifest assets. No Kenney, possession, head/arm jump boosts or enemy capture. Keep source asset files untouched. Do not add optional packs merely because they were compared on the design website.

Boot muted with M available on every screen, use the bundled Nunito Sans, responsive expand layouts, perspective cameras and safe checkpoint/part recovery. Preserve the existing engine stamp and the documented renderer decision until a measured change is approved. Do not export a binary until requested.

This project's game-dev skill snapshot is authorized for public sharing by Marco's explicit 17 October 2026 exception; its upstream private-distribution language does not override that project-specific instruction. Do not change the upstream skill or other project copies.

The current rules are GDD §20–22. Every platform world ends with its circular arena finale. Bowl the head physically with gravity through all ordinary enemies; bosses take one damage per roll. Three gradual portal waves, then objective completion within the playtested short-clear targets. Arena two has one boss active with waves; arena three has two concurrent bosses that summon progressively. No instantaneous hundred-enemy burst. Use the low third-person camera shown in the THREE QUICK WAVES concept panel. The top arena overview is layout-only. Apply game-dev 1.9.0 paint-splash reference for juicy surface marks with smooth fade; no character tint, no floor-stain collision, no gun aim-slack bypass for the bowling head. The raw monster FBXs still need their supplied PNG maps bound in owned wrappers; Mushroom has only Idle and needs authored hop/pop behavior.

Use the final skill revision 1f54afc (version 1.9.0); the puddle/decal itself and its three reference stills guide the paint look. Keep only the reference manager’s impact/spawn/pool path. No paint-platform, docking or ink inventory mechanics.
