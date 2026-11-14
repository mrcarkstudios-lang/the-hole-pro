# The Hole Pro

3D top-down "hole" game for mobile (landscape), Godot 4.7. City built from the KayKit City Builder Bits pack (CC0) plus our own primitive props (trees, barrels, crates, cones, bins, fountain, gold). All music and sound effects are synthesised in code.

## Run
Open this folder in Godot 4.7 and press F5, or `godot --path .`
Controls: drag anywhere (floating joystick) / WASD or arrow keys.

## Modes
- **Classic** (campaign): 90 s rounds, finish 1st to advance. Level themes cycle (Sunny City, Golden Hour, Neon Night, Frost Town). Every 5th level is a BOSS level (2x coins).
- **Royale** (unlocks at level 3): the arena shrinks, eaten holes are eliminated, last one standing wins.

## Gameplay systems
- Swallow anything smaller than you; items lean and tip into the hole as you approach.
- Combo multiplier up to x5, gold bonus items, power-ups (speed, magnet, grow, +8 s).
- Bots with different aggression; bigger holes eat smaller ones. Danger vignette + warning when a bigger hole closes in.
- Countdown, final-10-seconds tension, shrinking zone (Royale), camera shake, particles, rings, haptics.

## Retention systems
Daily reward streak (7-day cycle) - 3 daily missions - player XP/level - 7 hole skins (incl. animated Rainbow) - 4 permanent upgrades - bonus-coin meter after each round - near-miss messages ("only 12 points behind Kai") - instant PLAY AGAIN - first-run tutorial hints.

## Audio
- Adaptive 5-layer music loop in A minor (pad, bass, drums, lead, hype). Layers fade in with combo/time pressure; menu and result use calmer mixes.
- Swallow sounds climb the A-minor pentatonic scale with your combo, so the SFX play in key with the music.

## Files
`scripts/main.gd` controller - `hole.gd` - `item.gd` - `game_ui.gd` (all screens) - `profile.gd` (save + retention) - `props.gd` (our own models) - `fx.gd` (juice) - `sfx.gd`, `music.gd`, `synth.gd` (audio) - `assets/models/` (KayKit, see KayKit_License.txt)

## Android export
Project > Export > Add Android preset (needs Android SDK + Godot export templates).


## Links
- Privacy policy (for Google Play): https://mrcarkstudios-lang.github.io/the-hole-pro/privacy.html
- Source: Godot 4.7, GDScript. Open `project.godot` in Godot 4.7+.
- Android export: install the Android build template (Project > Install Android Build Template) to regenerate `android/build/libs`, then set your own signing key via the `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables. Signing keys are never stored in this repository.

## Credits and licences
- 3D models: KayKit City Builder Bits, Furniture Bits, Resource Bits, RPG Tools Bits (CC0) by Kay Lousberg.
- Fonts: Lilita One and Titan One (SIL Open Font Licence).
- Vehicles, people, audio and UI art are original to this project.
