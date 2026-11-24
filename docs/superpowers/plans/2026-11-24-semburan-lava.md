# Semburan Lava Gunung Api (Rintangan Pulau, langkah 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Di pulau Gunung Api ada 3 kawah per pulau. Kawah berasap, lalu menyala, lalu menyemburkan tiang lava yang
harus dilewati dengan melambung. Ada busur koin di atas tiang.

**Architecture:** `Terrain` memilih lembah kawah (diperdalam) dan mencatat `vents`. Node `LavaVent` mengikuti
antarmuka bersama dari langkah 1 (`World._island_hazards`). Fase semburan dipicu **jarak** burung ke kawah
(pola `Wave`), dan bentuk tiang adalah fungsi statis dari `(vent, tinggi)`.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar `Art.*`, suara sintesis `Sfx`.

**Spec:** `docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md` (bagian "Langkah 2").

**Butuh:** langkah 1 (`2026-11-24-lorong-kanopi.md`) sudah di-merge. Antarmuka bersama, `World.safe_x_after`,
`HAZARD_POPUPS`, dan `HAZARD_PASS` berasal dari sana.

## Status

- Belum dimulai.

## Global Constraints
- Hanya biome `gunung`, `VENTS_PER_ISLAND = 3`, tidak di bukit 0–1, tidak berurutan. Dasar lembah kawah ≥ y 150.
- Jarak picu: asap 2400 px, menyala 1500 px, naik 800 px, penuh saat 300 px. Surut 0,9 dtk setelah lewat.
- Tiang lebar ±120 px (`COL_HW = 60`), puncak = `minf(puncak kiri, puncak kanan) − 260` (y lebih kecil = lebih tinggi).
- Bara di puncak tiang hanya hiasan. Busur 8 koin di atas tiang.
- Popup "Awas lava!" / "Saat kawah menyala, tahan untuk naik". Kalah "Tersembur lava!", saran
  "Tahan lebih awal saat kawah menyala, lalu terbang di atas semburan". Lolos "LOLOS LAVA!" +150.
- Penyebab `"lava"`. Teks bahasa Indonesia, tanpa simbol di luar Fredoka, tanpa aset gambar.

## Review Focus
- Dua kawah berdekatan (dipisah satu bukit) tidak boleh membuat tiang meletup atau kehilangan fase → batasi perubahan tinggi per detik seperti `Wave.RISE_SPEED`, dan tes dua kawah di Task 2.
- Burung yang **sudah tinggi** sebelum kawah menyala tetap lolos (tidak ada tiang yang "mengejar" ke atas) → tes Task 2.
- Lanjut setelah mati di tiang → burung muncul setelah kawah + 200 px dan tiang di-reset → tes Task 3.
- Burung yang mati di laut dan muncul tepat sebelum kawah tidak langsung kena semburan penuh → `safe_x_after` mendorong x melewati `[vent.x − 800, vent.x + COL_HW]` → tes Task 3.
- Autopilot tidak terlempar ke atap langit (`CEILING_SOFT`) karena mengejar puncak tiang → tes Task 2.

---

### Task 1: Data kawah di terrain + busur koin

**Files:**
- Modify: `scripts/world/terrain.gd`
- Create: `scripts/world/lava_vent.gd` (konstanta saja di task ini)
- Test: `tests/test_lava.gd` (baru)

**Interfaces:**
- Produces: `Terrain.VENTS_PER_ISLAND := 3`, `Terrain.VENT_COINS := 8`, `Terrain.VENT_FLOOR_Y := 150.0`,
  `var vents: Array` terurut x, item `{x: float, floor_y: float, top_y: float, island: int}`, dengan
  `top_y = minf(peak_before_y, peak_after_y) − LavaVent.RISE_ABOVE`. RNG `run_seed * 6907 + k * 81031`.
  `LavaVent.RISE_ABOVE := 260.0`, `LavaVent.COL_HW := 60.0`.

- [ ] **Step 1: Tes gagal:** `test_vents_only_on_gunung` (start 3 → pulau 0 punya 3, pulau lain bukan gunung 0);
  `test_vent_in_valley` (`floor_y == height_at(x)` ±1, `floor_y ≥ 150`, dan tanah di x ± 300 tidak lebih rendah dari `floor_y`);
  `test_vent_top_above_peaks` (`top_y ≤` puncak terdekat di kiri dan kanan − 260); `test_vent_coin_arc` (tepat 8 koin di
  `|x − vent.x| ≤ 260`, semuanya `y < top_y − 60`, dan tidak ada koin lain di dalam kolom `vent.x ± COL_HW + 40`).
