# Lorong Kanopi Hutan (Rintangan Pulau, langkah 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Di pulau Hutan Hujan ada 2 lorong kanopi per pulau: atap dahan dan semak berduri mematikan, jalur tengah aman
dan berisi koin. Sekalian, `World` mendapat daftar `_island_hazards` yang dipakai juga oleh langkah 2–4.

**Architecture:** `Terrain` memilih bukit lorong dan mencatat `canopies`. Node baru `Canopy` (pola `Kite`) menghitung
bentuk atap/semak secara statis, menggambar, dan mengecek tabrakan. `World` menyimpan `_island_hazards: Array[Node2D]`
dengan antarmuka bersama dari spec. `game.gd` mengambil judul/saran/popup dari penyebab dan memakai `safe_x_after`
semua rintangan saat Lanjut.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar `Art.*`.

**Spec:** `docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md` (bagian "Antarmuka bersama" + "Langkah 1").

## Status

- **Selesai** di branch `feat/lorong-kanopi` (Task 1–4, 77 tes hijau).
- Bukit lorong dibuat landai (lembah 40, puncak −40) dan bukit terakhir pulau tidak dipilih. Lereng acak terlalu curam
  untuk lorong 300 px pada kecepatan fever.
- Pohon "pintu" di mulut lorong tidak dipakai karena menutup lorong secara visual.
- `hazard_passed` hanya untuk lorong yang benar-benar dimasuki burung.

## Global Constraints
- Tidak ada aset baru. Atap, pohon pintu, sulur, dan semak berduri digambar sebagai `Art.*`.
- Teks pemain bahasa Indonesia. Hindari simbol di luar subset Fredoka.
- `maxf/minf/absf/clampf` saat hasil di-assign dengan `:=`.
- Hanya biome `hutan`, `CANOPIES_PER_ISLAND = 2`, tidak di bukit 0–1, tidak berurutan.
- `GAP` awal 300 px. Semak ±40 px. Atap sampai `Bird.CEILING_HARD`.
- Popup "Awas lorong hutan!" / "Terbang di tengah, jangan sentuh duri". Kalah "Tersangkut di hutan!", saran
  "Terbang di tengah lorong: jauhi dahan dan semak berduri". Lolos "LOLOS HUTAN!" +150.
- Penyebab `"hutan"`. Sim/screenshot pakai `--nosave`.

## Review Focus
- Burung yang **lari di tanah** saat masuk lorong harus kalah karena duri, bukan lolos diam-diam → tes di Task 2.
- Lanjut setelah mati di laut tepat sebelum pulau Hutan tidak boleh menaruh burung di dalam lorong → tes rantai `safe_x_after` di Task 3.
- Burung fever (×1,3) yang mengikuti garis tengah tetap lolos → varian fever di tes jalur (Task 2).
- Dunia menu (`hazards = false`) dengan autopilot tidak mati dan tidak tersangkut → tes Task 2 + sim Task 4.
- Koin acak tidak berada di zona atap/semak → tes koin (Task 1).

---

### Task 1: Data lorong di terrain + jalur koin

**Files:**
- Modify: `scripts/world/terrain.gd` (`_generate_island`, `_place_items`, helper `_in_canopy_x`)
- Test: `tests/test_canopy.gd` (baru, helper `_world/_free` seperti `test_kites.gd`)

**Interfaces:**
- Produces: `Terrain.CANOPIES_PER_ISLAND := 2`, `Terrain.CANOPY_COINS := 8`,
  `var canopies: Array` terurut x, tiap item `{x0: float, x1: float, island: int}`. `x0` = lembah sebelum puncak,
  `x1` = lembah sesudahnya (key point lembah bukit berikutnya). RNG `run_seed * 5381 + k * 77003` → `pick_hills(hills, 2, rng)`.

- [x] **Step 1: Tes gagal:**
  - `test_canopies_only_on_hutan`: seed 4242/7/99, start 2 → pulau 0 (hutan) punya tepat 2 lorong, pulau 1–5 tidak punya; start 0 → lorong hanya di pulau `k` dengan biome `hutan`.
  - `test_canopy_spans_one_hill`: tiap lorong `x1 − x0` di [800, 1600] dan ada tepat satu puncak lokal di antaranya.
  - `test_canopy_not_first_hills`: `x0` > key puncak bukit ke-2 di pulau itu.
  - `test_canopy_coins`: tiap lorong punya tepat 8 koin dengan `x0 < x < x1`, masing-masing `|y − (height_at(x) − GAP/2)| ≤ 30`. Tidak ada koin lain di [x0, x1].
