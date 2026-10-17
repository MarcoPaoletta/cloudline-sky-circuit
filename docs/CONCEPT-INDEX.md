# Concept index

Twenty-one final concept illustrations generated with the built-in image-generation tool. They are design targets and comparison mockups, not runtime screenshots or supplied model files. Full original PNGs are in `concepts/`; optimized WebP copies serve the website. The initial ten were edited to correct the robot's eye orientation. The head-relay image received a further correction to keep the body headless. Rejected drafts remain local QA only.

| Image | Purpose | What to preserve in the build |
| --- | --- | --- |
| [01 Cloudline key art](concepts/01-cloudline-key-art.png) | Opening vista | Branches, layered heights, sky space, wooden bridge rhythm, one summit beacon |
| [02 Sunrise Junction](concepts/02-level-1-sunrise-junction.png) | Level 1 target | Compact four-tool discovery foreground with low/high route choices beyond |
| [03 Cargo Gardens](concepts/03-level-2-cargo-gardens.png) | Level 2 target | Cargo hub, long bridge crossings and separated lift terraces |
| [04 Crown Circuit](concepts/04-level-3-crown-circuit.png) | Level 3 target | Broad ring structure, central crown landmark and expanded vertical movement |
| [05 Head Relay](concepts/05-head-relay.png) | Tool target | One detached head on receiver, headless body, powered bridge |
| [06 Fetch Arm](concepts/06-fetch-arm.png) | Tool target | Grounded body, one detached forearm/hand, thin tether and distant treasure |
| [07 Counterweight Island](concepts/07-counterweight-island.png) | Tool target | Gentle tilt, clear pivot, cargo influencing exit alignment |
| [08 Orbit Console](concepts/08-orbit-console.png) | Camera / tool target | Robot on stationary pad, perspective overview, grouped route and Left/Right/E strip |
| [09 Vertical Traversal](concepts/09-vertical-traversal.png) | Movement target | Broad pad landing, horizontal shuttle, vertical lift and continued flag visibility |
| [10 Dialogue and Wayfinding](concepts/10-dialogue-and-wayfinding.png) | UI target | Bottom-center portrait panel, legible short text, restrained HUD and goal beam |
| [11 Platformer enemies](concepts/11-enemies-platformer-choice.png) | Selected enemy art direction | Crab/bee scale, playful forms and returning head attack, not possession |
| [12 Cute Monsters alternative](concepts/12-enemies-cute-monsters-option.png) | Comparison, not production target | Evaluate rounded textured cactus/mushroom in the same scene language |
| [13 Mechs alternative](concepts/13-enemies-mechs-option.png) | Comparison, not production target | Evaluate weathered mech detail/proportions in the bright platformer environment |

The selected enemy concept approximates the source Crab/Bee; it is not a model render. The exact downloadable meshes and clips are verified separately. Mechanical support housings, beam, rings, rail details, tether and UI shown in artwork require authored wrapper/effect scenes using existing models and simple engine geometry. No unsupported claim that a concept's every polygon is already a prefab.

## Generation record

- `research/concept-prompts.json`: ten original prompts, actual robot and assembled pack renders as references.
- `research/concept-corrections.json`: paired-eye/front-facing correction applied to all ten; localized headless-body correction for image 05.
- `research/enemy-concept-prompts.json`: three in-context enemy option prompts, with corrected character/world and creator preview references where applicable.
- Built-in image generation was used; no external image-generation CLI or API key was used.

## Arena, animation and paint additions

| Image | Purpose | Build contract |
| --- | --- | --- |
| [14 Opening Burst](concepts/14-arena-1-opening-burst.png) | Arena 1 gameplay target | Third-person behind player, circular ground, gradual portal waves, no boss |
| [15 The Summoner](concepts/15-arena-2-summoner.png) | Arena 2 gameplay target | Same camera, three waves and one active summoning Yeti |
| [16 Twin Paintstorm](concepts/16-arena-3-twin-paintstorm.png) | Arena 3 gameplay target | Same camera, two concurrent summoning bosses during waves |
| [17 Bowling study](concepts/17-bowling-animation-study.png) | Authored animation beats | Grab, lift, low underarm roll and recall; one head per pose |
| [18 Monster library](concepts/18-monster-library.png) | In-context cast | Four regular horde shapes plus Yeti, Crab and Bee, scale in the environment |
| [19 Paint impact and fade](concepts/19-paint-impact-and-fade.png) | Effect target | Impact burst, wet surface splash, pop and smooth fade from game-dev 1.9.0 |
| [20 Flag to arena](concepts/20-flag-to-arena-flow.png) | Transition and camera target | Right-hand THREE QUICK WAVES panel is the approved behind-player camera reference |
| [21 Circular arena overview](concepts/21-circular-arena-overview.png) | Layout-only high view | One giant circle, six edge portals and clear lanes; not an interactive camera mode |

Arena camera corrections use the THREE QUICK WAVES panel as the framing reference. Arena 2 no longer depicts an arm blaster; it uses the bowling head. Read `research/arena-concept-prompts.json` and `research/final-image-prompts.json` for the additions and correction prompts. Arena scale/crowd appearance in a concept is not an FPS or simultaneous-enemy-count guarantee.
