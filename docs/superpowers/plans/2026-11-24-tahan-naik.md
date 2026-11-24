# Tahan = Naik + Monster Laut — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hold-to-dive slope mechanic with hold-to-rise flight (stamina, ceiling, ground running, "NYEREMPET" combo) and make the sea deadly (drowning + a telegraphed jumping sea monster).

**Architecture:** Flight physics stays in `bird.gd` (pure `step(delta)` driven by `holding`), hazards live in a new `SeaMonster` node owned by `World`, run rules (end causes, combo→fever, HUD) stay in `game.gd`. `World` re-emits bird/hazard events as signals so `game.gd` never reaches into hazard internals. A headless test scene drives `Bird`/`World` deterministically.

**Tech Stack:** Godot 4.7.2, typed GDScript, GL Compatibility.

**Spec:** `docs/superpowers/specs/2026-11-24-tahan-naik-design.md`

## Status (2026-11-24)

- **Selesai** di branch `tahan-naik` (Task 1–5, 23 tes hijau). Belum di-merge ke `main`.
- Penyimpangan dari rencana (lihat pesan commit): laut makin lebar per pulau, pulau lebih pendek
  (9+k bukit), kecepatan 420→740, peringatan laut pertama 1,4 dtk, respawn "Lanjut" 900 px di atas air,
  flag dev `--nosave`.

## Global Constraints

- All visuals in code (`Art.*` static helpers / shaders); no new bitmap or audio files. New sounds are synthesised in `sfx.gd` with `_tones`/`_noise`.
- Typed GDScript; use `maxf/minf/absf/clampf` when the result is assigned with `:=`.
- Player-facing text Indonesian; only latin + `×` `•` `…` symbols (already used, render fine in Fredoka).
- Coordinates: y grows downward. `Terrain.WATER_Y = 300`. Hills span roughly y ∈ [-260, 160].
- Headless error check must stay clean: `godot --headless --path . --quit-after 600 res://scenes/game.tscn -- --autoplay`
- Not a git repo: skip commit steps unless the user runs `git init`.

## Review Focus

1. Holding while stamina is exactly at 0 then barely refilling — expect no rapid on/off flicker (re-enable only at ≥ 0.2). → Task 1 test `test_stamina_hysteresis`.
2. Bird flying over the sea above the monster's reach — expect never bitten, regardless of how many jumps fire. → Task 3 test `test_monster_cannot_reach_high_bird`.
3. Menu/shop autoplay worlds — expect no deaths, no monsters, no "game over" signals (they run forever). → Task 3 test `test_no_hazards_in_menu_world`.
4. "Lanjut terbang" after drowning/bite — expect bird respawned above water, stamina full, any active monster removed, no instant re-death. → Task 4 test `test_continue_after_drown_is_safe`.
5. Nightfall while over the sea — expect the sleepy bird to sink and the run to end by drowning (cause shown), not hang in "night" forever. → Task 4 test `test_night_over_sea_ends_run`.

---

### Task 1: Test harness + hold-to-rise flight physics

**Files:**
- Create: `tests/run_tests.tscn` (root Node + `tests/test_runner.gd`)
- Create: `tests/test_runner.gd` — collects `test_*` methods from `tests/test_*.gd` scripts, runs each, prints `PASS name` / `FAIL name: msg`, ends with `TESTS passed=N failed=M` and `get_tree().quit(1 if failed else 0)`.
- Create: `tests/test_flight.gd` (extends `RefCounted`, each test returns `""` on success or a failure message)
- Modify: `scripts/world/bird.gd` (replace `step`, `_land`, constants; remove dive/tucked logic)
- Modify: `scripts/autoload/game_state.gd:46-54` — rename action `dive` → `fly`; keys Space, Up, W.
- Modify: `scripts/world/world.gd:122` — `Input.is_action_pressed("fly")`.

**Interfaces:**
- Produces (Bird):
  - consts `GRAVITY := 1300.0`, `LIFT := 2900.0`, `MAX_RISE := 620.0`, `MAX_FALL := 520.0`, `SPEED_START := 380.0`, `SPEED_MAX := 700.0`, `SPEED_RAMP_X := 60000.0`, `CEILING_SOFT := -1200.0`, `CEILING_HARD := -1500.0`, `STAMINA_DRAIN := 0.4`, `STAMINA_REGEN_AIR := 0.33`, `STAMINA_REGEN_GROUND := 0.8`, `STAMINA_RESUME := 0.2`, `BONK_SLOPE := -0.5`, `BONK_FALL_SPEED := 420.0`
  - `var stamina := 1.0`, `var exhausted := false`, `var on_ground: bool`, `var holding: bool`, `var sleepy: bool`, `var fever: bool`
  - `func step(delta: float) -> void`
  - `func can_lift() -> bool` — `holding and not sleepy and not exhausted`
  - signals: `landed(bonk: bool)` (replaces `landed(quality)`), `took_off`, `splashed` kept for the visual splash.
