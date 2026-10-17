# Measured art targets

Measurements are from the corrected final concept PNGs, not from the game. Use the selected target image as the build comparison; record final renderer, camera and light values in BUILD_NOTES after runtime verification. RGB patch values are median samples from the stated normalized coordinates. Overall brightness is PIL 8-bit grayscale, not physical luminance.

| Target | Mean gray / 255 | Pixels under 64 | Sky median | Grass median | Sample centers sky / grass |
| --- | --- | --- | --- | --- | --- |
| 01-cloudline-key-art | 198.3 | 0.53% | #99d5fc | #f1f932 | ((0.35, 0.06), (0.2, 0.88)) |
| 02-level-1-sunrise-junction | 197.7 | 0.43% | #85d1fd | #7ba503 | ((0.76, 0.06), (0.53, 0.91)) |
| 03-level-2-cargo-gardens | 195.4 | 0.40% | #82dcf4 | #e6fa3f | ((0.65, 0.05), (0.1, 0.89)) |
| 04-level-3-crown-circuit | 186.0 | 0.53% | #fce7dc | #c8cc28 | ((0.32, 0.1), (0.19, 0.88)) |

Initial scene candidates: perspective gameplay FOV 60°, console overview FOV 32°; sun elevation 35° and azimuth 135°, warm-neutral sun and cool sky ambient. These are starting hypotheses, not recovered physical camera/light calibration from the AI image. Tune them against the reference and record actual values.

Match in order: camera/horizon and subject screen size, visible island counts and silhouettes, prop locations, sky/grass colors, sun direction/shadow softness, fog depth, feedback and UI. Use all visible objects in the selected frame, extending the remainder of the level off-frame. Do not match an enlarged level overview to the normal follow camera.

Brightness gate: compare equivalent 1920×1080 framing. Investigate runtime mean gray differing by more than 10 from its selected concept or dark-pixel share rising by more than 5 percentage points. These are review triggers, not automatic proof of a match; inspect landings, character and dialogue directly. Fix exposure/ambient/sun before disguising a dark scene with bright materials.

No Kenney skybox. Use a procedural sky and the imported Cloud_1/2/3 geometry. No SSAO, volumetric fog, glow or renderer-specific technique is assumed available in the existing Mobile renderer. The beacon uses a simple emissive mesh material effect that must remain legible without those features.


Arena camera ground truth: image 20's THREE QUICK WAVES panel, carried into revised images 14–16. Keep the camera behind the robot with a gentle downward pitch, rather than zooming to a tactical view. Image 21 is an intentional high perspective layout overview only. For paint, the skill's three actual reference-stills show the required flat vivid puddle/decal silhouette, surface wrapping and surrounding juice. These are separate source-game captures, not Cloudline runtime evidence.
