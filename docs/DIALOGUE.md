# Dialogue and guidance script

Robot voice: curious, concise and practical. The robot addresses itself/player through the bottom-center portrait panel. No voice recording or dialogue tree. Each line is a separate event-driven beat, max two rendered lines. Acknowledge with E; the first press completes typewriting and a separate press advances. Guidance never fires during a required jump or enemy wind-up.

| ID | Trigger / guard | Robot line | Completion / priority |
| --- | --- | --- | --- |
| welcome | Level 1 safe arrival, once | “A whole sky of shortcuts. Let's find ours.” | Movement stays active; flavor |
| flag_intro | Arrival view, once | “That golden beam marks the flag.” | Dismiss or leave safe anchor; objective |
| relay_hint | First receiver visible, head attached | “Q sends my head to that socket. It powers the bridge.” | receiver_powered; tutorial |
| relay_done | Receiver powered | “I'll leave my head here. The rest of me can cross.” | Enter far landing; confirmation |
| recall_hint | Safe landing latch closed | “Bridge secured. Q brings my head back.” | head_attached; tutorial |
| combat_hint | First crab wind-up on safe island | “Those claws mean trouble. Aim, then click to bowl my head.” | First accepted enemy hit; tutorial |
| combat_done | First enemy defeated | “A clean hit. And my head comes straight back.” | Head reattached; confirmation |
| attack_seated | Click while head seated | “Recall your head first.” | Brief 2 s prompt; safety |
| fetch_hint | First light target in sight | “F reaches that coin. My feet can stay right here.” | collectible_fetched; tutorial |
| cargo_hint | Anchor entered, crate available | “On this anchor, F can pull the heavy crate into its tray.” | crate_docked; tutorial |
| balance_hint | Crate docked in first balance tray | “Now my weight matters. Walk toward the raised exit.” | balance_exit_latched; tutorial |
| balance_done | Exit latched | “Balanced. The clamp will hold our way out.” | Nonblocking confirmation |
| console_hint | Near first console, no other modal | “Step onto the arrow pad. Let's rearrange the route.” | console_entered; tutorial |
| console_active | Console camera settled | “Left and Right move this group. E returns to exploring.” | route_aligned or exit; mode-specific |
| console_blocked | Affected group or sweep occupied | “Clear the platform first.” | Brief prompt, no repeated spam; safety |
| console_done | First route aligned | “That fits. E, then let's cross it.” | console_exited; confirmation |
| junction | First branch hub reached | “Low bridges or the high route? Both lead toward the beam.” | Once; objective |
| bee_hint | First bee approach, player on safe landing | “Watch its hover. The dive comes after the warning.” | First bee attacked/avoided; tutorial |
| checkpoint | First checkpoint activation | “A safe place to restart. Our treasures are banked.” | Once; confirmation |
| lost_hint | 20 s with no route progress, safe ground | “Look for the golden beam. A lift or bridge can change your height.” | Cooldown 45 s; objective |
| relay_tradeoff | Level 2 powered door, enemy ahead | “Power or protection? I'll need my head back before I fight.” | Safe latch/alternate route reached; tutorial |
| level2_intro | Level 2 arrival | “Cargo below, shortcuts above. Same tools, more possibilities.” | Once; objective |
| level3_intro | Level 3 arrival | “Three rings, one crown. Pick a route and keep the beam in sight.” | Once; objective |
| fall_return | First checkpoint recovery, safe | “Parts accounted for. Let's try another way.” | Once, never after every fall; recovery |
| flag_capture | Capture accepted and parts returned | “Flag captured. One more piece of sky reconnected.” | Results ready; celebration |
| final_capture | Level 3 capture | “All three flags. Not bad for a robot who keeps losing its head.” | Campaign results; celebration |

Priority: recovery/safety, active instruction, objective reminder, flavor. Queue at most one pending hint per event ID. Never replay a finished instruction because the player walks backward through its trigger. An in-pause Hint Log offers seen guidance without interrupting play. The console strip replaces, rather than stacks on, dialogue. Hint text and key prompts read remapped action names.

## Arena guidance additions

| ID | Trigger | Robot line |
| --- | --- | --- |
| arena1_ready | Safe arena spawn before wave clock | “Three quick waves. Let's make a colorful mess.” |
| bowling_hint | First arena roll opportunity | “Grab, roll, recall. One good line can clear the crowd.” |
| wave_start | Wave release window opens | “More coming through the portals!” |
| boss1_ready | Arena 2 ready beat | “That big one summons friends. Five good rolls should do it.” |
| boss2_ready | Arena 3 ready beat | “Two summoners. A straight line can catch them both.” |
| arena_victory | All wave and boss objectives satisfied | “Clean sweep. Well, almost clean.” |
| arena_retry | Arena-only retry | “Same arena. Fresh paint. Let's roll.” |

Arena lines are short ready-beat or nonblocking barks. They never open a blocking dialogue while the player is dodging. Wave count and boss health use the compact HUD. Retry Arena preserves the completed platforming section. Flag-capture text now leads to the fade/arena, not directly to final results; campaign completion follows arena three.
