# Cloudline: The Sky Circuit

Game Design Document 1.3 · 17 October 2026 · Design and preproduction package

**Current authority:** Section 22 is the final paint-puddle/skill update. Section 21 governs the updated paint module, circular arena layout and camera. Section 20 governs the bowling head, waves, bosses and world-to-arena flow. Together they supersede the single-hit head projectile, flag-to-results ending, two-enemy roster and no-boss cut in sections 3, 5, 11 and 18. Earlier sections remain as revision history; follow sections 20–22 wherever rules differ.

**Pitch:** A little yellow robot takes itself apart to reconnect a broken sky. Launch your head to power routes or bonk enemies, fetch distant treasures with an arm, balance floating islands with cargo, and step onto ground consoles to rearrange the path to a distant flag.

**Deliverable status:** This document specifies a game to build. Imported assets and inspected animation clips exist; the gameplay, levels, dialogue, effects and custom animations described here are not implemented yet. All numbers below are initial design targets to tune in playtests, not measured game results. The concepts are visual targets, not screenshots.

## 1. Visual contract and the one-to-one rule

When an image is selected as a build target, reproduce its visible layout, major island count, silhouettes, props, perspective, lighting, palette and UI element by element. Keep the same camera architecture across all three levels. Additional off-frame islands extend the world; they do not replace or reduce what is visible in the target frame. Use repeated instances of the real modular art to reproduce visible objects. Never replace a walkable level with a painted background.

Keep a saved perspective `ConceptCam` or `ConceptPose` for each target. After every visual milestone capture a 1920×1080 runtime frame, compare it beside the concept, save numbered comparisons, fix the largest mismatch and repeat. `docs/evidence/comparison-final.png` is the first game completion gate. The current package has no runtime comparisons because it is a design delivery.

**Character orientation is mandatory:** the two black spheres are the robot's eyes. They are a paired set on the FRONT of the head, aligned with the chest and toes. The back of the head has no eyes. Rear gameplay views show its plain yellow back. They are never drawn as side ear cups. On detached-head attacks the eyes point along the attack. Corrected concepts supersede the initial orientation-error drafts.

Reference images and their intended use are indexed in [CONCEPT-INDEX.md](CONCEPT-INDEX.md). The opening vista and the three level frames guide art placement; the level graphs in section 9 specify connections and off-frame content. A concept may show a partial view of a full level. If geometry or a drawn connection conflicts with the solvability specification, resolve the discrepancy in a documented visual revision before building that area.

## 2. Product scope and design pillars

Three levels are enough for a substantial course-sized game if the same mechanics support new decisions. Target a first clear of approximately 40–60 minutes across the three levels, plus optional collecting and replay. That is a pacing hypothesis, not a promise.

- **A robot with useful detachable parts.** The head is one physical commitment: remote power or a short combat shot. The arm reaches out while the body remains grounded.
- **An archipelago, not a corridor.** Each level has visible branching routes, reconnecting loops, optional pockets, shortcuts and multiple height bands.
- **World manipulation with two directions.** A ground console changes the perspective and gives Left/Right control over one authored platform group.
- **All the toys in level one.** Every signature mechanic and both enemy types appear in the opening level. Later levels increase combination, route scale and decision complexity, rather than withholding mechanics.
- **Readable spectacle.** Moving platforms, clear silhouettes, bridges, a yellow goal beacon and immediate feedback create a rich first impression without obscuring landings.

Single player, third-person 3D, desktop keyboard and mouse first. Xogot on Mac is the authoring environment; preserve the existing Godot 4.7 project stamp. Controller support is planned as a mapped equivalent. Mobile touch, multiplayer, procedural worlds, bosses, skill trees, possession, mid-air part stepping stones and throw-granted jump boosts are outside this build.

## 3. Core loop and player motivation

Spot the flag beacon, inspect two or more routes, change a local route with the robot's tools, cross it, claim optional treasure, activate a safe checkpoint, and reach the flag. Enemies add short movement and timing decisions within that loop; the game is not an arena shooter.

Each level has one real finish flag. Grounded contact inside its 2 m capture area for 0.4 s begins a 1.2 s capture celebration, returns detached parts, banks the level result and opens Continue / Explore / Replay. The final level continues to a campaign-complete screen. Coins and gems are optional and never gate the flag or later levels. No mandatory kill quotas.

Coins reward routes and quick fetching. Blue gems reward side puzzles: 3 in level one, 4 in level two, 5 in level three. Completion records flag status, best clear time and collected IDs. There is no shop or upgrade economy in scope. A persistent shortcut should visibly change the world when opened.

## 4. Inputs and movement metrics

Use remappable InputMap actions with physical key bindings. Show context-aware prompts, never all bindings at once.

| Context | Action | Initial binding | Rule |
| --- | --- | --- | --- |
| Explore | Move | W A S D | Camera-relative; no tank steering |
| Explore | Look | Mouse | Free look; Escape releases capture through pause |
| Explore | Jump | Space | One jump; coyote time and buffer |
| Explore | Aim assist | Right mouse hold / toggle option | Highlight one valid target; release does not fire |
| Explore | Head deploy / recall | Q | Receiver target deploys; if already seated, recalls |
| Explore | Head combat shot | Left mouse | Fire forward / at locked enemy only while head attached |
| Explore | Fetch / cancel | F | Launch arm to valid target, second press cancels |
| Safe interactions | Interact / dialogue | E | Dialogue has priority; a pad enters automatically |
| Console | Step group left / right | Left / Right arrows | One press, one preset; no other manipulation axis |
| Console | Exit | E or Escape | Returns camera; Escape is consumed before pause |
| Global | Pause / resume | Escape | Only after any modal interaction is closed |
| Global | Mute | M | Available on every screen and while paused |
| Development | Recording tools | F1 | Hidden at boot, absent from release UI |

Initial metrics: 1 Godot unit = 1 m. Robot collision height 1.6 m, radius 0.35 m, physics body scale 1.0. Calibrate the imported visual in a wrapper to the approved size without modifying vendor source assets. Normal run speed 6 m/s; acceleration 24 m/s²; air control 60%; coyote time 0.12 s; jump buffer 0.12 s. Jump launch 8.5 m/s with 20 m/s² gravity gives about 1.81 m peak height and 5.1 m ideal same-height range. Mandatory unassisted gaps stay at or below 3.5 m, with landings at least 4 m wide. Validate actual collision and player control before multiplying level content.

Standard island tops are approximately 8×8 m; hub assemblies 12–18 m wide; narrow optional landings at least 4×4 m. Walkable bridges at least 2.4 m wide. Place a broad landing beyond each camera change or jump pad. A jump pad launches at 14 m/s, about 4.9 m ideal rise; authored landing rises stay below 4 m. Use lifts for larger vertical changes. Normal slopes stay below the controller's tested floor angle.

## 5. Head Relay and head-shot combat

### The head's two jobs

The same head is a remote power key and a returning projectile. It is never duplicated, never possesses an enemy, and never carries or boosts the player. The body keeps its normal movement and camera when headless. Combat shoots the head; it does not move the viewpoint into it.

Head states: attached, launching-to-receiver, seated, returning, combat-outbound, combat-returning. Only one state is active. Q with an attached head and valid receiver within 12 m of the body deploys it. A seated head powers exactly one receiver, connected to one gate, bridge or lift state. The receiver has a clear socket silhouette, distinct from jump pads and consoles. Q while seated recalls; losing power eases the connected mechanism back to its authored safe rest.

Left mouse fires only while attached, with an 0.18 s anticipation and an initial 18 m/s projectile speed, max outbound travel 10 m. The eyes face the shot direction. The first valid enemy impact deals 1 damage, then returns; a wall or missed shot also returns. Return is homing visual motion toward the neck, collision-free and never capable of damaging enemies. Max round trip target 1.3 s; 0.25 s recovery after reattachment. One accepted hit per launch, no piercing or return-path damage. A missed shot costs time, not ammunition or the head.

A head seated on a receiver cannot attack. Left mouse produces a small receiver pulse and the message “Recall your head first”; it never silently recalls and destroys the player's route. This makes the tradeoff readable. Do not put compulsory enemies on a crossing whose only safe state requires the head permanently seated. Provide a safe staging island, an alternate route, or a power latch activated only after the player reaches the far side.

### Feedback and animation

