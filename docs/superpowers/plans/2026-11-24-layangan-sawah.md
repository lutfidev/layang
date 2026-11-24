# Layangan Sawah (Tanpa Batas, tahap 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [x]`) syntax.

**Goal:** Di pulau Sawah ada 2 layang-layang warga yang diam di atas puncak bukit; badan + ekornya mematikan,
jalur bawah (menyusuri bukit) aman, jalur atas di atas badan berisi busur 10 koin.

**Architecture:** `Terrain` memilih puncak layangan dan mencatat `kites`, serta menaruh busur koin khusus.
Node baru `Kite` (meniru `Wave`) menghitung bentuk layangan (statis, bisa dites), menggambar, dan mengecek
tabrakan; `World._update_hazards` memanggilnya, penyebab kalah `"layangan"`. `game.gd` menambah judul/saran,
popup "Awas layangan!", dan lanjut yang melewati layangan.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar lewat `Art.*`.

**Spec:** `docs/superpowers/specs/2026-11-24-tanpa-batas-design.md` (bagian "Tahap 3").

## Status

- **Selesai** di branch `feat/layangan-sawah` (Task 1–4, 65 tes hijau).
- Tes jalur terbang menggerakkan "tahan" lewat `input_enabled` + `_touch_hold` (World menimpa `bird.holding` dari input).
- Ekor digambar dengan warna utama layangan dan pita lebih besar setelah screenshot pertama (ekor tipis sulit terbaca).
- Catatan kecil yang ditunda: `Kite._draw` mengulang semua layangan dari awal run (jumlahnya kecil); busur koin
  di atas layangan berada di tepi atas layar saat terbang tinggi.

## Global Constraints
- Tidak ada aset baru: layangan, ekor, tali, warga digambar sebagai `Art.*`.
- Teks pemain bahasa Indonesia; hindari simbol di luar subset Fredoka.
- `maxf/minf/absf/clampf` saat hasil di-assign dengan `:=`.
- Hanya biome `sawah`, `KITES_PER_ISLAND = 2`, tidak di bukit 0–1, tidak berurutan.
- Ujung ekor ≥ 170 px (`TAIL_CLEAR`) di atas tanah; layangan tidak berpindah, ekor hanya berkibar ke samping.
- Judul kalah "Tersangkut layangan!", saran "Terbang rendah di bawah ekor, atau tinggi di atasnya",
  popup "Awas layangan!" / "Terbang rendah di bawah ekornya".
- Sim/screenshot pakai `--nosave`.

## Review Focus
- Burung fever (kecepatan ×1,3) yang menyusuri bukit tetap lewat di bawah ekor → varian fever di tes jalur bawah (Task 2).
- Lanjut setelah mati di laut/teluk tidak boleh menaruh burung (200 px di atas tanah) di dalam ekor layangan
  berikutnya → `safe_x_after` dipakai untuk semua penyebab, tes di Task 3.
- Burung yang lari di tanah (on_ground) melewati puncak layangan tetap aman → tes jalur bawah mulai dari tanah (Task 2).
- Busur koin tidak boleh berada di zona tabrakan layangan pada fase animasi mana pun → tes koin (Task 2).
- Autopilot menu/sim tidak boleh mati di layangan → tes autopilot (Task 2) + sim (Task 4).

---

### Task 1: Data layangan di terrain + busur koin

**Files:**
- Modify: `scripts/world/terrain.gd` (`pick_bay_hills` → `pick_hills`, `_generate_island`, `_place_items`)
- Test: `tests/test_kites.gd` (baru)

**Interfaces:**
- Produces: `Terrain.KITES_PER_ISLAND := 2`, `Terrain.KITE_ARC_COINS := 10`, `Terrain.KITE_ARC_HALF := 300.0`,
  `Terrain.KITE_ARC_TOP := 520.0` (puncak busur = `peak_y − 520`, ujung busur turun 120 px),
  `static func pick_hills(hills: int, count: int, rng: RandomNumberGenerator) -> Array[int]`
  (`pick_bay_hills(hills, rng)` tetap ada, memanggil `pick_hills(hills, BAYS_PER_ISLAND, rng)`),
  `var kites: Array` terurut x, tiap item `{x: float, peak_y: float, island: int, color: int}`.

- [x] **Step 1: Tes gagal** di `tests/test_kites.gd` (helper `_world/_free` seperti `test_bays.gd`, start island 0):
  - `test_pick_hills_rule`: seed 1..200, hills 9..15, count 2 dan 3 → ukuran = count, semua di `[2, hills-1]`, terurut, selisih ≥ 2.
  - `test_kites_only_on_sawah`: seed 4242/7/99, start 0 → setiap pulau `k` yang sudah dibuat dengan biome `sawah` punya tepat 2 layangan,
    pulau lain 0; start 1 → layangan hanya di pulau yang biome-nya `sawah` (k = 5 kalau sudah dibuat).
  - `test_kite_at_peak`: setiap `kite.peak_y == terrain.height_at(kite.x)` (±1) dan tanah di `x ± 200` tidak lebih tinggi (y ≥ peak_y − 1).
  - `test_kite_coin_arc`: setiap layangan punya tepat 10 koin dengan `|x − kite.x| ≤ 300` dan `y < kite.peak_y − 380`.
