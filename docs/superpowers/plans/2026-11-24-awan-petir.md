# Gerbang Awan Petir (Rintangan Pulau, langkah 4) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Di Negeri Awan ada 3 gerbang awan petir per pulau. Dua awan gelap (bawah dari tanah, atas sampai langit)
menyisakan celah terang setinggi 260 px yang tingginya berbeda di tiap gerbang. Ada koin di tengah celah.

**Architecture:** `Terrain` memilih puncak gerbang dan tinggi celah (`storm_gates`). Node `StormGate` mengikuti
antarmuka bersama langkah 1. Bentuknya statis (hanya goyang hiasan ±10 px, celah tetap), jadi tabrakan cukup dengan
cek kotak.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar `Art.*`, suara sintesis `Sfx`.

**Spec:** `docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md` (bagian "Langkah 4").

**Butuh:** langkah Petualangan dan Misi (`2026-11-24-peta-petualangan.md`, `2026-11-24-misi.md`) dan langkah 1 sudah di-merge.

## Status

- Belum dimulai.

## Global Constraints
- Hanya biome `awan`, `GATES_PER_ISLAND = 3`, tidak di bukit 0–1, tidak berurutan.
- Celah 260 px (`GAP_H`), pusat celah acak di `[peak_y − 620, peak_y − 220]`. Tebal gerbang ±160 px (`HALF_W = 80`).
- Awan atas digambar sampai tepi atas layar. Tabrakannya sampai `Bird.CEILING_HARD`. Awan bawah dari tanah.
- Kilat tiap ±1,2 dtk dan goyang ±10 px hanya hiasan. Tepi celah dipakai untuk tabrakan tanpa goyang.
- 5 koin di tengah celah.
- Popup "Awas awan petir!" / "Lewat celah terang di antaranya". Kalah "Tersambar petir!", saran
  "Bidik celah terang sejak awan terlihat". Lolos "LOLOS PETIR!" +100.
- Penyebab `"petir"`.

## Review Focus
- Celah paling tinggi (`peak_y − 620`) harus terjangkau dari lembah sebelumnya dengan stamina yang tersisa setelah gerbang sebelumnya → tes dua gerbang berjarak minimum (selisih 2 bukit) dengan celah rendah lalu tinggi di Task 2.
- Burung yang lari di tanah menabrak awan bawah (kalah, bukan menembus) → tes Task 2.
- Gambar goyang ±10 px tidak boleh membuat burung yang menyentuh awan yang terlihat tetap selamat terlalu jauh: radius tabrakan ≤ 6 px lebih kecil dari gambar diam → cek di screenshot Task 4.
- Lanjut di depan gerbang → burung muncul setelah gerbang + 200 px → tes Task 3.
- Autopilot membidik celah tanpa memantul ke atap langit → tes Task 2.

---

### Task 1: Data gerbang + koin celah

**Files:**
- Modify: `scripts/world/terrain.gd`
- Create: `scripts/world/storm_gate.gd` (konstanta saja)
- Test: `tests/test_storm.gd` (baru)

**Interfaces:**
- Produces: `Terrain.GATES_PER_ISLAND := 3`, `Terrain.GATE_COINS := 5`, `var storm_gates: Array` terurut x, item
  `{x: float, peak_y: float, gap_y: float, island: int}` (`gap_y` = pusat celah). RNG `run_seed * 8017 + k * 99991`.
  `StormGate.GAP_H := 260.0`, `StormGate.HALF_W := 80.0`, `StormGate.GAP_MIN_ABOVE := 220.0`, `StormGate.GAP_MAX_ABOVE := 620.0`.

- [ ] **Step 1: Tes gagal:** `test_gates_only_on_awan` (start 5 → pulau 0 punya 3); `test_gate_gap_range`
  (`peak_y − 620 ≤ gap_y ≤ peak_y − 220`, dan `gap_y − GAP_H/2 > Bird.CEILING_SOFT + 100`); `test_gate_gap_varies`
  (dalam 10 seed, rentang `peak_y − gap_y` ≥ 250 px); `test_gate_coins` (5 koin di `x ± HALF_W`, `|y − gap_y| ≤ 40`,
  dan tidak ada koin lain di `x ± (HALF_W + 60)`).