The supplied robot has a separate, unskinned head mesh at `RobotArmature/Skeleton3D/Head2/Head2`, attached through the Head bone. It has 14 imported clips, but no reach/grab/throw/detach/recall clip. Author the arm reach, lift, release and reattachment gesture on the existing rig. Use a saved detached-head scene and hide the attached mesh during deployment; never hide the whole skeleton.

Anticipation hand reach → neck release flash → short head trail → socket/impact ring → head return → small reattachment bob. Invalid targets give a hollow click and brief amber outline. Combat impact uses a 0.07 s enemy flash, small star particles, short recoil and synchronized sound, with optional tiny camera impulse. Do not freeze player input for the whole animation. Locomotion remains responsive; authored contact timing controls head release. Default animation blends are 0.75 s, with contact-action blend-in 0.20–0.30 s and exported tuning values.

### Safety and acceptance

Recall is always available; never allow a permanently lost head. Fall, level reload, cancellation and transition restore exactly one attached head. A powered crossing may finish its current safe movement before resting; never withdraw collision beneath a player without warning. Provide a local reset and a reachable fallback island near every relay puzzle.

Pass when: a new player powers a bridge, crosses safely, recalls, hits each enemy type once, sees an invalid attack while seated, misses safely, and recovers after falling. Inspect a full launch contact sheet for duplicated heads, backwards eyes, visibility flicker and incorrect attachment scale. Head deployment never changes the jump arc.

## 6. Fetch Arm

F launches one forearm/hand toward a valid light collectible or cargo handle within 10 m and unobstructed line of sight. Max one target. Light coins and gems return directly, one item at a time, at an initial 12 m/s visual retrieval speed. Aim assist uses a small 12° cone; the highlighted target is exactly what will be fetched. The arm never grapples the player or provides an extra jump.

Heavy crates move only when the robot stands on an anchor tile. A valid heavy pull follows a visible authored cargo lane toward a marked receiving tray at 2 m/s. This avoids dragging crates through walls or arbitrary gaps. F again cancels. Walking off the anchor stops the crate at the nearest safe lane stop, returns the arm and gives feedback. Crates can also be pushed locally at walking pace. Do not allow arbitrary overhead carrying, stacking or throwing in this scope.

The fetched arm can work while the head is seated, enabling a relay-plus-cargo puzzle. Pause, dialogue and console transitions cancel an outbound arm safely before entering their mode. A returning arm cannot damage enemies. Fetching a creature is rejected; combat belongs to the head.

The forearm visuals are separate; the hands are skinned. Preserve the relevant rig or bake a rigid forearm-hand pose into a derived scene, leaving the original download untouched. Use a saved tether-effect scene, a collision/target query and a per-target collect-once contract. A pickup increments its collected ID exactly once even if the body touches it during retrieval.

Pass when: fetch one near and one far coin, a gem behind a clear sightline, reject a hidden target, pull a crate while anchored, cancel halfway and walk off the anchor. No pickup duplication or cargo loss; the body never moves because of the tether. Check arm facing, hand scale and the release frame visually.

## 7. Counterweight Islands

A balanced island is a kinematic puzzle, not an unconstrained physics raft. It tilts around one authored pivot axis. The player's position and one or two crates contribute weighted torque. Initial weights: player 1 unit, crate 1.5 units; tilt clamps to ±12°. Use a stable damped response, roughly 0.7 s to settle, with a 1° alignment tolerance. The camera horizon stays level.

Crates sit in two or three marked trays rather than freely sliding forever. Moving the robot to one edge changes the exit height; pulling a crate into a distant tray changes the balance persistently. An exit latch holds a solved alignment after the player reaches the safe exit island, with a visible clamp closing. The island remains tilted for a beat to show the cause, then may settle without trapping the player.

No enemies on the introductory balancing island; later enemies occupy safe approaches or exits, never force unavoidable knockback over a balancing edge. Use generous side lips or visible railings on required traversal. Falling crates reset to their authored tray after a warning pulse; R from the pause/reset UI resets the local puzzle and respawns the player on a safe nearby anchor.

Pass when: robot-only movement tilts in the expected direction, one crate reverses it, reaching the exit visibly latches a route, cargo reset recovers every state, and camera roll remains zero. Check a continuous movement clip for jitter, slipping collision and z-fighting around the pivot rim.

## 8. Ground consoles: Orbit and Slide

### Enter, manipulate, leave

The player steps onto a distinct ground pad with a lever motif and two arrow marks. After 0.35 s grounded near its center at low speed, the pad pulses and the game enters console mode automatically. A small settle delay prevents triggering while running across it. If a pickup dialogue is open, finish or dismiss it first; do not silently consume E for two actions.

Before entry, cancel/retract the arm and ensure the controlled group is at a valid rest pose. A smooth 0.65 s eased transition moves the existing perspective camera from gameplay framing to a saved overview pose. Keep the robot and complete controlled group in frame. Overview target: perspective FOV 32°, pitch around 50°, yaw around 45°, final pose individually authored for the puzzle. No orthographic projection and no sudden switch. Reduced-motion option uses a 0.15 s dissolve or a short transition chosen in settings.

Each console controls ONE group and ONE configured degree of freedom. Orbit consoles use four discrete 90° rotational states. Slide consoles use three discrete positions on a single horizontal OR vertical rail. Left/Right selects the adjacent authored state. No axis switching, object selection, Up/Down, mouse dragging or separate confirm action. Movement takes about 0.6–1.0 s with easing and a visible direction preview. One press queues at most one movement; inputs during travel give a busy pulse rather than stacking commands. At a slide endpoint, the rejected direction gives an endpoint tick.

The state commits when travel settles. E or Escape returns the camera over 0.65 s, restores exploration controls and keeps the selected arrangement. Holding E through entry does not instantly exit; require a new press. Suppress auto-entry until the robot leaves the pad radius, preventing immediate re-entry loops. The robot's last yaw is preserved; no surprise 180° control reversal.

### Occupancy and route safety

The player stands on a stationary safe hub, outside the moving group. No rotation/translation if a player, crate, deployed head or enemy occupies the affected platform or swept volume. Highlight the obstruction and state “Clear the platform first.” Do not crush or teleport occupants. Consoles are for arranging an empty route, then traversing it. Ambient moving platforms are separate systems.

A pad has a reset pedestal/menu command restoring the group's default state and a walkable path back to that pad in every reachable state. A solved route need not remain solved after reset, but the player is moved to the pad's safe reset anchor first. Restarting, pausing mid-transition, losing focus or changing level cannot leave the input locked, camera detached or platform between states.

Pass when: automatic entry works from all four approach directions, camera transition is smooth, Left/Right only manipulates the linked group, both rotational directions work, all three slide positions work, endpoints reject clearly, occupancy blocks movement, E/Escape exits, and no immediate re-entry occurs. Record the whole enter/step/exit sequence and inspect consecutive frames. Verify normal controls after pause, reset and focus loss.

## 9. Three-level progression and world structure

The proposed island counts include walkable fixed and moving landing platforms, excluding tiny decorative rocks/clouds. They are content budgets to validate in a small section before stamping out the full worlds. The initial target visible-concurrency budget is lower than the total count. No empty long travel stretches just to achieve dimensions.

| Level | Footprint / height span | Walkable islands | Bridges | Movers H / V | Balance islands | Consoles orbit / slide | Jump pads | Enemies total / active cap | First-clear target |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 Sunrise Junction | 150×120 m / 0–24 m | 28 | 8 | 2 / 1 | 1 | 1 / 1 | 2 | 6 / 3 | 10–14 min |
| 2 Cargo Gardens | 220×180 m / 0–40 m | 42 | 12 | 3 / 2 | 2 | 2 / 1 | 3 | 10 / 4 | 14–20 min |
| 3 Crown Circuit | 300×240 m / 0–60 m | 60 | 16 | 4 / 3 | 3 | 2 / 2 | 4 | 14 / 5 | 18–26 min |

Enemy types are the selected platformer Crab and Bee in all three levels. Difficulty rises through placement, overlapping decisions and route combinations, not faster surprise attacks or missing mechanics. All levels offer a safer long route and a shorter more technical route. Late shortcuts return toward earlier hubs, making the world a loop rather than a one-way chain.

### Level 1: Sunrise Junction