- [x] **Step 2:** `godot --headless --path . --import` lalu `... res://tests/run_tests.tscn -- --only=kite` → FAIL (`kites` belum ada).
- [x] **Step 3: Implementasi.** RNG terpisah `run_seed * 4271 + k * 65537` untuk `pick_hills(hills, 2, rng)` bila `biome.id == "sawah"`;
  di loop bukit, setelah puncak `(px, py)` untuk bukit terpilih → `kites.append({...})`, `color` = indeks bukit % 3.
  `_place_items`: segmen naik yang berakhir di x layangan tidak memakai busur acak (tetap panggil `rng.randf()` agar urutan RNG lain sama);
  sebagai gantinya 10 koin di `x = kite.x + u * 300`, `y = peak_y − 520 + u² * 120`, `u` rata dari −1 ke 1.
- [x] **Step 4:** tes `--only=kite` PASS dan seluruh tes tetap `failed=0` (termasuk `test_pick_bay_hills_rule`).
- [x] **Step 5: Commit** `feat(world): pick sawah kite peaks and their coin arcs`

### Task 2: Node `Kite` (bentuk, tabrakan, gambar) + world

**Files:**
- Create: `scripts/world/kite.gd`
- Modify: `scripts/world/art.gd` (`kite`, `kite_tail`, `villager`), `scripts/world/world.gd` (node, hazard, `_die`, `clear_hazards`)
- Test: `tests/test_kites.gd`

**Interfaces:**
- Consumes: `terrain.kites` (Task 1).
- Produces (`class_name Kite extends Node2D`):
  konstanta `BODY_ABOVE = 400.0` (pusat badan di `peak_y − 400`), `BODY_HW = 34.0`, `BODY_HH = 44.0`, `BOB = 8.0`,
  `TAIL_CLEAR = 170.0`, `TAIL_DRIFT = 40.0` (ujung ekor di `x − 40`), `TAIL_SWAY = 20.0`, `TAIL_SEGS = 10`,
  `BIRD_R = 16.0` (badan: titik di belah ketupat yang diperbesar `BIRD_R`; ekor: jarak ke ruas < `BIRD_R`),
  `SPOT_DIST = 1400.0`, `VILLAGER_BACK = 360.0`.
  `static func body_center(k: Dictionary, t: float) -> Vector2`,
  `static func tail_points(k: Dictionary, t: float) -> PackedVector2Array` (TAIL_SEGS+1 titik dari bawah badan ke ujung; goyang hanya di x, makin ke ujung makin besar; y ujung tetap),
  `static func hits(k: Dictionary, t: float, p: Vector2) -> bool`,
  `static func span(k: Dictionary) -> Vector2` (x kiri/kanan zona bahaya termasuk goyang dan `BIRD_R`),
  `var terrain: Terrain`, `var view_left/view_right: float`, `signal spotted` (sekali per run, saat layangan pertama < `SPOT_DIST` di depan),
  `func update(delta: float, bird_center: Vector2, bird_x: float) -> bool`,
  `func safe_x_after(x: float) -> float` (bila `x` di dalam atau < 200 px sebelum `span` suatu layangan → `span.y + 200`, diulang untuk layangan berikutnya).
  `World.kite: Kite`, `World.bird_died` bisa membawa `"layangan"`.

- [x] **Step 1: Tes gagal** di `tests/test_kites.gd` (seed 4242/7/99, start 0, semua layangan pulau 0):
  - `test_tail_clearance`: untuk t = 0..4 dtk langkah 0,05 dan tiap titik ekor: `height_at(p.x) − p.y ≥ TAIL_CLEAR − 0.5`; titik terakhir y = `peak_y − 170`.
  - `test_ground_run_passes_under`: burung di tanah pada `kite.x − 600`, `holding=false`, kecepatan `_ground_speed`, normal dan fever; `w._physics_process(DT)` sampai `x > span.y + 100` → tanpa kematian.
  - `test_skim_passes_under`: sama, tapi `holding = position.y > height_at(x) − Bird.SKIM_HEIGHT` tiap langkah → tanpa kematian.
  - `test_body_height_dies`: terbang datar (tahan saat `center.y > body_center.y`) dari `kite.x − 500` → kematian `["layangan"]` sebelum `kite.x + 100`.
  - `test_over_body_survives`: sama di `body_center.y − BODY_HH − 90` → tanpa kematian sampai `span.y + 100`.
  - `test_coins_outside_hit_zone`: untuk setiap koin busur dan t = 0..4 dtk langkah 0,05 → `Kite.hits(k, t, coin) == false`.
  - `test_menu_world_no_kite_death`: `hazards=false`, jalur setinggi badan → tanpa kematian.
  - `test_autopilot_clears_kites`: autoplay, seed 11/22/33/44/55, start 0, sampai `span.y + 100` dari layangan terakhir pulau 0 → tanpa kematian.