- [ ] **Step 2:** import + `--only=lava` → FAIL.
- [ ] **Step 3: Implementasi.** Untuk bukit terpilih, y lembah = `maxf(vy, VENT_FLOOR_Y)`. `top_y` diisi setelah puncak
  sesudahnya dibuat. Koin busur di `x = vent.x + u·240`, `y = top_y − 140 + u²·80`, dengan `u` rata dari −1 ke 1.
  Pertahankan urutan panggilan RNG.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): pick gunung lava vents and their coin arcs`

### Task 2: Node `LavaVent` (fase, bentuk, gambar, autopilot)

**Files:**
- Modify: `scripts/world/lava_vent.gd`, `scripts/world/art.gd` (`lava_column`, `vent_mouth`, `smoke_puff`), `scripts/world/world.gd` (daftarkan ke `_island_hazards`, `_die("lava")`, `_ai_hold`), `scripts/autoload/sfx.gd` (`"rumble"`)
- Test: `tests/test_lava.gd`

**Interfaces:**
- Consumes: antarmuka bersama langkah 1, `terrain.vents`.
- Produces: `class_name LavaVent extends Node2D`, `const CAUSE := "lava"`, `SMOKE_DIST := 2400.0`, `GLOW_DIST := 1500.0`,
  `RISE_DIST := 800.0`, `FULL_DIST := 300.0`, `RECEDE_TIME := 0.9`, `RISE_SPEED := 2400.0`, `BIRD_R := 16.0`;
  `static func target_height(v: Dictionary, ahead: float) -> float` (0..1 dari jarak `ahead = v.x − bird_x`);
  `static func column_rect(v: Dictionary, h: float) -> Rect2` (dari `floor_y` ke `lerpf(floor_y, top_y, h)`, lebar `2·COL_HW`);
  `static func hits(v: Dictionary, h: float, p: Vector2) -> bool` (jarak titik ke kotak < `BIRD_R`);
  `func phase_of(i: int) -> String` (`"idle"|"smoke"|"glow"|"erupt"|"recede"`); `func update(...)`, `safe_x_after`, `reset_current` sesuai antarmuka bersama.

- [ ] **Step 1: Tes gagal:**
  - `test_vent_phases_by_distance`: `target_height` = 0 di ahead 900, > 0 di 700, = 1 di ≤ 300. `phase_of` "glow" pada ahead 1400.
  - `test_vent_hold_from_glow_passes`: tiap kawah (seed 4242/7/99, start 3), burung datang dari puncak sebelumnya dan
    menahan sejak ahead ≤ 1500 sampai `y < top_y − 60`, lalu lepas. Diuji di `SPEED_START`, `SPEED_MAX`, fever →
    tidak mati, `hazard_passed("lava")` sekali.
  - `test_vent_glide_dies`: burung hanya meluncur dari puncak sebelumnya → `bird_died("lava")`.
  - `test_vent_high_bird_safe`: burung terbang rata di `top_y − 200` → tidak mati.
  - `test_two_close_vents`: buat dua vent berjarak 1300 px secara manual di dunia uji. Tinggi tiang kedua tidak pernah
    berubah lebih dari `RISE_SPEED·dt` per frame.
  - `test_autopilot_clears_vents`: autopilot `hazards = true` start 3 sampai pulau 1 → tidak mati, dan `bird.position.y > Bird.CEILING_SOFT` sepanjang jalan.
  - `test_vents_safe_in_menu`: `hazards = false` → tidak pernah `dead`.
- [ ] **Step 2:** `--only=vent` → FAIL.
- [ ] **Step 3: Implementasi** pola `Wave`: tinggi tiap kawah dalam `_heights[i]`, `move_toward` ke `target_height` dengan
  `RISE_SPEED / (floor_y − top_y)`. `recede` mulai saat `bird_x > x + COL_HW + 40`, yang juga memancarkan `passed`.
  `Sfx.play("fizz")` saat masuk glow, `Sfx.play("rumble")` saat erupt (rumble = noise 0,8 dtk + nada 70 Hz).
  `_die("lava")`: getar 1,0, burst oranye `#ff6a2c`. `_ai_hold`: saat ada kawah dengan ahead ≤ 1500 →
  target = `top_y − 120`.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): gunung lava vents with smoke, glow and eruption`

### Task 3: Aturan game

**Files:**
- Modify: `scripts/ui/game.gd` (`CAUSE_TITLES/TIPS`, `HAZARD_POPUPS`, `HAZARD_PASS`)
- Test: `tests/test_game_rules.gd`

- [ ] **Step 1: Tes gagal:** `test_lava_death_title`, `test_lava_pass_points` (+150), `test_continue_skips_vent`
  (mati di tiang → x baru ≥ `vent.x + COL_HW + 200`, tiang kawah itu tinggi 0, skor tidak turun),
  `test_continue_before_vent` (mati di laut dengan tanah kering < 800 px sebelum kawah pertama → x baru melewati kawah).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi:** tambah entri sesuai Global Constraints. Popup warna `Color("#ffb04a")`. `LavaVent.safe_x_after`
  mendorong x di `[x − RISE_DIST, x + COL_HW]` ke `x + COL_HW + 200`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(game): lava death title, warning popup, pass points, continue past vents`

### Task 4: Verifikasi, screenshot, dokumen

- [ ] **Step 1:** Cek wajib bersih.
- [ ] **Step 2:** Sim `--island=3` dengan seed 11 dan 4242 → `cause=batas`.
- [ ] **Step 3:** Screenshot `--island=3 --seed=4242`, dengan delay saat kawah menyala dan saat semburan penuh. Lihat gambarnya dan catat perintahnya di CLAUDE.md.
- [ ] **Step 4:** Tulis "Angka akhir langkah 2" di spec, centang plan, dan set status selesai.
- [ ] **Step 5: Commit** `docs: lava step notes, plan status`, lalu push + PR.
