class_name DialogueData
extends RefCounted
## Robot guidance lines (docs/DIALOGUE.md). One entry per event id; priority 0 safety, 1 tutorial,
## 2 objective, 3 flavor. `once` lines never replay in a run after they were shown.

const SAFETY := 0
const TUTORIAL := 1
const OBJECTIVE := 2
const FLAVOR := 3

const LINES := {
	&"welcome": {"text": "A whole sky of shortcuts. Let's find ours.", "priority": FLAVOR},
	&"flag_intro": {"text": "That golden beam marks the flag.", "priority": OBJECTIVE},
	&"relay_hint": {"text": "{head_deploy} sends my head to that socket. It powers the bridge.", "priority": TUTORIAL},
	&"relay_done": {"text": "I'll leave my head here. The rest of me can cross.", "priority": TUTORIAL},
	&"recall_hint": {"text": "Bridge secured. {head_deploy} brings my head back.", "priority": TUTORIAL},
	&"combat_hint": {"text": "Those claws mean trouble. Aim, then {head_attack:click} to bowl my head.", "priority": TUTORIAL},
	&"combat_done": {"text": "A clean hit. And my head comes straight back.", "priority": TUTORIAL},
	&"attack_seated": {"text": "Recall your head first.", "priority": SAFETY, "duration": 2.0, "repeat": true},
	&"fetch_hint": {"text": "{fetch} reaches that coin. My feet can stay right here.", "priority": TUTORIAL},
	&"cargo_hint": {"text": "On this anchor, {fetch} can pull the heavy crate into its tray.", "priority": TUTORIAL},
	&"balance_hint": {"text": "Now my weight matters. Walk toward the raised exit.", "priority": TUTORIAL},
	&"balance_done": {"text": "Balanced. The clamp will hold our way out.", "priority": TUTORIAL},
	&"console_hint": {"text": "Step onto the arrow pad. Let's rearrange the route.", "priority": TUTORIAL},
	&"console_active": {"text": "{console_left} and {console_right} move this group. {interact} returns to exploring.", "priority": TUTORIAL},
	&"console_blocked": {"text": "Clear the platform first.", "priority": SAFETY, "duration": 2.2, "repeat": true},
	&"console_done": {"text": "That fits. {interact}, then let's cross it.", "priority": TUTORIAL},
	&"junction": {"text": "Low bridges or the high route? Both lead toward the beam.", "priority": OBJECTIVE},
	&"bee_hint": {"text": "Watch its hover. The dive comes after the warning.", "priority": TUTORIAL},
	&"checkpoint": {"text": "A safe place to restart. Our treasures are banked.", "priority": TUTORIAL},
	&"lost_hint": {"text": "Look for the golden beam. A lift or bridge can change your height.", "priority": OBJECTIVE, "repeat": true},
	&"relay_tradeoff": {"text": "Power or protection? I'll need my head back before I fight.", "priority": TUTORIAL},
	&"level2_intro": {"text": "Cargo below, shortcuts above. Same tools, more possibilities.", "priority": OBJECTIVE},
	&"level3_intro": {"text": "Three rings, one crown. Pick a route and keep the beam in sight.", "priority": OBJECTIVE},
	&"fall_return": {"text": "Parts accounted for. Let's try another way.", "priority": SAFETY},
	&"flag_capture": {"text": "Flag captured. One more piece of sky reconnected.", "priority": FLAVOR},
	&"final_capture": {"text": "All three flags. Not bad for a robot who keeps losing its head.", "priority": FLAVOR},
	# Arena additions
	&"arena1_ready": {"text": "Three quick waves. Let's make a colorful mess.", "priority": TUTORIAL, "duration": 3.2},
	&"bowling_hint": {"text": "Grab, roll, recall. One good line can clear the crowd.", "priority": TUTORIAL, "duration": 3.6},
	&"wave_start": {"text": "More coming through the portals!", "priority": FLAVOR, "duration": 2.4, "repeat": true},
	&"boss1_ready": {"text": "That big one summons friends. Five good rolls should do it.", "priority": TUTORIAL, "duration": 3.8},
	&"boss2_ready": {"text": "Two summoners. A straight line can catch them both.", "priority": TUTORIAL, "duration": 3.8},
	&"arena_victory": {"text": "Clean sweep. Well, almost clean.", "priority": FLAVOR, "duration": 3.0},
	&"arena_retry": {"text": "Same arena. Fresh paint. Let's roll.", "priority": TUTORIAL, "duration": 3.0},
}


static func get_line(id: StringName) -> Dictionary:
	return LINES.get(id, {})


static func has_line(id: StringName) -> bool:
	return LINES.has(id)