- Test helper inside `test_flight.gd`: `_make(seed: int) -> Array` returning `[terrain, bird]` added under the runner's tree (Terrain needs a `CoinField`).

- [ ] **Step 1: Write failing tests in `tests/test_flight.gd`**
  - `test_hold_rises`: bird in air at y=-400, `holding=true`, step 0.5 s at 1/120 → `bird.position.y < -400` and `bird.vel.y >= -Bird.MAX_RISE - 0.1`.
  - `test_release_glides`: in air, `holding=false`, step 2 s → `bird.vel.y <= Bird.MAX_FALL + 0.1` throughout.
  - `test_stamina_drains_and_blocks`: hold 3 s in air → `stamina == 0`, `exhausted == true`, `can_lift() == false`.
  - `test_stamina_hysteresis`: from exhausted, release until `stamina` reaches 0.15 → still exhausted; until ≥ 0.2 → not exhausted.
  - `test_ceiling`: hold with infinite stamina (reset `stamina = 1` each step) for 10 s → `position.y >= Bird.CEILING_HARD - 5`.
  - `test_ground_runs_not_dies`: release over a hill until it touches ground → `on_ground == true`, bird keeps moving (`vel.x > 0`) for 2 s, stamina regen ≥ `STAMINA_REGEN_GROUND * 0.9` per second.
  - `test_forward_speed_ramps`: `vel.x` ≈ `SPEED_START` at x≈0 and ≈ `SPEED_MAX` at x ≥ `SPEED_RAMP_X` (fever ×1.3).
  - `test_sleepy_cannot_lift`: `sleepy=true, holding=true` → bird descends; stamina does not regen.
