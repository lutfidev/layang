# Kawanan Kelelawar Danau (Rintangan Pulau, langkah 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Di pulau Danau Kunang-kunang ada 3 kawanan kelelawar per pulau. Tiap kawanan berupa pita mendatar
(rendah atau tinggi) yang terbang ke kiri mendekati burung, dengan mata kuning menyala sebagai tanda. Jalur aman
yang berlawanan berisi koin.

**Architecture:** `Terrain` memilih puncak kawanan, jenis pita, dan koin jalur aman (`bat_flocks`). Node `BatFlock`
mengikuti antarmuka bersama langkah 1. Posisi kawanan = fungsi statis dari waktu sejak aktif. Kawanan aktif saat
masuk tepi kanan layar.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar `Art.*`, suara sintesis `Sfx`.

**Spec:** `docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md` (bagian "Langkah 3").

**Butuh:** langkah Petualangan dan Misi (`2026-11-24-peta-petualangan.md`, `2026-11-24-misi.md`) dan langkah 1 sudah di-merge (antarmuka bersama). Langkah 2 tidak wajib.

## Status

- Belum dimulai.

## Global Constraints
- Hanya biome `danau`, `FLOCKS_PER_ISLAND = 3`, tidak di bukit 0–1, tidak berurutan.
- 7 kelelawar per kawanan dalam pita ±320 × 90 px. Pusat pita `peak_y − 150` (rendah) atau `peak_y − 400` (tinggi).
- Kecepatan kawanan 150 px/dtk ke kiri. Kepakan ±12 px per kelelawar. Pita tidak pernah pindah ketinggian dan tidak mengejar.
- 6 koin di jalur aman (di atas pita rendah, di bawah pita tinggi).
- Popup "Awas kelelawar!" / "Lihat matanya, lewat di atas atau di bawah". Kalah "Ditabrak kelelawar!", saran
  "Lihat ketinggian kawanan dari jauh, lalu lewat di atas atau di bawahnya". Lolos "LOLOS KAWANAN!" +100.
- Penyebab `"kelelawar"`.

## Review Focus
- Kawanan bergerak, jadi koin jalur aman harus tetap aman di **seluruh** rentang kecepatan burung → tes jalur aman yang mengumpulkan koin di Task 2.
- Kawanan yang aktif jauh sebelum burung (misalnya burung lambat di awal) tidak boleh "menunggu" atau keluar dari jalur puncak → titik temu dihitung dari kecepatan burung saat aktivasi, tes di Task 2.
- Lanjut di dekat kawanan: kawanan yang sedang terbang dinonaktifkan (`reset_current`) atau burung dipindah melewatinya → tes Task 3.
- Burung yang lari di tanah di bawah pita tinggi tetap aman → tes Task 2.
- Pita rendah di puncak rendah tidak boleh menyentuh tanah (selalu ≥ 60 px di atas tanah di seluruh lebarnya) → tes penempatan Task 1.

---

### Task 1: Data kawanan di terrain + koin jalur aman

**Files:**
- Modify: `scripts/world/terrain.gd`
- Create: `scripts/world/bat_flock.gd` (konstanta saja)
- Test: `tests/test_bats.gd` (baru)

**Interfaces:**
- Produces: `Terrain.FLOCKS_PER_ISLAND := 3`, `Terrain.FLOCK_COINS := 6`, `var bat_flocks: Array` terurut x, item
  `{x: float, peak_y: float, band_y: float, high: bool, island: int}`. `x` = x puncak (titik temu), `band_y` = pusat pita.
  RNG `run_seed * 7451 + k * 93719` (bukit + jenis: `rng.randf() < 0.5` → tinggi).
  `BatFlock.BAND_HW := 160.0`, `BatFlock.BAND_HH := 45.0`, `BatFlock.SPEED := 150.0`, `BatFlock.COUNT := 7`,
  `BatFlock.LOW_ABOVE := 150.0`, `BatFlock.HIGH_ABOVE := 400.0`.

- [ ] **Step 1: Tes gagal:** `test_flocks_only_on_danau` (start 4 → pulau 0 punya 3); `test_flock_band_heights`
  (`band_y == peak_y − 150` atau `− 400`, cocok dengan `high`; tiap seed 1..50 punya minimal satu dari tiap jenis di
  dua pulau Danau pertama, atau tes mencatat proporsi ≥ 25 % untuk tiap jenis); `test_low_band_clear_of_ground`
  (`band_y + BAND_HH + 60 ≤ height_at(x')` untuk x' di `x ± (BAND_HW + 300)`); `test_flock_coins` (6 koin di `x ± 200`,
  di atas pita rendah: `y < band_y − BAND_HH − 70`, di bawah pita tinggi: `band_y + BAND_HH + 70 < y < height_at − 40`).