- [x] **Step 2:** `godot --headless --path . --import` lalu `godot --headless --path . res://tests/run_tests.tscn -- --only=canopy` → FAIL (`canopies` belum ada).
- [x] **Step 3: Implementasi.** Pola sama dengan `kite_hills`. Untuk bukit terpilih, `x0` = key lembah bukit itu dan
  `x1` diisi saat key lembah bukit berikutnya dibuat (atau key landasan peluncur kalau bukit terakhir). `_place_items`
  tetap memanggil `rng.randf()` untuk segmen di dalam lorong supaya urutan RNG sama, tapi koin acak tidak ditaruh.
  8 koin rata di `x0 + 0.1..0.9·(x1−x0)` dengan `y = height_at(x) − Canopy.GAP * 0.5`. `Canopy.GAP` dipakai sebagai
  konstanta, jadi buat `canopy.gd` minimal dengan `const GAP := 300.0` di task ini.
- [x] **Step 4:** `--only=canopy` PASS dan seluruh tes `failed=0`.
- [x] **Step 5: Commit** `feat(world): pick hutan canopy hills and their guide coins`

### Task 2: Node `Canopy` + daftar `_island_hazards` di World

**Files:**
- Create/Modify: `scripts/world/canopy.gd`
- Modify: `scripts/world/art.gd` (`canopy_roof`, `thorn_bush`, `giant_tree`), `scripts/world/world.gd` (`_island_hazards`, `_update_hazards`, `_die`, `clear_hazards`, view sync, autopilot `_ai_hold`)
- Test: `tests/test_canopy.gd`

**Interfaces:**
- Consumes: `terrain.canopies` (Task 1).
- Produces (antarmuka bersama, dipakai langkah 2–4):
  - `class_name Canopy extends Node2D`, `const CAUSE := "hutan"`, `const GAP := 300.0`, `const THORN_H := 40.0`,
    `const BIRD_R := 16.0`, `const SPOT_DIST := 1400.0`, `signal spotted`, `signal passed`
  - `static func roof_y(terrain: Terrain, x: float) -> float` (tepi bawah atap yang dihaluskan, = `height_at − GAP` dirata-rata ±60 px)
  - `static func span(c: Dictionary) -> Vector2` (= `(x0, x1)`)
  - `static func hits(terrain: Terrain, c: Dictionary, p: Vector2, on_ground: bool) -> bool`: true kalau x di span dan
    (`p.y − BIRD_R < roof_y` atau `on_ground` atau `p.y > height_at(p.x) − THORN_H`)
  - `func update(delta: float, bird_center: Vector2, bird_x: float, bird_on_ground: bool) -> bool`
  - `func safe_x_after(x: float) -> float` (x di `[x0 − 200, x1]` → `x1 + 200`), `func reset_current() -> void`
  - `var terrain`, `var view_left`, `var view_right`, `var hit_color: Color`
  - `World._island_hazards: Array[Node2D]`, `signal hazard_spotted(cause: String)`, `signal hazard_passed(cause: String)`,
    `func safe_x_after(x: float) -> float` di World (rantai `wave`, `kite`, semua `_island_hazards`, `dry_ground_after`,
    diulang sampai x tetap)

- [x] **Step 1: Tes gagal:**
  - `test_canopy_center_path_passes`: tiap lorong pada seed 4242/7/99, burung dimulai 600 px sebelum `x0` dengan input
    "tahan" yang mengejar `height_at − GAP/2` (pengendali sederhana di tes, lewat `_touch_hold` seperti `test_kites`) pada
    kecepatan `SPEED_START`, `SPEED_MAX`, dan fever → tidak mati, dan `hazard_passed("hutan")` terpancar sekali.
  - `test_canopy_ground_run_dies`: burung lari di tanah memasuki lorong → `bird_died("hutan")`.
  - `test_canopy_roof_dies`: burung terbang rata di `roof_y(x0 + 100) − 40` → `bird_died("hutan")`.
  - `test_canopy_safe_in_menu`: `hazards = false` dan autopilot melewati 2 pulau Hutan → tidak pernah `dead`.
  - `test_autopilot_clears_canopies`: `hazards = true` dan autopilot di start island 2 sampai pulau 1 → tidak mati.
