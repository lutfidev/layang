# Layang — notes for Claude

Godot 4.7.2, GDScript, GL Compatibility renderer, landscape 1280x720 (stretch canvas_items/expand). Android target.

## Architecture
- No bitmap/audio assets except the font + `assets/audio/gamelan_loop.ogg`. All visuals are drawn in code (`scripts/world/art.gd`) or shaders (`shaders/`). Keep it that way: add new art as `Art.*` static helpers.
- Scenes are thin: each `.tscn` is a root Node2D + script; UI is built in code via `UIKit` (`scripts/ui/ui_kit.gd`).
- `World` (scripts/world/world.gd) is reused by game, menu and shop (menu/shop use `autoplay = true`, `input_enabled = false`).
- Game rules (timer, islands bonus, combos, fever, night, results) live in `scripts/ui/game.gd`; physics in `bird.gd`; terrain in `terrain.gd` (cosine-interpolated key points, islands separated by a sea at `boundaries`).
- Content is data: islands in `scripts/data/biomes.gd`, skins in `scripts/data/skins.gd`.
- Autoloads: `Game` (save/economy/dev flags/scene fade via `Game.goto(path)`), `Sfx` (`Sfx.play("coin")`), `Ads` (rewarded/interstitial/IAP facade — demo mode; integrate real plugins only inside ads.gd).

## Conventions
- Typed GDScript. Use `maxf/minf/absf/clampf` (not `max/min/abs`) when the result is assigned with `:=`, otherwise Godot fails with "Cannot infer the type".
- Player-facing text is Indonesian.
- Fredoka font is a latin subset: avoid symbols like ▶ ★ ← (they render as boxes).

## Testing
- Headless error check: `godot --headless --path . --quit-after 600 res://scenes/game.tscn -- --autoplay`
- Balance sim: `godot --headless --path . --fixed-fps 120 res://scenes/game.tscn -- --autoplay --sim --fresh` prints `RUN score=…`
- Screenshot: `... res://scenes/game.tscn -- --island=4 --autoplay --shot=out.png --shot-delay=8`