A safe opening viewpoint presents the finish beacon, a patrolling crab, a distant bee, moving lift, balancing island and rotating route within the first 10–15 s. The robot speaks while the player remains in control on safe ground. The guided first circuit aims for roughly 90–150 s on a first try, with all four signature tools and both enemy silhouettes visible in the first minute. This is a playtest target; do not rush a beginner to satisfy a timer.

Sector budget: Arrival 4 islands; Discovery Circuit 8; Junction 4; Low Loop 4; High Loop 4; Summit 4 = 28. Main-route heights: arrival 0 m, discovery 0–4 m, junction 6 m, low loop 4–10 m, high loop 10–18 m, summit 24 m. Split tall changes between lifts, pad landings and stairs. Do not ask a normal jump to climb an entire height band.

Opening encounters, in reachable order:

1. Arrival: one low-risk coin and the distant flag beacon; no modal tutorial wall.
2. Head Relay: throw Q to a socket on a neighboring island to power a short bridge. A safe landing on the far side supplies a visible latch before recall.
3. Head combat: after recall, one crab on a broad 12 m safe island shows its wind-up. A second overhead bee is visible but not attacking. Shoot once; a miss returns safely.
4. Fetch Arm: fetch a coin, then stand on an anchor and pull a crate along a short lane into the balance tray.
5. Counterweight: move to the marked far edge; player plus crate aligns a short exit. A safe exit latch prevents the route disappearing behind the player.
6. Console: step on a pad; camera glides up; one Left/Right step aligns the rotating bridge; E returns control. The branch hub opens immediately beyond.

From Junction, Low Loop crosses two wooden bridges, a horizontal shuttle and a broad bee encounter island. High Loop uses the vertical lift, a jump pad and a slide console to align a shortcut. Both rejoin Summit Approach, where a safe final lift reaches the flag. Optional side pockets contain 3 gems and 60 coins across the full level, not all clustered on the main path. A bridge shortcut loops Summit Approach back to Junction.

Graph: Arrival → Discovery Circuit → Junction; Junction → Low Loop → Summit Approach → Flag; Junction → High Loop → Summit Approach; Low Loop ↔ High Loop via a fixed return bridge; Summit Approach → Junction via an unlocked shortcut. Three checkpoints: Arrival, Junction, Summit Approach.

Acceptance: a first-time player completes all four introductory interactions, recognizes both enemy types, then can reach the flag by either branch. Both paths must work after resetting every optional puzzle. Show the beacon at Arrival, Junction and each branch's main decision point.

### Level 2: Cargo Gardens

Sector budget: Arrival 4, Cargo Hub 8, Low Canal 8, High Orchard 8, Console Terrace 6, Summit 8 = 42. The visual theme stays the same; denser crates, bridge spans and foliage edge clusters change rhythm without adding another asset style.

Graph: Arrival → Cargo Hub; Cargo Hub → Low Canal → Summit; Cargo Hub → High Orchard → Summit; Cargo Hub → Console Terrace → Summit; Low Canal ↔ Console Terrace; High Orchard → Cargo Hub via a one-way safe drop. Checkpoints at Arrival, Cargo Hub, Console Terrace, Summit Approach.

Low Canal is the long dependable route: retrieve one crate, balance an island, cross broad bridges, handle a crab/bee pair sequentially. High Orchard is shorter: use two staggered lifts and one jump pad, with a clear low-route bail-out. Console Terrace is the spatial route: rotate an empty bridge group, leave the pad, fetch a gem or cross the aligned route, then use a slide pad to position an empty lift bridge at the next stop. Do not require simultaneous console control and standing on its moving group.

One relay powers a cargo door while the body pulls a crate with its arm. The player then reaches a safe latch before recalling the head for a nearby encounter. This is the first deliberate head-power-versus-combat decision, with a visible safe retreat. Ten enemies across zones, no more than four active in the current local area; same two archetypes. 90 coins, 4 gems. Target heights 0–40 m across four broad terraces.

Acceptance: complete each of three major routes from a fresh checkpoint; recover a lost crate; recall the head without becoming stranded; reach the flag with zero optional gems; use a discovered shortcut to change route without restarting.

### Level 3: Crown Circuit

Sector budget: Arrival 6, Central Exchange 10, Low Ring 10, Mid Balance Ring 10, High Orbit Ring 10, Crown Approach 8, Flag Crown 6 = 60. The finish is a recognizable central crown visible over the entire level, with the flag beam extending well above the skyline. The player circulates around and above it rather than following a single ascent.

Graph: Arrival → Central Exchange; Exchange → Low Ring → Crown Approach; Exchange → Mid Balance Ring → Crown Approach; Exchange → High Orbit Ring → Crown Approach; Low Ring ↔ Mid Balance Ring; Mid Balance Ring ↔ High Orbit Ring; Crown Approach → Flag Crown; unlocked return lift connects Crown Approach back to Exchange. Five checkpoints: Arrival, Exchange, Low/Mid Link, High Ring Landing, Crown Approach.

Low Ring is the long bridge circuit with broad safe combat areas and cargo shortcuts. Mid Ring combines two balance puzzles with optional side routes; a third balance island serves a gem detour. High Ring chains an orbit console, a vertical lift, a second console and a bounce-pad landing. Every transfer has a recovery island and a view of the next landing.

Final approach offers a choice: power a broad bridge with the head and avoid enemies via the low lane, or keep the head for combat and take a moving-platform lane. Both converge on a safe staging island before the final ascent. Do not combine narrow platform riding, mandatory precision shooting, dialogue and camera switching at the same instant. Fourteen enemies total, max five active locally. 120 coins, 5 gems. Optional complete-collection loop crosses all three rings; the flag remains reachable by any main ring.

Acceptance: a complete path exists through every ring, inter-ring connectors actually reduce backtracking, beacon is visible or its edge marker is meaningful at all major decisions, no reset can delete the last route to a safe hub, and the busiest view meets the performance target.

## 10. Traversal systems, checkpoints and recovery

Horizontal shuttles and vertical lifts use authored stops and simple collision, initial speeds 2 m/s and 1.8 m/s. Pause 0.8 s at each stop. They carry the character through platform velocity; do not simulate attachment by endlessly reparenting the player. Required waits under 4 s; provide a nearby optional coin while waiting. A lift has a visible motion rail or arrow, clear landing and enough overhead clearance.

Jump pads are separate from head receivers and console pads: a spring/bouncer silhouette with an UP arrow, cyan segmented rim and a readable launch arc shown only on approach or in help. Head receivers have a small neck socket; console pads have lever plus Left/Right markings. Art shape, icon and motion distinguish these even without color. Pad triggers require a fresh grounded contact, not every overlap frame. Air steering remains available; landing zone is broad. No chained mandatory blind launches.

Checkpoints use a small low beacon with a diamond marker, visually distinct from the tall yellow flag beam. Activate once when grounded. On falling below a local kill plane, fade out in 0.2 s, reset parts and local unsafe cargo, respawn at the last safe checkpoint and fade in over 0.3 s. Restore 3 health. Keep banked collectibles and unlocked safe shortcuts; reset volatile enemy/combat and puzzle states to the checkpoint snapshot. A new-level Replay starts a fresh run with collectible visuals restored while preserving the campaign's best records separately.

Only the transition coordinator owns a screen fade. Repeated fall or reset requests cannot stack two fades. Preserve level ID and checkpoint ID on pause Restart Checkpoint. Restart Level explicitly clears that run's puzzle state. Erase Save is separate and requires a clear local confirmation.

## 11. Enemies and the style decision

**Selected: Crab and Bee from the existing Ultimate Platformer Pack.** They share the world's faceted geometry and cartoon scale, add a ground and air silhouette, and need no extra art pack. Exact source files and animation names are inventoried in [ASSET-MANIFEST.md](ASSET-MANIFEST.md). The alternatives on the site are visual comparisons, not an instruction to mix three packs.

Option B, Cute Animated Monsters, has charming rounded characters but stronger texture detail and monster styling than the environment; its bee or mushroom could work in a later visual revision. Option C, Animated Mech Pack, reinforces the robot theme but its weathered panels, proportions and visual density compete with this small bright platformer. Keep both as comparison candidates; neither is a required download or runtime dependency. The final choice is an art-direction judgment, not a claim about quality.

### Crab: readable ground guard

