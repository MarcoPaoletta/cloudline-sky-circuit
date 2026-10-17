# Cloudline game assets

Runtime assets for the scoped Cloudline robot platformer. Imported from the creator archives already stored in `cloudline-platformer/downloads/`.

- `robot/`: Quaternius Robot.fbx, with its 14 supplied animations.
- `platformer/`: the 12 glTF models needed for terrain, rock bases, clouds, coins, flags, bridge, bushes, rocks, and grass. The models embed their buffers/material data.
- `audio/`: six WAV sounds for jump, landing, pickup, checkpoint, footsteps, and menus.
- `licenses/`: license/info text retained from all three source archives.
- `import-manifest.json`: original archive members, destination paths, and file hashes.

Creator downloads:

- https://quaternius.itch.io/lowpoly-robot
- https://quaternius.itch.io/ultimate-platformer-pack
- https://opengameart.org/content/512-sound-effects-8-bit-style

The source archives include CC0 statements. Current Quaternius terms also allow games/videos and restrict standalone asset redistribution. Keep the supplied license evidence and obtain additional pack files from the creators. No Kenney assets are included.

These are source assets, not gameplay scenes. Add gameplay nodes and collision in wrapper scenes rather than editing imported model children. The FBX and glTF authoring scales differ; normalize their visual scale during gameplay setup. Asset importing does not change project input, renderer, or main scene.