- [ ] **Step 2:** import + `--only=gate` → FAIL.
- [ ] **Step 3: Implementasi** pola `kite_hills`. `gap_y = peak_y − rng.randf_range(220, 620)`.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): pick awan storm gates and their gap coins`

### Task 2: Node `StormGate` (tabrakan, gambar, autopilot)

**Files:**
- Modify: `scripts/world/storm_gate.gd`, `scripts/world/art.gd` (`storm_cloud`, `lightning_bolt`, `gap_glow`), `scripts/world/world.gd` (daftar, `_die("petir")`, `_ai_hold`), `scripts/autoload/sfx.gd` (`"thunder"`)
- Test: `tests/test_storm.gd`

**Interfaces:**
- Consumes: antarmuka bersama, `terrain.storm_gates`.
- Produces: `class_name StormGate extends Node2D`, `const CAUSE := "petir"`, `const BIRD_R := 16.0`,
  `const SPOT_DIST := 1400.0`, `const FLASH_EVERY := 1.2`;
  `static func gap_top(g) -> float`, `static func gap_bottom(g) -> float`;
  `static func hits(g: Dictionary, p: Vector2) -> bool` (`|p.x − g.x| < HALF_W + BIRD_R` dan (`p.y − BIRD_R < gap_top` atau `p.y + BIRD_R > gap_bottom`));
  `update/safe_x_after/reset_current` sesuai antarmuka bersama.

- [ ] **Step 1: Tes gagal:**
  - `test_gate_aim_passes`: tiap gerbang (seed 4242/7/99, start 5), burung mulai membidik `gap_y` (pengendali tahan
    sederhana) saat `g.x − bird_x ≤ 1300`. Diuji di `SPEED_START`, `SPEED_MAX`, fever → lolos, mengumpulkan ≥ 4 koin,
    `hazard_passed("petir")` sekali.
  - `test_gate_low_then_high`: dunia uji dengan dua gerbang buatan berjarak 2 bukit (celah `peak_y − 220` lalu
    `peak_y − 620`), stamina mulai 0,6 → pengendali yang sama lolos di keduanya.
  - `test_gate_ground_run_dies` dan `test_gate_above_dies` (terbang rata di `gap_top − 60`) → `bird_died("petir")`.
  - `test_autopilot_clears_gates` (posisi tidak pernah < `CEILING_SOFT`) dan `test_gates_safe_in_menu`.
- [ ] **Step 2:** `--only=gate` → FAIL.
- [ ] **Step 3: Implementasi** pola `Kite`. Kilat: pilih ruas acak per gerbang tiap `FLASH_EVERY` (hiasan). `passed` dipancarkan
  saat `bird_x > x + HALF_W + 40`. `Sfx.play("thunder")` (noise 1,0 dtk dengan envelope turun + nada 55 Hz) saat gerbang pertama
  terlihat dan pelan (pitch 0,8) di gerbang lain. `_die("petir")`: getar 1,0, layar putih kilat singkat lewat `Ambient.burst` putih/kuning.
  `_ai_hold`: gerbang dengan `g.x − x ≤ 1500` → target `gap_y`.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): awan storm cloud gates`

### Task 3: Aturan game

**Files:** `scripts/ui/game.gd`, `tests/test_game_rules.gd`

- [ ] **Step 1: Tes gagal:** `test_petir_death_title`, `test_petir_pass_points` (+100), `test_continue_skips_gate`
  (x baru ≥ `g.x + HALF_W + 200`, skor tidak turun).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi:** entri judul/saran/popup (warna `Color("#ffe066")`)/lolos. `safe_x_after` mendorong x di
  `[g.x − 200 − HALF_W, g.x + HALF_W]` ke `g.x + HALF_W + 200`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(game): storm death title, warning popup, pass points, continue past gates`

### Task 3b: Buka level Awan + misi

**Files:**
- Modify: `scripts/data/levels.gd` (`READY_ISLANDS` + `"awan"`, seed level awan-1..3 dikunci), `scripts/data/missions.gd` (templat `pass_petir`: "Lolos %d gerbang petir", target 3, hadiah 75, `island: "awan"`)
- Test: `tests/test_levels.gd`, `tests/test_missions.gd`

- [ ] **Step 1: Tes gagal:** `test_awan_levels_ready` (`Levels.is_ready` untuk `awan-1..3`; jumlah rintangan pulau 0 = tingkatnya: 1/2/3);
  `test_awan_mission_available` (`Missions.available` untuk templat `pass_petir` = true); `test_ready_levels_completable` mencakup level awan.
  `hazard_passed("petir")` menaikkan `pass` dan `pass_petir`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi.** Jumlah rintangan pulau level memakai `terrain.level_hazards` seperti layangan/ombak/lorong.
  Pilih seed awan-1..3 lewat sim `--level=awan-N --autoplay --sim` sampai `cause=selesai`. Tombol Lanjut di layar selesai level Badai
  pulau sebelumnya otomatis aktif (pulau ini sekarang siap), dan tes `test_level_done_buttons` disesuaikan.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(game): unlock awan levels and petir missions`

### Task 4: Verifikasi, screenshot, dokumen

- [ ] **Step 1:** Cek wajib bersih.
- [ ] **Step 2:** Sim level `--level=awan-1/2/3` → `cause=selesai`, lalu sim `--island=5` dengan seed 11 dan 4242 → `cause=batas`.
- [ ] **Step 3:** Screenshot `--island=5 --seed=4242` saat gerbang di tengah layar. Awan gelap harus kontras dengan langit pastel, dan celahnya harus terbaca. Catat perintahnya di CLAUDE.md.
- [ ] **Step 4:** Tulis "Angka akhir langkah 4" di spec, centang plan, dan set status selesai.
- [ ] **Step 5: Commit** `docs: storm step notes, plan status`, lalu push + PR.