1 health. Patrol a short authored strip on a broad island at 1.6 m/s. Detect within 5 m with line of sight; move toward the player only while a tested floor exists at the projected next step. Stop at island boundaries. Wind-up 0.65 s, bite reach 1.2 m, one damage per accepted attack, recover 0.9 s. The provided clips include Idle, Walk, Bite_Front, Bite_InPlace, HitRecieve and Death. One head impact defeats it with its death animation, a short scale/fade finish and one coin reward ID.

### Bee: bounded air guard

1 health. Fly a short local loop 1.5–2 m above a broad landing island at 1.8 m/s; never camp a tiny landing, console or checkpoint. Detect within 6 m. Hover and show an amber wind-up for 0.8 s, make a 2.5 m straight dive toward the player's sampled safe-area position, then return over 1.0 s. Provided clips: Flying, Bite_Front, HitRecieve, Death. The path is bounded to its encounter volume. It never pursues the player through the whole level.

Both appear in level one's opening view and are fought individually before a later mixed encounter. Enemies do not manipulate consoles, pick up cargo or remove head receivers. No enemy attacks within 3 m of checkpoints, console pads or tutorial dialogue anchors. Leaving an encounter deactivates distant decision logic rather than spawning an unavoidable attack behind the camera.

Player health is 3 pips. Accepted contact removes one pip and gives 1.2 s invulnerability, a short readable flash and 0.5 m maximum controlled recoil directed toward safe ground, never a random shove into a pit. No knockback during console control or the tutorial balance step. At zero, use checkpoint recovery; no lives counter. Optional comfort assist removes damage recoil and adds aim assistance.

Acceptance: actual head launches defeat each type; one projectile cannot hit twice; returning head causes no damage; repeated overlap does not remove multiple pips; blocked edge patrol stops while the same enemy on a continuous floor moves. Check enemies after reset, reload, pause and a fall. A broad alternate route permits bypassing each non-tutorial encounter.

## 12. Dialogue, HUD and wayfinding

The robot speaks through a bottom-center UI, with its own front-facing portrait. No voiced actor or dialogue tree is required. The text is short, practical and lightly playful. Teach one action at a time; confirm success with a line rather than repeating the instruction indefinitely.

At 1920×1080 the initial dialogue panel is 960–1120 px wide, max 150 px high, 42 px above the bottom edge. Body text 30–34 px, minimum 24 px in smaller tested layouts; portrait about 86 px. Two text lines maximum, around 80 characters total before splitting. Nunito Sans is downloaded and bundled with its SIL OFL license; one family throughout the game, including pause and debug UI. Use responsive anchors and containers, not absolute layout alone. Test 1280×720, 1920×1080, 2560×1080 and 1280×1024 with `canvas_items` / `expand`.

A typewriter at 38 characters/s is optional and disableable. First E completes the current line; a separate new E advances. Never advance and fire another E action in the same frame. Auto-advance is optional; timed hints do not disappear before being readable. Queue priority: recovery/safety → active tutorial → objective reminder → flavor. Repeated hints require 20 s without progress, not every frame in a trigger. Completed tutorial events persist for that run; Replay can opt into full guidance again.

Normal hints are non-blocking on safe ground. Any instruction requiring attention pauses its local encounter and holds hostile attacks. Never obscure the destination during a moving-platform ride, a pad launch or a jump. Console instructions replace the dialogue area with a compact Left / Right / E strip, rather than stacking two panels.

Dialogue events and final lines are in [DIALOGUE.md](DIALOGUE.md). They trigger on semantic gameplay events: receiver powered, head returned, enemy defeated, collectible fetched, crate docked, balance latched, console entered, route aligned, checkpoint reached, flag captured. Public state getters allow tests without coupling to internal UI nodes.

### Goal marker

One tall, narrow golden ray rises 35–50 m above the current flag, with a subdued base ring and small diamond. Make it an authored emissive mesh/shader effect, not a real shadow-casting spotlight and not dependent on volumetric fog. Keep the flag mesh visible when near. The beam is visible from major route choices; the diamond becomes a restrained screen-edge arrow when its target is behind the camera or off-screen. Occlusion may dim the diamond, but it never points at the wrong height or world position. Optional distance appears only while holding the objective-help action, not permanently.

The beam names the destination, not a single mandatory route. Coins and bridges suggest local options. Route landmarks use distinct shapes: cargo stacks, tall lift rail, orbit ring and crown. Avoid a breadcrumb arrow that makes every branch feel wrong. The final beam fades during capture celebration; checkpoint markers stay much shorter and cyan/white.

Minimal HUD: coin count and three health pips top-left; small speaker + M top-right; temporary tool state beside the reticle while aiming; compact goal diamond only when useful. No permanent four-mechanic checklist after the first circuit. Pause includes Controls, Hint Log, Restart Checkpoint, Restart Level, Settings and Return to Title.

## 13. Art, camera, light and feedback direction

Bright modular low-poly sky world. Grass lime/green, warm ochre rocks, small deep-green shrub clusters, white faceted clouds, yellow robot, cyan machines, golden goal and red flag. Preserve opaque vendor material style. Use metallic/roughness response and restrained emission for new mechanical overlays; do not add high-detail weathered architecture to compensate for missing composition.

Normal perspective camera initial FOV 60°, follow distance 6.5 m, pivot 1.2 m above the body and a mild downward pitch. Keep the position follow rigid on the interpolated player transform. Smooth automatic rotation, FOV, spring distance and effects, not position lag. Use a spring collision arm and intermediate ArmEnd node. Gameplay camera has zero roll. Console cameras interpolate position, quaternion rotation and FOV between authored perspective poses. Save those poses; do not derive them from guessed coordinates on every entry.

The existing project is Mobile-rendered. Preserve it during this documentation task. For the implementation baseline, target the existing Mobile renderer on Xogot/Mac, one soft-shadow directional sun, procedural sky, mild distance fog and emissive mesh beacon; advanced volumetric fog/SSAO/glow depend on renderer support and must not be assumed. If desktop Forward+ is chosen later, document the measured visual/performance benefit and keep a tested Mobile-compatible presentation. No Windows D3D12 requirement is applied to this Mac project. Do not change the engine version stamp to chase an effect.

After corrected concepts are selected, [ART-TARGETS.md](ART-TARGETS.md) records sampled sky/grass colors and image brightness. Initial authored light candidates: sun elevation 35°, azimuth 135°, warm-neutral sun, cool cyan ambient, soft contact shadows; adjust to the selected concept. Exposure and fog must keep landings bright and legible. Use light fog to separate height bands; never conceal safe landings in cloud layers.

Every important action has anticipation, readable effect, synchronized sound and settlement. Coins pop and travel toward the HUD; head attach has a small bob; cargo docks with a tray light; a console step shows its new path; blocked actions visibly reject. Use restrained 2–4 px camera impulses for normal impacts at 1080p, setting-controlled. Do not apply combat hit-stop globally to moving platforms. Small sounds and particles are enough; constant huge shakes work against precise jumps.

Prevent duplicate coplanar faces on tiled grass, pad rims, bridge ends and UI markers. Test in motion from normal, low and console cameras. Fix geometry and authored separation first; render priority and blur are not general fixes. Required zero-flicker evidence is a clip or consecutive frames, not one still screenshot.

## 14. Audio and accessibility

Audio mode: complete short SFX set, optional ambient/music loop later. The six existing WAV effects cover placeholder movement, landing, pickup and confirmation; select and tune additional head launch, impact, reel, console movement and enemy cues from the same downloaded 512-SFX archive. A specific “perfect” throw sound is not claimed to exist. Final selection remains an audio task; no paid audio pack is required.

Every launch boots with the Master bus muted. M toggles on every screen and while paused; a speaker/M indicator explains it. Do not persist the mute state. Install this before any sound plays during development. Separate SFX, UI and optional ambience buses, limited simultaneous one-shots, no unbounded enemy loops. Keep all stream/effect players in authored reusable scenes.

Settings: remappable keys, mouse sensitivity, aim assist, hold/toggle aiming, text scale, instant text, reduced camera motion, reduced shake/flashes, separate audio levels and optional no-recoil assist. Shape/icon differences supplement color. No rapid flashing beacon, tiny timed subtitles, camera roll or mandatory rapid key presses. Controller mapping follows the same actions; mobile controls remain a later scope decision.