- [x] **Step 2:** import + `--only=` nama-nama di atas → FAIL.
- [x] **Step 3: Implementasi.** `Kite` seperti `Wave`: `_anim` sendiri, `z_index = 2`, cek hanya layangan dengan `span` yang mengandung `bird_x`.
  `_draw`: hanya layangan di `[view_left − 600, view_right + 600]`: warga di `x − 360` di tanah, tali lengkung tipis dari tangan ke bawah badan,
  ekor (pita kecil di tiap titik), badan. Warna dari palet tetap 3 entri (merah/kuning, biru/putih, hijau/oranye) menurut `color`.
  `Art.kite(ci, center, hw, hh, col, accent)`, `Art.kite_tail(ci, pts, col)`, `Art.villager(ci, base, s, col)`.
  `World`: buat `kite` setelah `wave`, set `view_left/right` di tempat yang sama dengan `coins`; di `_update_hazards` saat `hazards` →
  `kite.update(...)` true → `_die("layangan")` (urutan sesudah ombak, sebelum laut); `_die("layangan")`: `shake = 0.8`, `Sfx.play("bonk")`,
  `Ambient.burst` warna layangan. `hazards=false`: tetap panggil `kite.update` untuk animasi, abaikan hasil.
- [x] **Step 4:** seluruh tes `failed=0`; cek error headless bersih.
- [x] **Step 5: Commit** `feat(world): villagers' kites over sawah peaks`

### Task 3: Aturan game (judul, saran, popup, lanjut)

**Files:**
- Modify: `scripts/ui/game.gd` (`CAUSE_TITLES`, `CAUSE_TIPS`, `_continue_run`, sambungan `kite.spotted`)
- Test: `tests/test_game_rules.gd`

**Interfaces:**
- Consumes: `World.kite`, `Kite.spotted`, `Kite.safe_x_after`, `Kite.span` (Task 2).

- [x] **Step 1: Tes gagal:**
  - `test_kite_death_title`: emit `bird_died("layangan")` → `end_cause == "layangan"`, panel memuat "Tersangkut layangan!" dan saran.
  - `test_sawah_warns_about_kites`: taruh burung di `kites[0].x − 1300`, `_frames(g, 0.5)` → `lbl_popup.text == "Awas layangan!"`; muncul sekali saja.
  - `test_continue_after_kite_death_is_safe`: terbang setinggi badan ke layangan 0 → `deaths == ["layangan"]`; `_continue_run()` → `x > span.y`, skor tidak turun, `_frames(g, 2.0)` tanpa kematian lagi.
  - `test_continue_never_lands_in_kite`: untuk tiap layangan, `world.kite.safe_x_after(x)` dengan `x` di `span.x − 100` dan di tengah span → hasil `≥ span.y + 200`.
- [x] **Step 2:** `--only=kite` / `--only=continue` → FAIL.
- [x] **Step 3: Implementasi.** Tambah entri `"layangan"` ke kedua kamus; `world.kite.spotted` → `_popup("Awas layangan!", "Terbang rendah di bawah ekornya", Color("#ffd36b"))` bila `state == "play"`;
  `_continue_run`: `b.position.x = world.kite.safe_x_after(world.terrain.dry_ground_after(b.position.x))`.
- [x] **Step 4:** seluruh tes `failed=0`.
- [x] **Step 5: Commit** `feat(game): kite death title, warning popup, continue past kites`

### Task 4: Verifikasi, dokumen, PR

- [x] **Step 1:** Cek wajib (import, tes `failed=0`, headless tanpa `SCRIPT ERROR`).
- [x] **Step 2:** Sim seed 11 dan 4242 (`--sim --fresh --nosave --seed=N`) → `cause=batas`.
- [x] **Step 3:** Screenshot Sawah (`--island=0 --seed=4242 --autoplay --nosave --shot=... --shot-delay=D`, D dipilih agar layangan pertama terlihat) dan periksa: layangan, ekor, tali, warga, busur koin.
- [x] **Step 4:** Review kode branch, perbaiki temuan.
- [x] **Step 5: Dokumen.** Spec: status tahap 3 selesai + angka akhir; `CLAUDE.md`: perintah screenshot layangan; plan ini: centang semua + Status.
  Commit `docs: kite phase notes, plan status`.
- [x] **Step 6:** `git push -u origin feat/layangan-sawah`, `gh pr create --base main` judul `feat: layangan sawah`, badan sesuai CLAUDE.md.
