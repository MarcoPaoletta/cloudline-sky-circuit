# Asset manifest and coverage

Source evidence checked 17 October 2026. No Kenney assets. Do not infer implemented mechanics from a model name. Packs are banks, not feature checklists; unused models are spare stock.

## Required free sources

| Source | Exact free pack | Rights evidence | Use |
| --- | --- | --- | --- |
| Quaternius | [LowPoly Robot](https://quaternius.itch.io/lowpoly-robot) | Bundled CC0 text; current creator terms allow commercial games/videos | Robot, detachable visuals, existing 14 clips |
| Quaternius | [Ultimate Platformer Pack](https://quaternius.itch.io/ultimate-platformer-pack) | Bundled CC0 text; current creator terms allow commercial games/videos | Environment, props, two enemies and their clips |
| Juhani Junkala / SubspaceAudio | [512 Sound Effects](https://opengameart.org/content/512-sound-effects-8-bit-style) | Creator page CC0; downloaded archive info retained | Existing six movement/pickup/confirmation sounds; further selection from archive |
| Google Fonts / Nunito Sans authors | [Nunito Sans](https://fonts.google.com/specimen/Nunito+Sans) | SIL OFL beside downloaded variable TTF | All game UI and website typography |

[Quaternius's current terms](https://quaternius.com/license.html) permit games, artwork and videos, including commercial use, and restrict standalone redistribution of the asset files. Raw model packs stay local and linked to their creator; public documentation includes renders, source paths, inventories and checksums. Bundled historical CC0 evidence is preserved, alongside the current terms; this package does not try to resolve the licensing discrepancy by replacing either text.

## Exact game paths

All paths below begin `res://assets/cloudline/`. Archive root is `Ultimate Platformer Pack - Dec 2021/`; glTF members add `glTF/` inside each category. The original archive is local at `cloudline-platformer/downloads/platformer.zip`, excluded from public GitHub.

| Need | Exact project file(s) | Supplied content | Remaining authored work |
| --- | --- | --- | --- |
| Player and head | robot/Robot.fbx | 14 clips; unskinned Head2/Head2; separate limbs; skinned hands | Player wrapper, head flight/seat states, throw/recall gestures and visual swap |
| Grass surfaces | platformer/Cubes/Cube_Grass_Single.gltf | Real mesh | Modular island wrapper, simple colliders, safe landings |
| Floating rock bodies | platformer/Nature/RockPlatforms_Medium.gltf; RockPlatforms_Large.gltf | Real meshes | Layout, authored scale, collision kept separate |
| Clouds | platformer/Nature/Cloud_1.gltf; Cloud_2.gltf; Cloud_3.gltf | Real meshes | Placement below routes; no gameplay collider |
| Dressing | platformer/Nature/Bush.gltf; Rock_1.gltf; Grass_1.gltf | Real meshes | Edge clusters and simple family collision where needed |
| Small bridges | platformer/Level and Mechanics/Bridge_Small.gltf | Real mesh | Powered wrapper/collision/state |
| Long bridges | platformer/Level and Mechanics/Bridge_Modular.gltf; Bridge_Modular_Center.gltf | Exact archive models | Modular spans with measured joins and collision |
| Rails | platformer/Level and Mechanics/Fence_1.gltf; Fence_Corner.gltf; Fence_Middle.gltf | Exact archive models | Safety rail composition and colliders |
| Steps and lift silhouette | platformer/Level and Mechanics/Stairs_Small.gltf; Tower.gltf | Exact archive models | Compose stairs; use Tower only where suitable; moving lift uses grass slab and authored support primitives |
| Receiver / launch pad | platformer/Level and Mechanics/Bouncer.gltf | Bouncer_Bounce and Bouncer_Idle clips | Distinct socket receiver vs spring pad variants; material/icon/effect changes; triggers |
| Ground console | platformer/Level and Mechanics/Lever.gltf; Arrow.gltf; Arrow_Up.gltf | Lever_On and Lever_Off; arrow meshes | Ground base, Left/Right signs and camera/group control |
| Gates | platformer/Level and Mechanics/Door.gltf | 2 mesh parts | Safe open/close behavior and collision |
| Counterweight cargo | platformer/Cubes/Cube_Crate.gltf | Real crate mesh | Cargo wrapper, lane, tray, tilt pivot and latch |
| Coins and special treasure | platformer/Powerups and Pickups/Coin.gltf; Gem_Blue.gltf | Real meshes | Collect-once, arm fetch, optional IDs and feedback |
| Finish | platformer/Level and Mechanics/Goal_Flag.gltf | Real flag mesh | Capture area, celebration, progress and results |
| Goal beam and checkpoints | Authored mesh/material effects | Engine primitives, no extra pack | Golden beam, diamond/edge marker, low checkpoint beacon |
| Head and arm feedback | Derived visuals from robot plus native effects | Existing head/arm meshes | Saved tether, trail, impact and attach scenes; skin extraction |
| Crab ground enemy | platformer/Enemies/Crab.gltf | Bite_Front, Bite_InPlace, Dance, Death, HitRecieve, Idle, Jump, No, Walk, Yes | Patrol/edge guard, wind-up, hit receiver, reward and reset |
| Bee air enemy | platformer/Enemies/Bee.gltf | Bite_Front, Death, Flying, HitRecieve | Bounded hover/dive path, wind-up, hit receiver, reward and reset |
| Typography | fonts/NunitoSans-Variable.ttf; OFL.txt | Real downloaded font and license | Theme/font coverage and in-menu screenshot comparison of weights/sizes |

## Existing audio files

`audio/Jumping and Landing/sfx_movement_jump1.wav`, `audio/Jumping and Landing/sfx_movement_jump10_landing.wav`, `audio/Coins/sfx_coin_single1.wav`, `audio/Positive Sounds/sfx_sounds_powerup1.wav`, `audio/Footsteps/sfx_movement_footsteps1a.wav`, `audio/Menu Sounds/sfx_menu_select1.wav` are the six previously imported cues. Treat them as initial placeholders for selection/tuning; exact final bus/volume and action assignment still need authoring. Inspect the original `audio-archive-files.json` if a category path differs in a later import.

## Import evidence and limits

The existing robot/core meshes and first six optional props were previously instantiated in Xogot. New support import records and the final load report live in `research/`. For Bee and Crab, animation names were also read directly from each glTF's `animations[]` array, not inferred from the pack's marketing. Imported geometry is not proof of working AI, collisions, audio timing or gameplay.

The support set adds eight bridge/rail/vertical-dressing models, the two chosen enemies and Nunito Sans. No new paid pack is needed for the scoped game. Do not import the comparison candidates into the production game by default.

## Enemy options considered

| Option | Creator source | Evidence | Decision |
| --- | --- | --- | --- |
| Platformer Crab + Bee | Ultimate Platformer Pack link above | Exact archive members and animation arrays inspected | Selected. Closest geometric/material match and both ground/air silhouettes |
| Cute Animated Monsters | https://quaternius.com/packs/cutemonsters.html | Creator page: 21 animated textured monsters, free commercial use, CC0 badge | Selected expansion for the arena pool: Cactus, Mushroom, Alien, Cyclops and Yeti imported from the creator’s free OpenGameArt archive. See verified clips below. |
| Animated Mech Pack | https://quaternius.com/packs/animatedmech.html | Creator page: 4 animated textured mechs, free commercial use, CC0 badge | Visual alternative. Mechanical theme fits, weathering/proportions less coherent |

The site's comparison images are AI art-direction mockups in the same environment, not runtime renders of those candidate assets. Creator preview images served only as generation references. Exact imported enemy appearance is represented by the selected pack files and must be checked in the first authored encounter before final art acceptance.

## Arena pool expansion, revision 1.2

The same [Cute Animated Monsters pack](https://quaternius.com/packs/cutemonsters.html) is now selected for a limited arena roster, superseding its earlier comparison-only status. Its official Drive mirror hit quota limits; Quaternius’s own [OpenGameArt upload](https://opengameart.org/content/textured-cute-monster-pack) supplied the ZIP. SHA256 `844824c04936a9af954ee82011f98ad8c14ba291a20a0dd0b83c172764ba0eb2`. Twenty-one models are available in the archive; five selected FBXs and their five original PNG maps are imported. Mechs remain comparison-only.

| Role | Exact imported file | Verified animation clips | Custom integration still required |
| --- | --- | --- | --- |
| Cactus horde | res://assets/cloudline/monsters/FBX/Cactus.fbx | MonsterArmature prefix: Bite_Front, Bite_InPlace, Dance, Death, HitRecieve, Idle, Jump, No, Walk, Yes | Wrapper/material map, crowd behavior, hit/paint event |
| Mushroom horde | res://assets/cloudline/monsters/FBX/Mushroom.fbx | MonsterArmature prefix: Idle only | Authored hop/squash locomotion and pop defeat; no supplied walk/death clip claimed |
| Alien horde | res://assets/cloudline/monsters/FBX/Alien.fbx | Same 10 clips as Cactus; 2 meshes | Wrapper/material maps, crowd behavior, hit/paint event |
| Cyclops horde | res://assets/cloudline/monsters/FBX/Cyclops.fbx | Same 10 clips as Cactus | Wrapper/material map, crowd behavior, hit/paint event |
| Yeti boss | res://assets/cloudline/monsters/FBX/Yeti.fbx | Same 10 clips as Cactus | Owned larger visual/collider, custom summon/stomp gestures, boss health and spawn behavior |

The matching maps are `res://assets/cloudline/monsters/Textures/{Cactus,Mushroom,Alien,Cyclops,Yeti}_Texture.png`. The source FBXs load with meshes and clips, but the current material inspection found no connected albedo textures. Bind these supplied maps in the owned material/wrapper scenes during implementation; do not call the raw FBXs texture-ready. The texture sources are present, so this is material setup, not a missing paid asset. Exact original members, hashes and Xogot inspection are in `research/cute-monsters-selected.json` and `research/xogot-monster-pool-load-check.json`.

New custom visuals: circular arena floor and six portal arches/rings per arena, summon rings, wave HUD, boss bars, bowling-head animation, surface paint, hit effects and transition layer. Use saved editor-authored scenes, existing grass/rock/fence meshes and engine-native ring/mesh materials. Portals are explicitly authored work, not a nonexistent downloaded portal prefab.

The updated skill supplies six `splat_0.png` through `splat_5.png` plus `splat_orm.png`, copied into `res://assets/cloudline/paint/`. Reference shaders/scripts/scenes stay under the skill with `.gdignore` in code folders; they need adaptation and proper editor authoring to become game effects. The module's referenced wet-pop WAVs are not included. Select/create the three wet sound variants as a remaining audio task; no ready-made wet-sound claim is made.

Final update: the complete 21-model FBX library and original texture folder from the same creator ZIP are imported under `res://assets/cloudline/monsters/`. The active roster still uses the selected five plus exploration Crab/Bee. `research/monster-bank-manifest.json` inventories the complete bank. The newest skill snapshot is 1f54afc (1.9.0), including actual puddle/decal scenes, manager, styles/materials and three reference stills; read GDD §22 before integration. The source templates are reference-only and are not asserted to be drop-in runnable at their snapshot paths.
