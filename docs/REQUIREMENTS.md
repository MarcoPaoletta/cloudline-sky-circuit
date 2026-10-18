# Request coverage

| User request | Design response / evidence |
| --- | --- |
| Three levels, growing larger | GDD §9: 28 / 42 / 60 walkable platforms, expanding footprint, height and loop structure |
| All selected mechanics from level one | GDD §9 discovery circuit: head relay/combat, fetch arm, counterweight and ground console |
| Ground object changes camera smoothly | GDD §8: automatic grounded entry, 0.65 s perspective blend, saved overview pose |
| Simple Left/Right puzzle controls | GDD §8: one group / axis per console, four orbit or three slide states, E/Escape exit |
| Bottom-center robot dialogue | GDD §12 and DIALOGUE.md: portrait panel, event triggers, two-press typewriter behavior |
| Many platforms, bridges, branching paths | GDD §9: explicit per-level sector budgets and connected route graphs |
| Vertical and horizontal movement, jump pads | GDD §4 and §10: numeric metrics, safe landings, lift/shuttle/pad contracts |
| Flag goal, yellow ray marker | GDD §3 and §12: capture area, results flow, tall golden beacon and edge indicator |
| Enemies and head attack | GDD §5 and §11: returning head projectile, selected Crab/Bee, health and readable wind-ups |
| Different enemy visual options and a decision | Three comparable concept scenes plus ASSET-MANIFEST option table; platformer enemies selected |
| Fix backwards eyes | GDD §1 orientation contract; all ten initial images corrected, head-relay extra-head defect repaired |
| Roughly ten concept images | Twenty-one final images including arenas, bowling, paint and circular overview |
| Missing assets free, YouTube-safe, no Kenney | ASSET-MANIFEST.md and creator source links; downloaded Nunito Sans + OFL; same pack support models/enemies |
| New public website | Native Sites publishing with a new project ID and public access |
| docs folder in Xogot project, GDD Markdown | res://docs/GDD.md with supporting documents/concepts copied through xo |
| Pull latest skill, read it and import it | Fresh clone + pull at 1f54afc, skill 1.9.0; whole snapshot under res://skills/game-dev/ |
| Exception to skill privacy, publish it | Explicit project-only authorization recorded in skills/README.md; skill included in public design repository |

No gameplay, binary export or runtime performance result is claimed. This delivery is a design/reference package and imported support assets.

Latest additions: GDD §20–21 covers platforming first on every level; flag-to-arena fades; three gradual waves each; arena two has one summoning boss and arena three has two concurrent summoning bosses; 35–45 / 45–55 / 55–65 second clear targets; one circular platform with six rim portals; bowling head kills every ordinary enemy it touches; bounded layered juice and fading surface paint; behind-player camera matched to THREE QUICK WAVES; top overview is layout-only. Full updated skill and paint source masks are imported and shared under the explicit exception.

Final refresh: GDD §22 follows the second skill update at 1f54afc. All 21 monster models and their texture maps are imported as an asset bank. Arena overview shows exactly six rim portals and remains a planning view.

## As built (implementation coverage)

| Request | Where it lives in the game |
| --- | --- |
| Three levels, growing larger | `res://scenes/levels/level_1.tscn` (28 islands), `level_2.tscn` (42), `level_3.tscn` (60); route tests in BUILD_NOTES |
| All selected mechanics from level one | Level one has the relay bridge, crab and bee, fetch arm and crate, counterweight island, orbit and slide consoles, lifts, shuttle and pad |
| Ground object changes camera smoothly | `ground_console.tscn`: 0.35 s settle, 0.65 s eased perspective blend to the saved overview pose, reduced-motion 0.15 s |
| Simple Left/Right puzzle controls | One group per console; Left/Right step, E or Esc exit, endpoint and occupied rejections |
| Bottom-center robot dialogue | `dialogue_panel.tscn` with live robot portrait, two-press typewriter, queue priorities, hint log in the pause menu |
| Many platforms, bridges, branching paths | Per-level graphs in GDD §9 realised as saved scenes; world two has three routes, world three three rings plus two final lanes |
| Vertical and horizontal movement, jump pads | `vertical_lift`, `horizontal_shuttle`, `jump_pad` scenes (14 m/s launch), ramp and flat bridge scenes |
| Flag goal, yellow ray marker | `finish_flag.tscn` with the golden beam, HUD diamond marker with edge arrow |
| Enemies and head attack | Crab and bee on the platforms, four horde monsters and the Yeti in the arenas, bowling head with deduplicated hits |
| Bright toon look matched to the concepts | Toon materials through glTF import remaps, tapered faceted rocks, cloud sea, sunrise glow; see the comparison images in `docs/evidence/` |
| Music: title, worlds and arenas each have their own track (v2) | Three original seamless loops on a Music bus with crossfades (`Audio.play_music`), Music volume in Settings |
| Relaxing sound effects (v2) | 51 soft one-shots in `assets/cloudline/audio/soft/`, preferred over the pack sounds |
| 5 to 20 enemies on every platform by its size (v2) | 278 / 481 / 680 crabs and bees per world; far ones sleep, crabs never clip through each other |
| At least 3 head sockets per world (v2) | Each world has 3, each powering a bridge or door; new ones open coin pockets |
| Hit feedback: white flash, falling back instead of squashing (v2) | 0.07 s white overlay plus hit stop; bowled-over knock-back fall |
| Paint visible on arena floors (v2) | Flat splat quads on flat ground (Mobile decal limit), 16 s arena hold |
| Sprint with Shift (v2) | `sprint` action, 9.5 m/s, remappable |
| Dev tools: fly, go to flag, complete arena, lighting lab (v2) | F1 panel buttons; F2 lab with concept beside live game and Save to project |