## 15. Asset plan and remaining custom work

Use the exact imported robot and environment packs. Additional required art consists of wrappers, simple authored mesh/material effects and gestures, not a missing purchased model. The [ASSET-MANIFEST.md](ASSET-MANIFEST.md) maps each need to a real archive member and project path. It distinguishes supplied meshes/animations, imported/load-checked resources, comparisons and work still to author.

Free creator sources: [LowPoly Robot](https://quaternius.itch.io/lowpoly-robot), [Ultimate Platformer Pack](https://quaternius.itch.io/ultimate-platformer-pack), [512 Sound Effects](https://opengameart.org/content/512-sound-effects-8-bit-style), [Nunito Sans](https://fonts.google.com/specimen/Nunito+Sans). These supply the scoped art. No Kenney assets, including skyboxes, are allowed; use the procedural sky and existing white clouds.

The downloaded model archives contain CC0 statements. Current [Quaternius terms](https://quaternius.com/license.html) permit free use in games, films and videos, including commercial products, while restricting standalone asset redistribution. Keep archive evidence and current creator links. Publish documentation, renders, concepts and our code; do not republish raw third-party model packs as standalone downloads. Nunito Sans is distributed with its SIL OFL text. Nothing in the design's MIT license overrides source-asset terms.

Custom production tasks: head projectile and receiver wrapper; skinned-arm visual extraction; reach/throw/recall clips; socket, anchor and console variants using existing base meshes; tether and signal effects; simple safe platform rails/pivots if not represented by selected props; collision and triggers; all puzzle logic; camera transitions; dialogue panels/HUD; enemy behavior/hurtboxes; beacon; checkpoints/save; menus; tested level composition. An animated model is not an implemented enemy.

A pack is a bank, not a checklist. Only manifest-listed art belongs in the authored game. Cannons, bombs, skulls, saws and other unused pack models stay spare stock, not missing features. Add a new pack only for a concrete uncovered need and after checking style and license.

## 16. Scene ownership and implementation handoff

The whole world exists as named editable nodes inside saved scenes before Play. Every game element has its own reusable source scene with focused behavior; levels compose instances. Terrain, routes, bridges, platforms, props, player, enemies, cameras, lighting and UI must be repositionable and resizable in the Inspector. Spawnable effects have saved source scenes. No gameplay node trees built by a monolithic runtime constructor or an @tool scene generator.

Use Xogot's native `xo` tools for authored scenes, nodes, properties and Godot file edits. Read the owning scene first, save and reopen to verify persistence, and validate through actual editor/runtime state. Keep imported sources as generated inputs and author gameplay in wrapper scenes. Do not install a second editor bridge for this Xogot project.

Proposed reusable elements: Player, DetachedHead, FetchArm, Receiver, PowerBridge, PowerGate, CargoCrate, AnchorTile, CounterweightIsland, GroundConsole, OrbitGroup, SlideGroup, HorizontalShuttle, VerticalLift, JumpPad, Coin, BlueGem, CrabEnemy, BeeEnemy, Checkpoint, FinishFlag, GoalBeacon, DialoguePanel, ToolPrompt, HUD, PauseMenu, TitleMenu, LevelResults, ScreenTransition and individual action effects. LevelOne/Two/Three compose them in named sector containers. These names are proposed new scenes, not files that already exist.

Own each state in one place: Player owns tool availability; the head owns its flight/seat state; each receiver owns its linked powered mechanism; each console owns one group; each level coordinates checkpoints and the flag. A small campaign state persists progress/settings; no universal inventory framework or global event bus is required. Communicate through focused APIs and signals. Export authored tuning parameters; never overwrite Inspector dimensions with hard-coded startup values.

Collision domains distinguish world, player, enemies, enemy hurts, head attack, pickups, puzzle triggers and cargo. A hit is accepted once by a hurt receiver, not once per collision callback. Defer unsafe collision changes outside overlap signals. Moving and rotating platforms use predictable kinematic behavior. Use collision primitives scaled through shape dimensions rather than non-unit physics-body transforms.

Development-only F1 panel: +100 coins, +1000 coins, select level, teleport to safe checkpoint, reset current puzzle, return both parts, invulnerability, progression unlock, 1×/2×/4× local test speed, Erase Save / Start Over with confirmation. Trigger normal feedback for debug grants. It is hidden at boot, themed and readable, excluded from the final release UI. No recording emails or collaborator invitations are sent by this package.

## 17. Build order and acceptance gates

Each numbered implementation milestone ends with a run, meaningful behavior check, inspected screenshot/clip and separate Git commit. Documentation delivery is not a passed milestone. Do not export a binary unless Marco asks.

1. Read project skill and GDD. Pin tool/editor versions, preserve Godot stamp, author boot mute, input, perspective camera, metric kit, title/pause/respawn loop and responsive theme. Test movement on one actual island.
2. Author reusable head, receiver and attack scenes plus Crab/Bee wrappers. Complete one powered bridge and one encounter of each type. Test returning head, hit deduplication and headless movement. Match the first target frame early.
3. Author Fetch Arm, collectibles, cargo lane and anchor. Test skin/rig representation, exactly-once collection, cancel/reset and simultaneous seated head plus arm use.
4. Author the counterweight island and a safe exit latch. Test weights, tilt clamps, cargo reset and collision while riding.
5. Author the ground console, Orbit/Slide group variants and perspective camera transitions. Test occupancy, pause/focus loss, input re-entry and reset in every state.
6. Complete the whole level-one discovery circuit with dialogue, both enemies, flag beam, horizontal/vertical movers, pads and two full branches. All signature mechanics are present before moving to content expansion.
7. Dress and tune level one, run fresh-player onboarding, match concept lighting/layout and inspect all screenshots. Only multiply content after this pass feels good.
8. Build level two from reusable scenes, complete all three routes and shortcut/reset tests. Add higher combinations with unchanged player abilities.
9. Build level three with all three rings, recovery paths and worst-case camera view. Profile the full route and busiest console panorama.
10. Complete campaigns saves/results/menu loop, optional collection completion, feedback/audio selection, accessibility and aspect tests. Do full start-to-finish playthroughs through real controls and all menu restart/retry paths.
11. Capture final concept comparisons and moving-camera evidence; fix z-fighting, clipping, incorrect eye orientation and illegible UI. Verify saved-scene editability by changing a source element in the Inspector, saving/reopening and running. Review asset notices and repository state.

When an actual game setup repository contains the project and its permitted assets with no gameplay, create annotated `setup-finished`. Do not label this design-only website checkout as a runnable game setup. Each actual game version V1…Vn later gets its own commit, annotated vN tag and vN branch as the skill requires. The design snapshot itself can be versioned independently without pretending the game is built.

## 18. QA, performance, cuts and unresolved risks

Functional gates: each mechanic's acceptance paragraphs; both full level-one paths; all level-two branches and level-three rings; optional-collectible bypass; checkpoint/level restart; death during head flight; cancel fetch during pause; occupied console movement rejection; fall during platform travel; correct flag/level result after save/load. Test through actual inputs, not only direct method calls. Use semantic state queries and timeouts for asynchronous transitions.

Perceptual gates: correct eye/body alignment, one visible head/arm, readable anticipations, clear route landings, bright coherent atmosphere, camera continuity, audible/visible valid and invalid feedback, dialogue safe placement, beam readability, no jitter or z-fighting, no default Godot font, no exposed blockout props.

Desktop target: 60 fps (16.7 ms budget) on a named test Mac to be recorded in BUILD_NOTES. Weakest device is not yet measured; iPad/mobile performance is unclaimed. Initial content guardrails: one shadowed sun; no more than 5 active enemies in a local area, 10 moving mechanisms visible near the player and roughly 25–35 nearby full-detail islands in a gameplay view. Level three may expose more in its overview; profile that exact camera. Reuse meshes/materials, turn off distant enemy logic, use simple colliders and measured visibility ranges. Do not silently reduce source textures or decimate assets. No performance result is claimed by this GDD.

Highest risks and first tests: detached hand skinning (rigid-pose extraction test), moving-platform collision (ride a lift before building many), orbit sweep safety (occupancy and reset), head-power/combat deadlocks (solve both routes with both states), too much onboarding (watch a new player), too much level content (finish the 28-island first world before expanding), camera motion discomfort (reduced motion and horizon lock), large vista frame cost (profile before dressing level three).

Cut first if needed: third gem detour in level one, decorative far islands, extra enemy placements, bespoke cinematic intros and optional background music. Keep all four core mechanics, both basic enemy archetypes, three finish flags, at least two routes per level, head/arm safety, world beacon, dialogue guidance, theme and feedback. Do not cut recovery or readable camera transitions to add more scenery.

Open decisions are tuning decisions after the first playable: final move/jump speed, exact level clear times, render quality tier on the weakest target, best head/arm animation timing, number of enemy placements and comfort settings. The game uses no globally novel-mechanic claim. Its proposed identity comes from how these specific rules interact.

## 19. Sources, skill use and revision policy

Built from Marco's selected Head Relay, Fetch Arm, Counterweight and Orbit ideas, his three-level/branching/vertical-world request, ground-pad camera revision, enemy/head-attack addition and eye-orientation correction. Sources were checked 17 October 2026 and archive inventories were inspected rather than assuming advertised pack counts cover the game.

The game-dev skill was freshly cloned and pulled before drafting: version 1.8.3, commit `562ec96fdab3ec1b57506502838a321f722bde85`, source commit 17 October 2026 11:42:05 Argentina time. Its camera, launch, concept-match, UI, prop, scene-ownership and public-Xogot-repo guidance informed this document. The user explicitly authorized public distribution of this project's complete skill snapshot, overriding its default private-copy rule for this project only. See [../skills/README.md](../skills/README.md).

Maintain this GDD in place. Future playtest rounds append a dated superseding section, identify changed rules and keep earlier rationale/history. Do not replace it with a retrospectively cleaned summary. See [REQUIREMENTS.md](REQUIREMENTS.md) for request coverage and [BUILD_NOTES.md](BUILD_NOTES.md) for evidence and limitations.

## 20. Revision 1.1: bowling-head combat and arena finales

17 October 2026. This section records Marco's later revisions and has priority over earlier contradictory text. All four exploration mechanics, branching worlds, vertical traversal, dialogue and the perspective-console rules remain. The head now bowls through crowds with gravity. Every platforming world ends at a flag, followed by a fade into a short dedicated arena scene. Platforming always happens first, including in world one. World-one platforms contain a few enemies, not arena-sized crowds.

### 20.1 The revised complete loop

Title → platform world N → flag captured → fade → arena N → arena victory → results → next platform world, or final campaign results after arena three. Platforming flag status and completed-arena status are separate save fields. The flag is the exploration destination; the arena is the victory finale. On arena defeat, Retry Arena restarts that arena only, never the entire platform world. Returning to title and Continue resumes the pending arena with a readable ready screen. No way to farm a flag repeatedly for duplicate completion rewards.

The flag capture still has a short celebration and pulls back both parts, then a 0.30 s fade-out, preloaded scene switch in black, and a 0.35 s fade-in at a safe arena spawn. Only the transition coordinator controls it. Inputs remain locked only through scene handoff and then return before enemies start. An initial 1.0 s ready beat states the objective. The normal third-person perspective returns in the arena; no console/overview camera during combat. Arena victory waits for the actual objective, then plays a short reward splash/fade to results.

### 20.2 Bowling head, in platforms and arenas

Replace section 5's single-hit shot with a returning **gravity-driven rolling head**. Left mouse triggers a short hand-to-head grab, lift and underarm bowling release. The body is headless until return. The paired black eyes face the initial roll direction; physical rolling may naturally turn the face, but the attached representation is always anatomically correct. No second head, no possession and no player jump assistance.

Initial tuning: head collision radius 0.6 m, launch forward speed 18 m/s, low underarm vertical speed 2.5 m/s, gravity 20 m/s², modest bounce about 0.25 and low rolling resistance. The mesh rolls with traveled distance around a stable physical/visual axis. Use a saved physics head scene with continuous collision/swept query so it cannot tunnel through a thin enemy at speed. Do not move a physics body by arbitrary per-frame position assignment while pretending it has gravity.

A ball keeps moving through ordinary enemies and instantly defeats **every ordinary enemy it contacts**, without a one-target cap. Keep forward speed when passing through enemy hurt volumes; enemy bodies do not act as solid pinball blockers. Deduplicate each enemy ID for that launch. It can bank from solid arena/world geometry, fall, bounce and roll down slopes. It stops being an attack only when recalled/returning. Bosses are the explicit exception: more health, one accepted damage per boss per launch.

Automatic recall begins after 2.5 s or 36 m cumulative travel, when speed remains below 1 m/s for 0.4 s, or when the ball falls into a recovery volume. Q while deployed recalls early; target selection never strands the part. The return is a fast non-damaging visual homing state, with collision disabled and a clear fade/trail change; it is no longer a rolling attack. Initial return target ≤0.45 s plus 0.15 s reattach recovery. Holding attack may repeat on reattachment as a comfort option; each roll still has its full authored release gesture. Aim assist never removes gravity or teleports the ball into enemies.

Receiver deployment uses this same ball and a socket catch rather than a floating homing projectile. First-world receiver lanes are short, flat or slightly descending, with a visible curb/channel and broad catch funnel. A low underarm throw can bridge a small gap only when the physical trajectory reaches the catch; do not promise a 12 m socket across arbitrary empty space. The initial tutorial receiver is within 6 m and slightly lower. A trajectory preview highlights an achievable socket; invalid trajectories reject. A socket catches and parks the head in its seated state until Q recall. Do not require a launch through an enemy to solve the first receiver puzzle.

The head-power/combat tradeoff persists: no head roll while it is seated. A combat press while seated says “Recall your head first.” Q returns it; roll again from a safe position. Latches, safe retreat and alternative routes prevent combat/relay deadlocks. An arm retrieval does not cancel a rolling head unless a mode transition requires both parts attached.

### 20.3 One broad arena, many satisfying lanes

Each arena is a separate reusable scene in the same sky-world style: one giant connected landing surface, clouds and ochre rock sides, perimeter vegetation/rocks/fences, four to six visible spawn entrances, cyan machine details and a distant world beacon. Compose the floor from authored modular tiles or a saved authored floor resource; avoid duplicate coplanar top faces. Initial clear combat footprints: 48×48 m, 56×56 m, 64×64 m. A 4 m clear perimeter lane allows circling; decoration stays outside it. Slight ramps/curbs allow bank shots while avoiding clutter and small collision traps.

No orbit console, tilting floor or mandatory jump-pad puzzle runs during an arena. The same third-person camera follows the body, with a slightly wider initial FOV 65° and 8 m spring length tuned against concept captures. A stable horizon and clear body silhouette matter more than cinematic shakes. Keep the near-camera lane transparent through proper obstruction handling rather than hiding gameplay beneath huge UI.

Enemies spawn **little by little throughout each wave**, not a hundred on one frame. Each portal warms for 0.4 s, marks a safe landing, and releases a small staggered group. Do not spawn inside 6 m of the player, on the player's camera near plane, or inside solid props. Rotate portal choices to make readable roll lanes. Wave births pause while already at the profiled active cap, then catch up gradually; never release an accumulated batch at once.

### 20.4 Three waves and short pacing

All durations are first-clear targets requiring playtesting, not measured results or a claim that a maximum timer guarantees victory. A good clear can approach 30 s with strong roll chains; normal first clears target the bands below. Do not artificially prolong a successful arena. Wave release windows can overlap while old enemies remain; a new wave starts on its scheduled window or early after the prior wave is empty. A visible remaining-enemies count explains any cleanup. Defeat all required enemies and bosses for victory; a timer never silently grants success while a boss is alive.

| Arena | Target clear | Main wave population | Release schedule | Bosses / summons | Total target population |
| --- | --- | --- | --- | --- | --- |
| 1 Opening Burst | 35–45 s | 3 × 60 = 180 | 0–9 s, 11–20 s, 22–31 s; about 6–7 enemies/s spread over portals | No boss | 180 |
| 2 The Summoner | 45–55 s | 3 × 75 = 225 | 0–11 s, 13–24 s, 26–37 s; about 6–7 enemies/s | One boss active from first wave; at most 24 summoned extras | Up to 249 |
| 3 Twin Paintstorm | 55–65 s | 3 × 90 = 270 | 0–13 s, 15–28 s, 30–43 s; about 6–7 enemies/s | Two bosses active together during the waves; at most 24 summons each | Up to 318 |

Use distributed releases such as 1–2 enemies per 0.25–0.35 s across selected portals; no portal delivers a full wave instantly. Summons are also staggered and count toward the same active cap. Target crowd budget: initially 80 active regular enemies, tested stretch 120–160 if the target machine sustains the frame budget. Hundreds are the spawned encounter population; an especially successful player may keep the simultaneous crowd much smaller. Do not claim 200 fully simulated enemies at 60 fps before measuring it. If Marco wants a specific simultaneous count later, benchmark that exact count before promising it.

The last release is deliberately early enough to allow 10–20 s of satisfying cleanup. If first playtests repeatedly exceed 65 s, reduce the release count, move portals into fairer lanes or lower boss HP before speeding up the player or hiding remaining enemies. No endless reinforcement loops or post-wave 30-second boss phase. Boss death cancels its future summons; only enemies already born remain to clear.

### 20.5 A coherent monster library

Keep the platformer Crab and Bee as sparse exploration enemies. Expand the horde with a small curated set from Quaternius's Cute Animated Monsters: Mushroom, Cactus, Alien and Cyclops, plus Yeti as the boss source. The full pack's 21 models form the available asset bank; the selected five are the required import set, not a requirement to place all 21. Mechs stay a comparison alternative, not a production dependency.

The four ordinary horde silhouettes share one light chase/contact behavior with modest movement differences, keeping the crowd predictable and the build manageable. Mushroom and Cactus at 1.8–2.1 m/s, Alien at 2.4 m/s, Cyclops at 1.7 m/s. Each has 1 health and dies to a bowling contact. No tiny hard-to-read color-only variants. Show all four in arena one. Bees remain sparse platform encounters; do not require a floor-bound ball to hit an unreachable flying enemy in the arena.

Arena-two boss: one Yeti, visual height about 3.2 m through its owned wrapper and correctly sized collider, 5 accepted roll hits. It telegraphs a summon for 0.8 s and births at most 6 enemies over 1.5 s every 8 s, max four summons = 24 extras. It also makes a slow 1.0 s warned stomp with a visible ground ring, one damage in a 3 m radius, 1.2 s recovery. Boss hurtbox is always hittable except during its brief accepted-hit cooldown; no long invulnerable phases. Each launch can damage it only once, even if it bounces back into the same boss. Its health bar visibly animates on accepted contact.

Arena-three bosses: two Yeti variants with distinct cyan and warm-coral accents/icons, both active from wave one. Each has 5 roll-hit health and max 24 summoned extras. Their warning/attack schedules are offset by 2 s so rings do not create unavoidable traps. No mandatory sequential phase or “kill the first to reveal the second.” A line through both bosses can damage both once per launch, rewarding good positioning. They spawn their extras gradually, subject to the same density cap. Their health bars sit at top center with readable icons and never cover the player or head.

Chosen creature files, dependencies and clips must be checked after the new download; do not substitute concept artwork for a real asset. The official creator-linked Drive mirror returned quota-exceeded responses, so source the same free pack from Quaternius's own OpenGameArt upload and preserve its license/inventory/checksum. No paid or unattributed replacement is introduced.

### 20.6 Defeat paint and the juice budget

Every monster defeat leaves a colored paint splash on the contacted floor/surface, then that paint fades. It is paint, not blood. Color comes from a small coherent cyan/coral/yellow/violet palette, with shape/value cues preserving readability. Enemy defeat also gives a quick color burst, small 3D droplets, clear pop audio, brief squash/recoil and a readable chain counter. A boss defeat makes a larger authored splash and a short celebration, not a long unskippable movie.

The final painting technique, accumulation/fade rules and surface attachment follow the user's forthcoming skill update. Do not improvise a stack of coplanar transparent quads or claim a paint system has been implemented. Keep landings and remaining enemies legible; floor coverage is decorative, never slippery or damaging. Splash lifetime and effect concurrency will be explicit after reading that update. Preserve this rule in both normal platforming encounters and arenas.

High-volume juice is bounded: a kill chain emits per-enemy small particles and paint, but sound voices, large bursts and camera impulses are rate-limited so 30 kills do not become 30 full-volume simultaneous booms or an unreadable shaking screen. The ball keeps rolling and the player keeps moving. Effects are pooled from saved source scenes; active painting/effect counts are measured in the busiest frame.

### 20.7 Acceptance and scope updates

The cut list no longer excludes bosses or arena scenes. Keep exactly three short arena finales, one no-boss arena, one single-boss arena and one two-boss arena. No extra standalone levels, long boss introductions, weapon inventory or new combat abilities are added. Revised pacing adds roughly 2.5–3 minutes of arena action to the three platform worlds, plus brief transitions/results.

Pass actual gameplay tests: one roll defeats a line of at least 10 ordinary enemies without losing speed; a bank shot changes direction under collision; a ball falls and automatically returns; a socket catches the physical bowling head; each boss takes one hit per launch and survives normal contacts until its health reaches zero; both arena-three bosses are active during all wave windows; summons stop after boss death; enemies enter gradually with no one-frame crowd burst; arena retry never restarts platforming; world progress persists correctly through a quit during handoff.

Pass visual/performance tests: behind-player view with 80 active enemies first, then 120 and 160 only if frame time permits; capture the real frame time and effect counts, not a made-up crowd FPS. Inspect a defeat contact sheet for surface-attached paint, fade, no coplanar flicker, clean enemy removal and visible rolling-head rotation. Play each arena with new players and measure total clear time against 35–45 / 45–55 / 55–65 s. Inspect color/shape variety, head-body orientation and boss health feedback. Arena artwork is a visual target, not this evidence.

## 21. Revision 1.2: paint module and arena camera/layout correction

17 October 2026. Pulled the updated skill at `22fe20ab13670b63b8c8326916ec4a6bdc2453d5`, version 1.9.0 (14:27:37 Argentina time), then read the full new paint-splash module. This section resolves the pending paint design in §20.6 and updates arena geometry/camera. The full updated snapshot replaces the older project skill copy, under the same explicit public-sharing exception.

### 21.1 Circular arena, edge portals, true third person

Arenas are circular, one giant connected platform, with diameters 48 m, 56 m and 64 m. This supersedes square-footprint implications in §20.3. Keep a wide open center, a clear perimeter circulation lane and sparse decoration outside the combat lane. Six evenly spaced rim portal anchors have unobstructed release zones. Portal arrival positions face inward and must respect the player's 6 m safe radius. They are saved authored portal scenes using simple ring geometry/materials and particle effects, not a missing external pack.

Combat uses a conventional low **third-person follow view directly behind the robot**, not an overhead, isometric, tactical or arena-wide camera. Start near a 6.5–7.0 m follow distance, camera about 2.6–3.0 m above floor, gentle 10–15° downward pitch and perspective FOV 65°. The robot is large and readable in the lower center (target 18–23% of frame height), looking toward the action. Track the interpolated body rigidly in position, zero roll, collision-aware spring distance. Tune actual pose to match the corrected combat concept at 1920×1080. Do not zoom out just to show all enemies.

A separate high perspective overview concept shows the full circle, six portal positions, outer decoration band and combat lanes. It is a layout planning/reference shot, not an in-game arena camera mode. The only interactive overview camera remains the exploration ground-console mechanic. No extra arena camera controls are added.

### 21.2 Paint splash contract, adapted from game-dev 1.9.0

Use the skill's saved-scene paint module and included six splat shapes as the starting point, adapting behavior to a bowling head rather than copying a paint-gun game. The bowling head remains 18 m/s with gravity and solid-world collisions as §20.2 specifies; the module's 40 m/s paint ball and aim-slack world-surface bypass are NOT the head's mechanics. Do not bypass walls or make the physical roll land at a hitscan point. Use the module's swept-hit principle to prevent tunneling.

On each accepted enemy defeat, six layers align to that event: rolling-head trail/impact cue, a paint droplet burst, eased splat pop, the wet surface mark, small drips/spatter where appropriate, and a wet pop sound. The head remains intact and keeps rolling through ordinary enemies. Monster color chooses cyan/coral/violet/yellow paint with a slightly lighter highlight.

Initial burst: 16 droplets, 0.55 s lifetime, near-instant 0.95 explosiveness, 62° spread, 2–5 m/s velocity, shrink curve to zero and gravity. Orient it to the found surface normal and offset about 0.06 m. A miss uses about 30% burst intensity. A non-linear 0.22 s pop reaches a measured target peak around 1.15 before settling. Inspect actual frames rather than assuming the tween produces that scale.

Find the real floor or prop beneath the defeated enemy by a world-only ray, ignoring player/enemy meshes, head and paint. On floors/bridges use a low wet shader slab for relief when its surface fit is valid, or decorative puddle Decal for irregular surfaces. Walls/props use surface-wrapping Decals. All paint is visual, has no gameplay collider and never creates a walkable platform. Do not stack thick floor blobs into pillars or bridge a gameplay gap. If an airborne defeat has no receiver surface below, use falling droplets/air burst; never float a fake floor stain in mid-air.

Preserve the module's wetness and brightness: clearcoat, low plateau roughness, self-light near 0.22 for slab material, and the six exact alpha splat textures. Decals use the same texture as their emission, initial energy 1.2, and the matte ORM so lit/shaded marks retain their hue. Player and enemy geometry use the dedicated exempt visual layer (bit 19); Decal culling excludes it, so paint never tints the robot, monsters or head. The current project uses Mobile, which supports Decals; the Compatibility fallback would need an authored normal-offset textured quad and a documented corner-wrapping limit, not a silent renderer change.

Fade rule: 6 s initial lifetime. Hold vivid color for 4.1 s, gently desaturate during the last 1.5 s, then dissolve alpha to zero over 0.4 s. This deliberately avoids warning strobe for decorative death paint. Reduced-flash mode keeps only the smooth fade. Regular splat initial radius 0.65–0.9 m, thin relief 0.015–0.03 m; boss splat radius 2 m with a slower 0.35 s pop. Values are custom Cloudline targets, not claimed inherited measurements. Paint stays attached to the hit surface: if a platform translates/rotates later, its mark moves with its surface owner and fades normally.

Drips hang along WORLD down, ray-trimmed at real ground; flat supported splats use spatter beads instead of arbitrary dangling drops. Start with up to 7 drips/5 beads only where visible and justified. Share materials by paint color, use per-instance variation/seed, and keep the CPU/GPU outline definitions synchronized. Initial caps: 96 live surface marks, 24 active small burst slots, 6 larger chain/boss confetti slots and 12 decorative puddle slots; recycle oldest faded marks cleanly. Visual feedback never fails silently when a pool is full. Do not make hundreds of expensive full splat systems persist forever.

Audio uses three short wet variants, pitch variation ±8%, no immediate repeat. Rate-limit loud combined-chain accents while keeping individual small visual splashes. Sources for final wet SFX must be selected/created and recorded; the module references three WAVs but does not supply those WAV files. It is an integration reference, not a drop-in complete game dependency. Boot-muted/M behavior still applies.

### 21.3 New paint acceptance checks

Capture one defeat on a lit floor, shaded prop and moving platform. Paint color remains coherent, characters remain untinted, droplet burst begins on the impact frame, pop peak is measured near 1.15, and paint disappears through the specified smooth fade. Check both dry/new and overlapping marks during movement for z-fighting; use a small normal offset around 0.004 m where appropriate and fix geometry rather than hiding depth conflicts.

A diagonal wall impact wraps its receiver surface without becoming a billboard sticker. A rotating or lifting platform carries the stain without detaching. A large bowling chain leaves a readable lane of splashes, not a single giant opaque pool covering all enemies. Pool recycling does not create one-frame flashes or unbounded node growth. Record actual burst/mark counts and frame time during the busiest arena. A still image proves the visual target, not timing or feel; the final game requires a playtest and consecutive-frame evidence.

## 22. Revision 1.3: latest skill and the paint puddle target

17 October 2026. Marco updated the skill again; fresh pull is `1f54afc4cd24f163eb11d8a65ce8950eedaa1edd`, still version 1.9.0, timestamp 14:44:00 Argentina time. Read the updated paint-splash documentation and all three reference stills before finalizing this delivery. The full project/public snapshot includes the newly supplied puddle/blob/manager scenes, materials, resources, manager script, gel shader and reference captures, with their original relative paths and provenance. They remain reference material under `.gdignore` in code/resource folders, not silently installed live gameplay systems.

The visual priority is the **paint puddle/decal itself**: a flat, saturated, surface-wrapping splat with radiating arms and flung drops, matching the skill's `grip_splat_floor.jpg`, `grip_splat_wall.jpg` and `grip_splat_pip_near.jpg`. The synchronized juice surrounds that mark. Use decorative puddle Decals as Cloudline's default floor/bridge/wall death marks. This refines §21's optional low slab direction: Cloudline does not need thick walkable paint blobs, docking, paint bridges, ink inventory or terrain-generation mechanics. Keep only the impact-to-surface-spawn path, style variation, pop, fade, effects and pools from the reference manager.

Initial Decal targets remain normal_fade 0.2, paint-color modulation, shared alpha texture for albedo/emission, emission energy 1.2 and matte ORM, a small ~0.004 m normal offset, and exclusion of the dedicated player/enemy visual layer. The 0.22 s eased pop and 6 s Cloudline lifetime/0.4 s smooth dissolve stay. The skill's warning blink is omitted for decorative death paint in favor of the user-requested smooth fade; reduced-flash comfort is preserved. No character tint and no decal/paint collision.

The supplied reference's native scene/resource links still need path adaptation in the actual build. Do not copy its game manager wholesale: it contains Splatwalk-specific docking/bridge/ink rules and dependencies. Keep authored saved scene structure and the game's own focused behaviors. The raw source examples may include node-construction helpers; the skill's current modular-scene authoring rule remains authoritative for the future build.

The full 21-model Cute Monster source bank and all its original texture maps are now imported into the Xogot asset library so the additional silhouettes visible in crowd concepts are actually available. The core gameplay roster remains the four small horde types plus Yeti and the exploration Crab/Bee. A model being in the library does not require placing it, and any extra chosen variant must be added to the active roster/clip/material checks before use.


## 23. Revision 1.4: implementation record and the bright toon look (17 October 2026)

This section records decisions made while building the game. It supersedes earlier wording only where it says so; sections 20-22 still govern combat, arenas and paint.

**Look contract (Marco's note: the build lacked the concepts' toony, bright look).** Every frame is judged against the concept images, not against "default Godot". The runtime uses the Linear tonemap (Filmic greyed the whites and the grass), lime-yellow grass, peach-orange faceted rock bodies that taper to a narrow base, orange wood, deep-green shrubs, a bright yellow robot with silver trims and white faceted clouds that fill the space under and around the islands. Each world has its own time of day, matching its concept: Sunrise Junction is a bright morning (cream-white clouds with lavender shade, warm sun glow and disc on the left horizon), Cargo Gardens a clear turquoise midday, Crown Circuit a golden afternoon (blue sky, cream-peach clouds, warm glow on the right); arenas and the title use the midday look. The sun disc and glow are camera-anchored quads, not lights. Vendor models are untouched: their material names are remapped to toon materials through each glTF's import settings. Decorative far islands, grass tufts and cloud banks are saved scenes placed through xo like everything else.

**Level 2 and 3 adaptations.** Island and mover budgets follow section 9 except where a route needed a connector: world two has 42 fixed islands plus two optional pockets, world three 60 plus one pocket. The cross-links Low-Mid and Mid-High of world three are the plaza row of the Crown Approach (a bridge cannot span 35 m between rings without a dead stretch). The unlocked return lift is a cyan return pad that fades the robot back once the late checkpoint is active (Exchange in world three, Junction in world one). World two's cargo door is a relay-powered door on a long flat bridge with a latch beyond it, so the head can be recalled for the crab ahead without trapping anyone.

**Assists and comfort.** Arena survival has an optional regeneration and chain-heal assist (Settings); key remapping swaps clashing keys; text size and reduced motion/flash/shake are in Settings; the F1 development panel is removed from release builds.

**Not measured or not claimed.** Frame times are from the editor-embedded run on the development Mac only; no iPad or weakest-device result is claimed. The arena crowds were played by test bots, not by new human players, so the 35-65 s clear targets are untested with people. The supplied packs contain sound effects only, so there is no music or ambience loop.