- [ ] **Step 2:** import + `--only=flock` → FAIL.
- [ ] **Step 3: Implementasi.** Pola `kite_hills`. Koin ditaruh statis di sekitar titik temu: kawanan ada di sana saat
  burung tiba, jadi koin di sisi aman. Busur acak biasa tidak boleh ada di `x ± 400`.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): pick danau bat flocks and their safe-side coins`

### Task 2: Node `BatFlock` (gerak, tabrakan, gambar, autopilot)

**Files:**
- Modify: `scripts/world/bat_flock.gd`, `scripts/world/art.gd` (`bat`, mata menyala dengan halo aditif), `scripts/world/world.gd` (daftar, `_die("kelelawar")`, `_ai_hold`), `scripts/autoload/sfx.gd` (`"squeak"`)
- Test: `tests/test_bats.gd`

**Interfaces:**
- Consumes: antarmuka bersama, `terrain.bat_flocks`.
- Produces: `class_name BatFlock extends Node2D`, `const CAUSE := "kelelawar"`, `const BIRD_R := 16.0`, `const BAT_R := 14.0`;
  `static func center_x(f: Dictionary, start_x: float, t: float) -> float` (= `start_x − SPEED·t`);
  `static func bat_positions(f: Dictionary, cx: float, t: float) -> PackedVector2Array` (7 titik dengan offset tetap di pita + kepakan `sin`);
  `static func start_x_for(f: Dictionary, bird_x: float, bird_speed: float) -> float` (posisi awal supaya `center_x = f.x`
  saat burung tiba di `f.x`: `f.x + SPEED·(f.x − bird_x)/bird_speed`);
  `static func hits(positions: PackedVector2Array, p: Vector2) -> bool` (jarak < `BAT_R + BIRD_R`);
  `update/safe_x_after/reset_current` sesuai antarmuka bersama. Aktivasi saat `start_x_for(...) − BAND_HW < view_right + 200`.

- [ ] **Step 1: Tes gagal:**
  - `test_flock_meets_at_peak`: burung kecepatan tetap 500 dan 740, aktivasi → saat `bird_x == f.x`, `|center_x − f.x| < 40`.
  - `test_flock_band_never_moves_vertically`: semua `bat_positions` selama 3 dtk berada di `band_y ± (BAND_HH + 12)`.
  - `test_safe_path_passes`: tiap kawanan (seed 4242/7/99, start 4), burung lewat di jalur koin. Pita rendah: tahan ke
    `band_y − BAND_HH − 90`. Pita tinggi: menyusuri bukit atau lari di tanah. Diuji di `SPEED_START`, `SPEED_MAX`,
    fever → tidak mati, mengumpulkan ≥ 5 dari 6 koin, `hazard_passed("kelelawar")` sekali.
  - `test_band_height_dies`: burung terbang rata di `band_y` → `bird_died("kelelawar")`.
  - `test_autopilot_clears_flocks` dan `test_flocks_safe_in_menu` (sama seperti langkah sebelumnya).
- [ ] **Step 2:** `--only=flock` → FAIL.
- [ ] **Step 3: Implementasi.** Simpan `{start_x, t}` per kawanan aktif di dictionary yang diindeks i. `passed` dipancarkan
  saat `bird_x > center_x + BAND_HW + 40`. Kawanan keluar dari gambar setelah melewati `view_left − 300`.
  `Sfx.play("squeak")` (dua nada pendek 2,6 kHz/3,1 kHz) saat aktivasi. `_ai_hold`: kawanan dengan `|f.x − x| < 900`.
  Pita rendah → target `band_y − BAND_HH − 90`. Pita tinggi → perilaku menyusuri biasa, dengan batas atas
  `band_y + BAND_HH + 60`.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): danau bat flocks flying in fixed bands`

### Task 3: Aturan game

**Files:** `scripts/ui/game.gd`, `tests/test_game_rules.gd`

- [ ] **Step 1: Tes gagal:** `test_bats_death_title`, `test_bats_pass_points` (+100), `test_continue_skips_flock`
  (mati di kawanan → x baru ≥ `f.x + BAND_HW + 200`, kawanan itu tidak aktif lagi, skor tidak turun).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi:** entri `CAUSE_TITLES/TIPS`, `HAZARD_POPUPS` (warna `Color("#d9ff7a")`), dan `HAZARD_PASS`.
  `BatFlock.safe_x_after` mendorong x di `[f.x − 900, f.x + BAND_HW]` ke `f.x + BAND_HW + 200` dan menandai kawanan selesai.
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(game): bat death title, warning popup, pass points, continue past flocks`

### Task 3b: Buka level Danau + misi

**Files:**
- Modify: `scripts/data/levels.gd` (`READY_ISLANDS` + `"danau"`, seed level danau-1..3 dikunci), `scripts/data/missions.gd` (templat `pass_kelelawar`: "Lolos %d kawanan kelelawar", target 3, hadiah 75, `island: "danau"`)
- Test: `tests/test_levels.gd`, `tests/test_missions.gd`

- [ ] **Step 1: Tes gagal:** `test_danau_levels_ready` (`Levels.is_ready` untuk `danau-1..3`; jumlah rintangan pulau 0 = tingkatnya: 1/2/3);
  `test_danau_mission_available` (`Missions.available` untuk templat `pass_kelelawar` = true); `test_ready_levels_completable` mencakup level danau.
  `hazard_passed("kelelawar")` menaikkan `pass` dan `pass_kelelawar`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi.** Jumlah rintangan pulau level memakai `terrain.level_hazards` seperti layangan/ombak/lorong.
  Pilih seed danau-1..3 lewat sim `--level=danau-N --autoplay --sim` sampai `cause=selesai`. Tombol Lanjut di layar selesai level Badai
  pulau sebelumnya otomatis aktif (pulau ini sekarang siap), dan tes `test_level_done_buttons` disesuaikan.
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(game): unlock danau levels and kelelawar missions`

### Task 4: Verifikasi, screenshot, dokumen

- [ ] **Step 1:** Cek wajib bersih.
- [ ] **Step 2:** Sim level `--level=danau-1/2/3` → `cause=selesai`, lalu sim `--island=4` dengan seed 11 dan 4242 → `cause=batas`.
- [ ] **Step 3:** Screenshot `--island=4 --seed=4242`: satu saat mata kawanan muncul di tepi kanan, satu saat burung lewat. Lihat gambarnya (mata harus terbaca di langit malam) dan catat perintahnya di CLAUDE.md.
- [ ] **Step 4:** Tulis "Angka akhir langkah 3" di spec, centang plan, dan set status selesai.
- [ ] **Step 5: Commit** `docs: bat step notes, plan status`, lalu push + PR.
