# Peta Petualangan (18 level) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Mode Petualangan: 18 level (6 pulau × Pagi/Ramai/Badai), tiap level satu pulau dengan seed tetap sampai
gerbang candi, 3 bintang, peta level, dan layar "Level selesai!". Mode Tanpa Batas tidak berubah.

**Architecture:** Level adalah data (`Levels`). `Game.current_level` memilih mode. `World.level` diteruskan ke `Terrain`
(seed, bukit, jumlah rintangan pulau 0) dan `Bird.speed_scale`. `game.gd` mendapat cabang mode level (selesai di
gerbang, bintang, tombol), dan scene baru `level_map` menampilkan peta.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, UI lewat `UIKit`, gambar lewat `Art.*`.

**Spec:** `docs/superpowers/specs/2026-11-24-petualangan-design.md`

**Butuh:** PR lorong kanopi (#7) sudah di-merge, karena lorong Hutan ikut diatur jumlahnya.

## Status

- Belum dimulai.

## Global Constraints
- 18 level berurutan sawah, pantai, hutan, gunung, danau, awan. Tiap pulau punya Pagi, Ramai, Badai. `id` = `<biome>-<1..3>`.
- Tingkat: Pagi 8 bukit / 1 rintangan · Ramai 10 / 2 · Badai 12 / 3, kecepatan ×1,12, hujan + tint 18 % lebih gelap.
- `Levels.READY_ISLANDS := ["sawah", "pantai", "hutan"]`. Pulau lain terkunci dengan pita "Segera hadir".
- Bintang: sampai gerbang · koin ≥ ceil(60 % total) · tanpa Lanjut. Bonus 20 koin per bintang baru.
- Layar selesai: "Level selesai!" + tombol Lanjut / Ulangi / Peta. Layar kalah level: Ulangi / Peta / Lanjut (tonton iklan).
- Menu: tombol MAIN diganti "Petualangan" dan "Tanpa Batas". Teks bahasa Indonesia, tanpa simbol di luar Fredoka.
- Level tidak memanggil `Game.submit_run` dan tidak memberi bonus pulau.
- Tes/sim pakai `--nosave`.

## Review Focus
- Save lama (tanpa `level_stars`) tetap terbaca, dan pemain lama langsung bisa main level 1 → tes load di Task 2.
- Lanjut lewat iklan di level, lalu sampai gerbang → bintang 1–2 boleh, bintang 3 tidak → tes di Task 3.
- Mati tepat di atas gerbang atau setelah melewati gerbang tidak boleh terjadi: begitu lewat gerbang, rintangan dan air tidak mematikan lagi → tes Task 3.
- Bonus bintang tidak boleh dobel saat level diulang dengan hasil sama → tes Task 3.
- Membuka level terakhir yang terbuka saat pulau berikutnya belum siap → tombol Lanjut di layar selesai nonaktif → tes Task 3.

---

### Task 1: Data level + Terrain/Bird/World mengikuti level

**Files:**
- Create: `scripts/data/levels.gd`
- Modify: `scripts/world/terrain.gd` (`setup`, `_generate_island`: hills dan jumlah rintangan untuk pulau 0 dari level), `scripts/world/bird.gd` (`speed_scale`), `scripts/world/world.gd` (`var level`, cuaca Badai)
- Test: `tests/test_levels.gd` (baru)

**Interfaces:**
- Produces: `class_name Levels`, `const TIER_NAMES := ["Pagi", "Ramai", "Badai"]`,
  `const TIERS := [{hills: 8, hazards: 1, speed: 1.0, storm: false}, {hills: 10, hazards: 2, speed: 1.0, storm: false}, {hills: 12, hazards: 3, speed: 1.12, storm: true}]`,
  `const READY_ISLANDS := ["sawah", "pantai", "hutan"]`, `static func all() -> Array` (18 × `{id, island, tier, name, seed}`),
  `static func get_level(id: String) -> Dictionary` (kosong kalau tidak ada), `static func index_of(id: String) -> int`,
  `static func is_ready(lv: Dictionary) -> bool`.
- `Terrain.setup(seed_value, first_island, coin_field, level: Dictionary = {})`, `var level_hills := -1`, `var level_hazards := -1`
  (hanya untuk pulau 0, `-1` = aturan biasa). `World.level: Dictionary`: kalau tidak kosong, World memakai
  `run_seed = level.seed` dan `start_island = level.island`. `Bird.speed_scale := 1.0`.

- [ ] **Step 1: Tes gagal** (`tests/test_levels.gd`):
  - `test_eighteen_levels`: 18 level, `id` unik, level ke-i punya `island == i / 3`, `tier == i % 3`, `id == Biomes.get_biome(island).id + "-" + str(tier + 1)`, dan `name == biome.name.split(" ")[0] + " " + TIER_NAMES[tier]`.
  - `test_level_hazard_counts`: untuk tiap level siap, buat `World` dengan `level` itu → pulau 0 punya `TIERS[tier].hills` bukit dan rintangan khas (kites/bays/canopies yang `island == 0`) tepat `TIERS[tier].hazards`.
  - `test_endless_unchanged`: `World` tanpa level, seed 4242 start 0 → `terrain.kites` dan `keys_x` pulau 0 sama dengan sebelum perubahan (bandingkan dengan nilai yang disimpan di tes ini dari `main`: jumlah key + x key terakhir).
  - `test_badai_speed_and_storm`: level Badai → `bird.speed_scale == 1.12`, dan biome aktif World punya `ambient == "rain"`.
- [ ] **Step 2:** `godot --headless --path . --import`, lalu `... res://tests/run_tests.tscn -- --only=level` → FAIL.
- [ ] **Step 3: Implementasi.** Di `_generate_island`, kalau `k == 0 and level_hills > 0`, pakai `hills = level_hills` dan
  `count = level_hazards` untuk `pick_hills` biome itu (ombak: `pick_hills(hills, count, rng)` menggantikan `pick_bay_hills`).
  Urutan RNG lain tetap. Seed level sementara `1000 + i * 7`, yang dikunci ulang di Task 5.
- [ ] **Step 4:** Tes PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(world): level data drives terrain, speed and storm weather`

### Task 2: Simpanan bintang + aturan terbuka

**Files:**
- Modify: `scripts/autoload/game_state.gd` (`current_level`, `level_stars`, `record_level`, `is_unlocked`, `total_stars`, save/load, flag `--level`)
- Test: `tests/test_levels.gd`

**Interfaces:**
- Produces: `Game.current_level: String`, `Game.level_stars: Dictionary`,
  `func record_level(id: String, stars: int) -> int` (simpan maksimum, kembalikan jumlah bintang **baru**),
  `func is_unlocked(id: String) -> bool`, `func total_stars() -> int`, `func last_unlocked_index() -> int`.

- [ ] **Step 1: Tes gagal:** `test_unlock_rules` (kosong → hanya `sawah-1` terbuka; `sawah-1` 1 bintang → `sawah-2` terbuka;
  `hutan-3` ≥ 1 → `gunung-1` tetap terkunci karena tidak ada di READY); `test_record_level_new_stars_only`
  (2 lalu 2 → baru 0; 2 lalu 3 → baru 1; 3 lalu 1 → tersimpan tetap 3); `test_old_save_loads` (JSON tanpa `level_stars`
  → `level_stars == {}`, tanpa error). Setiap tes menyimpan lalu mengembalikan `Game.level_stars` aslinya.
- [ ] **Step 2:** `--only=unlock|record_level|old_save` → FAIL.
- [ ] **Step 3: Implementasi.** `load_game` membaca `level_stars` dengan bawaan `{}`. Flag dev `--level=<id>` mengisi `current_level`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(game): level stars save and unlock rules`

### Task 3: Mode level di game.gd (selesai, bintang, tombol)

**Files:**
- Modify: `scripts/ui/game.gd` (`_ready` membaca `Game.current_level`, `_physics_process` cek gerbang, `_finish_level`, `_show_level_done`, `_show_results` mode level, HUD koin `x/y`, sim mencetak `cause=selesai`), `scripts/world/world.gd` (`var finished := false`: setelah gerbang, rintangan dan air tidak mematikan), `scripts/world/art.gd` (`star(ci, c, r, filled: bool)`)
- Test: `tests/test_levels.gd`

**Interfaces:**
- Consumes: `Levels`, `Game.record_level/is_unlocked` (Task 1–2).
- Produces: `game.gd`: `var level: Dictionary`, `var level_coins_total: int`, `var level_coins: int`,
  `func level_stars_earned() -> int`, `const STAR_BONUS := 20`, `const COIN_STAR_RATIO := 0.6`.

- [ ] **Step 1: Tes gagal** (game dibuat seperti `test_game_rules._game()` setelah `Game.current_level = "sawah-1"`; setiap tes
  mengembalikan `current_level = ""`):
  - `test_level_finishes_at_gate`: autopilot dari awal, frame sampai `state == "done"` (≤ 120 dtk) → `bird.position.x ≥ island_finish[0]`, dan ada teks "Level selesai!".
  - `test_level_stars_rules`: atur `level_coins` 59 % / 60 % dari total dan `continued` false/true → `level_stars_earned()` = 2/3/… sesuai aturan.
  - `test_star_bonus_once`: selesai 2× dengan bintang sama → koin bonus hanya di run pertama (`Game.coins` naik 20 × bintang baru saja).
  - `test_level_lose_buttons`: `bird_died.emit("laut")` → tepat 3 tombol: "Ulangi", "Peta", "Lanjut (tonton iklan)".
  - `test_level_done_buttons`: tombol "Lanjut", "Ulangi", "Peta". Di level `hutan-3`, Lanjut nonaktif (gunung belum siap).
  - `test_safe_after_gate`: `world.finished = true` dan burung di atas laut setelah gerbang → tidak mati.
  - `test_level_no_record`: `best_score` tidak berubah setelah level selesai.
  - `test_hud_level_coins`: label koin berbentuk `"0/%d" % level_coins_total` di awal.
- [ ] **Step 2:** `--only=level` → FAIL.
- [ ] **Step 3: Implementasi.** `state` mendapat nilai `"done"`. Saat gerbang dilewati: `world.finished = true`, burung tetap
  meluncur dengan autopilot nonaktif, dan setelah 1,2 dtk `_show_level_done`. Bintang muncul satu per satu (tween 0,25 dtk)
  dengan `Sfx.play("perfect")`. Ulangi = `Game.goto("res://scenes/game.tscn")` dengan level sama. Peta =
  `Game.goto("res://scenes/level_map.tscn")`. Lanjut = level berikutnya. Mode Tanpa Batas tidak boleh berubah
  (seluruh `test_game_rules` lama tetap hijau).
- [ ] **Step 4:** PASS, semua `failed=0`.
- [ ] **Step 5: Commit** `feat(game): adventure level mode with gate finish, stars and level screens`

### Task 4: Peta level + menu dua mode

**Files:**
- Create: `scenes/level_map.tscn` (root Node2D + script), `scripts/ui/level_map.gd`
- Modify: `scripts/ui/main_menu.gd` (tombol "Petualangan" + "Tanpa Batas"), `scripts/world/art.gd` (`lock`, `ribbon`)
- Test: `tests/test_levels.gd`

**Interfaces:**
- Produces: `level_map.gd`: `var level_buttons: Array[Button]` (18, urut), `func scroll_target_index() -> int`.

- [ ] **Step 1: Tes gagal:** `test_map_buttons` (instansiasi `level_map.tscn` → 18 tombol, teks "1".."18", hanya yang
  `Game.is_unlocked` yang aktif); `test_map_coming_soon` (ada 3 label "Segera hadir" untuk gunung, danau, awan);
  `test_menu_two_modes` (instansiasi `main_menu.tscn` → ada tombol "Petualangan" dan "Tanpa Batas", dan tidak ada "MAIN").
  Tombol Tanpa Batas mengosongkan `Game.current_level` sebelum `goto`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3: Implementasi** sesuai spec bagian "Peta": `ScrollContainer` mendatar, kelompok per pulau dengan judul
  `biome.name`, tombol bulat 96 px, 3 bintang kecil, gembok untuk yang terkunci, total `Bintang N/54` di pojok, dan
  tombol "Kembali". Latarnya `World` autoplay (`input_enabled = false`, `hazards = false`) di pulau level `last_unlocked_index`.
- [ ] **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(ui): level map and two-mode main menu`

### Task 5: Kunci seed, sim tiap level, dokumen

**Files:**
- Modify: `scripts/data/levels.gd` (seed final), `CLAUDE.md` (mode level, flag `--level`, perintah screenshot peta), spec (angka akhir), plan ini

- [ ] **Step 1:** Untuk tiap level siap (9 level), jalankan sim
  `godot --headless --path . --fixed-fps 120 res://scenes/game.tscn -- --level=<id> --autoplay --sim --fresh --nosave`
  dengan beberapa kandidat seed. Pilih seed yang sim-nya berakhir `cause=selesai` dan bentuknya bervariasi (catat jarak per level).
  Kunci di `levels.gd`. Level pulau belum siap tetap diberi seed (diuji ulang di langkah rintangannya).
- [ ] **Step 2:** Tambah `test_ready_levels_completable`: autopilot di tiap level siap sampai `state == "done"` tanpa mati.
- [ ] **Step 3:** Cek wajib bersih, termasuk headless `res://scenes/level_map.tscn --quit-after 300` dan `main_menu.tscn`.
- [ ] **Step 4:** Screenshot peta (`res://scenes/level_map.tscn -- --nosave --coins=0 --shot=…`), layar selesai
  (`--level=sawah-1 --autoplay --nosave --shot=… --shot-delay=<sampai gerbang>`), dan menu. Lihat gambarnya, lalu catat
  perintahnya di CLAUDE.md.
- [ ] **Step 5:** Tulis angka akhir di spec, centang plan, set status selesai, commit `docs: adventure step notes, plan status`, lalu push + PR.