- [ ] **Step 2: Run** `godot --headless --path . res://tests/run_tests.tscn` → expected FAIL (old physics/constants missing).
- [ ] **Step 3: Implement the physics in `bird.gd`.** Per step: target `vel.x = lerpf(SPEED_START, SPEED_MAX, clampf(x / SPEED_RAMP_X, 0, 1)) * (1.3 if fever else 1.0)` (approach it, don't snap; on ground ×0.85). Vertical: `vel.y += GRAVITY*delta`; if `can_lift()` `vel.y -= LIFT * lift_scale * delta` where `lift_scale` fades 1→0 between `CEILING_SOFT` and `CEILING_HARD`; clamp `vel.y` to `[-MAX_RISE, MAX_FALL]`. Stamina drains only while lifting; regens otherwise (ground rate when `on_ground`; none when `sleepy`). Ground: if `position.y >= height_at(x)` snap to surface, follow tangent; `landed(bonk)` with `bonk = vel.y > BONK_FALL_SPEED or slope < BONK_SLOPE`; bonk cuts `vel.x *= 0.6`. Holding on ground lifts off (emit `took_off`). Visuals: fast flap while lifting, wings spread while gliding; drop the `tucked` pose.
- [ ] **Step 4: Run tests** → `TESTS passed=8 failed=0`.
- [ ] **Step 5: Run headless check** (Global Constraints) → no script errors. (World still compiles: update `world.gd:211-216` `_on_landed(bonk: bool)` — shake on bonk — and `game.gd:193` signature to `bonk: bool` as a temporary stub that keeps old popups for bonk only.)

### Task 2: NYEREMPET skim detection

**Files:**
- Modify: `scripts/world/bird.gd`
- Modify: `scripts/world/world.gd` (re-emit)
- Test: `tests/test_flight.gd`

**Interfaces:**
- Produces (Bird): consts `SKIM_HEIGHT := 90.0`, `SKIM_MIN_TIME := 0.6`; `signal skimmed(duration: float)`; `var skim_t := 0.0`.
- Produces (World): `signal bird_skimmed(duration: float)`, `signal bird_landed(bonk: bool)`.

- [ ] **Step 1: Write failing tests**
  - `test_skim_emits`: put bird in air 50 px above a hill, glide/hover inside the zone for 1.0 s, then lift above 90 px → exactly one `skimmed` with duration ≥ 0.6.
  - `test_skim_too_short`: 0.3 s in zone then leave → no `skimmed`.
  - `test_skim_cancelled_by_ground`: enter zone, touch ground → no `skimmed`; `skim_t == 0`.
  - `test_no_skim_over_sea`: zone measured only where `not terrain.is_sea_at(x)` (Task 3 adds it; for this task use `height_at(x) < Terrain.WATER_Y`).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** zone = `not on_ground and (height_at(x) - position.y) < SKIM_HEIGHT and height_at(x) < Terrain.WATER_Y`. Accumulate `skim_t`; on leaving zone emit if ≥ `SKIM_MIN_TIME`; reset on touching ground.
- [ ] **Step 4: Run tests** → all pass.

### Task 3: Sea hazards — drowning + SeaMonster

**Files:**
- Create: `scripts/world/sea_monster.gd` (`class_name SeaMonster extends Node2D`)
- Modify: `scripts/world/art.gd` — add `static func sea_monster(ci: CanvasItem, pos: Vector2, s: float, body: Color, belly: Color, mouth_open: float, t: float) -> void` (chubby serpent head + 2–3 trailing humps, big eyes, big teeth; original design).
- Modify: `scripts/world/terrain.gd` — add `func is_sea_at(x: float) -> bool` (`height_at(x) > WATER_Y`).
- Modify: `scripts/world/world.gd` — own one `SeaMonster`; add `var hazards := true`; signal `bird_died(cause: String)` with causes `"laut"` and `"monster"`; `func clear_hazards() -> void`.
- Modify: `scripts/autoload/sfx.gd` — `_sounds["blub"]` (low bubbly tones ~200–320 Hz), `_sounds["chomp"]` (short noise + low tone).
- Modify: `scripts/ui/main_menu.gd:14`, `scripts/ui/shop.gd:19` — `world.hazards = false`.
- Test: `tests/test_hazards.gd`

**Interfaces:**
- Produces (SeaMonster): consts `WARN_TIME := 1.0`, `PEAK_ABOVE_WATER := 600.0`, `HIT_RADIUS := 70.0`; `var state: String` (`"idle" | "warn" | "jump"`); `func arm(target_x: float) -> void`; `func update(delta: float, bird_center: Vector2) -> bool` (true = bite); `func jumps_for_island(k: int) -> int` = `mini(1 + k / 2, 3)`.
- Produces (World): `signal bird_died(cause: String)`; `var hazards := true`; `func clear_hazards() -> void`; `var dead := false` (stops physics after death).
- Drowning: bird center y > `WATER_Y` while `terrain.is_sea_at(x)` → `bird_died("laut")` (splash burst + `Sfx "splash"`). With `hazards == false`: set `vel.y = -MAX_RISE` instead, no signal.
- Spawning: while the bird is over the sea and jumps remain for this sea, arm at `bird.x + bird.vel.x * (WARN_TIME + 0.55)`, spacing ≥ 1.6 s between jumps. Warning: bubbles + dark ellipse on the surface + `Sfx "blub"`. Jump: parabola from water to `WATER_Y - PEAK_ABOVE_WATER` and back in ~1.1 s, mouth open near peak; `Sfx "chomp"` on bite.

- [ ] **Step 1: Write failing tests in `tests/test_hazards.gd`** (build a real `World` with `autoplay=false`, `running=true`, `input_enabled=false`, fixed `run_seed`, then drive `_physics_process` manually):
  - `test_drown_ends`: teleport bird above the first sea, `holding=false` → `bird_died("laut")` within 4 s; `dead == true`.
  - `test_monster_bites_low_bird`: bird held at y = `WATER_Y - 150` over the sea (reset y each step) → `bird_died("monster")` within 6 s; a `"warn"` state was observed ≥ 0.9 s before the bite.
  - `test_monster_cannot_reach_high_bird`: same but y = `WATER_Y - PEAK_ABOVE_WATER - 120` for the whole sea → no death.
  - `test_jumps_scale`: `jumps_for_island(0) == 1`, `(2) == 2`, `(6) == 3`.
  - `test_no_hazards_in_menu_world`: `hazards=false`, bird pushed into water → no `bird_died`, monster stays `"idle"`, bird ends above water.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** SeaMonster, Art helper, terrain query, World wiring, sounds.
- [ ] **Step 4: Run tests** → all pass.
- [ ] **Step 5: Screenshot** `godot --path . res://scenes/game.tscn -- --island=0 --autoplay --shot=C:/…/scratchpad/monster.png --shot-delay=12` (adjust delay until a sea is on screen) and look at it: monster reads as a cute-but-dangerous creature, warning visible.

### Task 4: Run rules, HUD and texts (`game.gd`)

**Files:**
- Modify: `scripts/ui/game.gd`
- Test: `tests/test_game_rules.gd` (instantiate `res://scenes/game.tscn`, drive frames)

**Interfaces:**
- Consumes: `World.bird_died(cause)`, `World.bird_skimmed(duration)`, `World.bird_landed(bonk)`, `World.clear_hazards()`, `Bird.stamina`, `Bird.exhausted`.
- Produces (game.gd): `var end_cause := ""` (`"senja" | "laut" | "monster"`); `func _finish(cause: String) -> void`; `var skim_streak := 0`, `var best_skim := 0`.

- [ ] **Step 1: Write failing tests**
  - `test_skim_combo_fever`: emit `bird_skimmed(1.0)` ×3 → `fever_t > 0`, `style_points == 25+50+75`.
  - `test_bonk_resets_combo`: skim ×2 then `bird_landed(true)` → `skim_streak == 0`.
  - `test_death_ends_run`: emit `bird_died("monster")` → `state == "over"`, `end_cause == "monster"`, results title "Digigit monster laut!".
  - `test_continue_after_drown_is_safe`: die by `"laut"`, call `_continue_run()` → bird y ≤ `WATER_Y - 500`, `stamina == 1`, monster `"idle"`, and no `bird_died` during the next 1.5 s with `holding=false`.
  - `test_night_over_sea_ends_run`: set `time_left = 0.1` with bird over sea → run ends with `end_cause == "laut"` (sleepy bird sinks) within `NIGHT_GRACE + 4` s, or `"senja"` if it reaches land — never stays in `"night"` past that.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement**
  - `_on_landed(bonk)`: bonk → popup "Aduh!" / "Nabrak tanjakan", `Sfx "bonk"`, reset streak. Non-bonk touch resets streak silently.
  - `_on_skimmed(d)`: streak += 1; `style_points += 25 * streak`; popup "NYEREMPET!" / "NYEREMPET ×%d"; `Sfx "perfect"` pitched by streak; streak ≥ 3 → fever (existing values 6 s, +1.5 s up to 8 s). Tutorial done after 2 skims.
  - Keep "TERBANG TINGGI!": award once per flight when the bird climbs > 520 px above terrain (track in game.gd from `bird.position` vs `terrain.height_at`, reset on ground touch).
  - `_finish(cause)`; results title: `"senja"` → "Senja telah tiba", `"laut"` → "Tercebur ke laut!", `"monster"` → "Digigit monster laut!". Stats row "Mulus beruntun" → "Nyerempet beruntun" (`best_skim`).
  - `_continue_run()`: `world.clear_hazards()`, `world.dead = false`, bird y = `Terrain.WATER_Y - 600` (or ground − 200 if over land), `vel.y = 0`, `stamina = 1`, `exhausted = false`; rest unchanged.
  - Stamina bar: small rounded bar drawn in code under the time bar (`StaminaBar extends Control`, like `TimeBar`), color green → red when `exhausted`.
  - Texts: ready label "Tahan untuk naik"; hint "TAHAN untuk naik  •  LEPAS untuk turun  •  Awas monster laut!".
- [ ] **Step 4: Run tests** → all pass; headless check clean.

### Task 5: Autopilot + balance

**Files:**
- Modify: `scripts/world/world.gd` — rewrite `_ai_hold() -> bool`
- Test: balance sim

**Interfaces:**
- Consumes: `Bird.stamina`, `Bird.exhausted`, `SeaMonster.state`, `Terrain.is_sea_at`, `Terrain.height_at`.

- [ ] **Step 1: Implement `_ai_hold()`**: over land keep a target altitude ~70 px above `max(height_at(x .. x+look))` (lets it skim); hold if below target and stamina > 0.25 or monster is `"warn"`/`"jump"` ahead; over sea aim for `WATER_Y - 450`, climb above `PEAK_ABOVE_WATER` only when a warning is up. Small per-run noise (seeded) so it sometimes fails.
- [ ] **Step 2: Run sim 10×** `godot --headless --path . --fixed-fps 120 res://scenes/game.tscn -- --autoplay --sim --fresh` and collect `RUN …` lines (add `cause=%s` to the print).
  Expected: median islands 2–4; at least 1 of 10 runs ends by `laut`/`monster`; none end before island 1 by hazard. If not, tune Bird / SeaMonster constants (not the AI) and rerun.
- [ ] **Step 3: Screenshots** at `--island=0` and `--island=4` with `--shot-delay=8`; check stamina bar, skim popups, monster visible and readable.
- [ ] **Step 4: Run full test suite + headless check** → all green.