- [x] **Step 2:** `--only=canopy` → FAIL.
- [x] **Step 3: Implementasi `Canopy`** meniru `Kite` (indeks `_first`, `spotted` sekali, gambar hanya `view_left..view_right`).
  Atap: polygon dari `roof_y` ke `CEILING_HARD − 400`, ditambah sulur yang menjuntai (hiasan, di atas `roof_y`, tidak
  mematikan). `passed` dipancarkan saat `bird_x > x1 + 40`. Di `World._ready`: buat `Canopy`, masukkan ke
  `_island_hazards`, sambungkan `spotted/passed` ke `hazard_spotted/hazard_passed` (hanya saat `hazards`).
  `_update_hazards` memanggil `update` untuk semua item lalu `_die(h.CAUSE)`. `_die("hutan")`: getar 0,8, `Sfx.play("bonk")`,
  semburan daun `Ambient.burst` warna `hill_top`. `clear_hazards` memanggil `reset_current`. `_ai_hold`: kalau x ada di
  `[x0 − 500, x1]` sebuah lorong, target = `height_at(x_depan) − GAP/2`, dengan `x_depan = x + vel.x·0,35`.
- [x] **Step 4:** `--only=canopy` PASS, semua tes `failed=0`.
- [x] **Step 5: Commit** `feat(world): hutan canopy tunnel hazard and shared island hazard list`

### Task 3: Aturan game (judul, saran, popup, lolos, Lanjut)

**Files:**
- Modify: `scripts/ui/game.gd` (`CAUSE_TITLES`, `CAUSE_TIPS`, const baru `HAZARD_POPUPS`/`HAZARD_PASS`, handler `hazard_spotted/passed`, `_continue` memakai `world.safe_x_after`)
- Test: `tests/test_game_rules.gd`

**Interfaces:**
- Consumes: `World.hazard_spotted/hazard_passed(cause)`, `World.safe_x_after(x)` (Task 2).
- Produces: `const HAZARD_POPUPS := {"hutan": ["Awas lorong hutan!", "Terbang di tengah, jangan sentuh duri"]}`,
  `const HAZARD_PASS := {"hutan": ["LOLOS HUTAN!", 150]}` (langkah 2–4 cukup menambah entri).

- [x] **Step 1: Tes gagal:** `test_hutan_death_title` (judul "Tersangkut di hutan!", saran sesuai spec);
  `test_hutan_pass_points` (`hazard_passed("hutan")` → `style_points` +150); `test_continue_skips_canopy` (mati di laut
  tepat sebelum pulau Hutan yang lorong pertamanya < 200 px dari tanah kering → burung muncul setelah `x1 + 200`, skor tidak turun).
- [x] **Step 2:** `--only=hutan` dan `--only=continue` → FAIL.
- [x] **Step 3: Implementasi** sesuai Interfaces. Popup "Awas" memakai `Color("#b8ff8a")`. `_on_kite_spotted` dan
  `_on_wave_passed` tetap ada (tidak dirombak).
- [x] **Step 4:** tes PASS, semua `failed=0`.
- [x] **Step 5: Commit** `feat(game): hutan death title, warning popup, pass points, continue past canopies`

### Task 4: Verifikasi, screenshot, dokumen

**Files:**
- Modify: `CLAUDE.md` (baris hazard + perintah screenshot Hutan), spec (angka akhir langkah 1), plan ini (status)

- [x] **Step 1:** Cek wajib (import, `TESTS ... failed=0`, headless `--quit-after 600` tanpa `SCRIPT ERROR`/`ERROR`).
- [x] **Step 2:** Sim `godot --headless --path . --fixed-fps 120 res://scenes/game.tscn -- --island=2 --seed=11 --autoplay --sim --fresh --nosave`, lalu ulangi dengan `--seed=4242` → keduanya `cause=batas`.
- [x] **Step 3:** Cari seed/delay yang memperlihatkan mulut lorong di tepi kanan layar (`--island=2 --seed=4242 --shot=out.png --shot-delay=…`), lihat gambarnya, perbaiki keterbacaan kalau perlu, dan catat perintahnya di CLAUDE.md.
- [x] **Step 4:** Tulis "Angka akhir langkah 1" di spec, centang plan, dan set status selesai.
- [x] **Step 5: Commit** `docs: canopy step notes, plan status`, lalu push + PR sesuai CLAUDE.md.
