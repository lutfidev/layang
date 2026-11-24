# Ombak Pantai (Tanpa Batas, tahap 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teluk berisi air di lembah pulau Pantai, dengan buih sebagai tanda dan ombak yang naik. Pemain melewatinya lewat bibir pelontar (launch lip) atau dengan menahan untuk naik. Kena ombak = kalah, "Terkena ombak".

**Architecture:** `Terrain` membangkitkan 3 teluk per pulau Pantai (key point khusus: lembah, bibir, dasar teluk, tepi seberang) dan bisa membedakan air teluk dari laut. `Bird` terlempar ke atas saat menyentuh tanah di zona pelontar bibir teluk. Node baru `Wave` (mirip `SeaMonster`) menangani buih/ombak berdasarkan jarak burung ke teluk berikutnya. `World` menghubungkan kematian/lolos, `game.gd` menangani judul hasil, popup, dan poin.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar di kode (`Art.*`).

**Spec:** `docs/superpowers/specs/2026-11-24-tanpa-batas-design.md` (bagian "Tahap 1"). Keputusan baru dari pemilik repo (2026-11-24): **bibir pelontar**, karena fisika sekarang tidak memberi momentum dari tanjakan. Bibir harus terlihat beda (pita warna dan panah), dan tes harus membuktikan `vel.y = -620` cukup untuk melewati puncak ombak terjauh.

## Global Constraints

- Godot binary: `/d/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe` (tulis `$G` di bawah). Tes: `$G --headless --path . res://tests/run_tests.tscn [-- --only=name]`. Setelah menambah `class_name` baru, jalankan `$G --headless --path . --import` dulu.
- Semua gambar di kode sebagai helper `Art.*`. Tidak ada aset bitmap/audio baru. Suara baru disintesis di `sfx.gd` dengan `_tones`/`_noise`.
- GDScript bertipe; pakai `maxf/minf/absf/clampf` kalau hasilnya di-assign dengan `:=`.
- Teks untuk pemain berbahasa Indonesia. Font Fredoka tidak punya ▶ ★ ←; panah digambar sebagai poligon.
- y tumbuh ke bawah. `Terrain.WATER_Y = 300`. Pantai = biome id `"pantai"` (index 1; `Biomes.get_biome(i)` memakai `posmod`).
- Timer tetap ada di tahap ini.
- Sim/screenshot selalu `--nosave`. Cek headless: `$G --headless --path . --quit-after 600 res://scenes/game.tscn -- --autoplay --nosave` tanpa `SCRIPT ERROR` (peringatan "2 resources still in use at exit" sudah ada sebelumnya).
- Commit kecil di branch `feat/ombak-pantai`, pesan bahasa Inggris, tanpa atribusi Claude.

## Angka yang dipakai (sumber kebenaran; tes membaca konstanta, bukan angka literal)

| Konstanta | Nilai | Di mana | Alasan |
|---|---|---|---|
| `BAYS_PER_ISLAND` | 3 | Terrain | spec |
| `BAY_VALLEY_Y` | 60.0 | Terrain | lembah sebelum bibir; tanjakan landai |
| `LIP_Y` | -60.0 | Terrain | puncak bibir |
| `LIP_RAMP` | 480.0 | Terrain | lembah→bibir; kemiringan maks 120·π/960 ≈ 0.39 < 0.5, jadi mendarat di tanjakan tidak bonk karena lereng |
| `BAY_FLOOR_Y` | 380.0 | Terrain | dasar teluk (di bawah air) |
| `BAY_HALF` | 300.0 | Terrain | bibir→dasar dan dasar→tepi seberang; air ≈ `lip_x+216 … lip_x+396` |
| `BANK_Y` | 40.0 | Terrain | tepi seberang rendah, tempat mendarat |
| `KICK_BEFORE` / `KICK_AFTER` | 40.0 / 10.0 | Terrain | zona pelontar `[lip_x-40, lip_x+10]` |
| `LIP_KICK` | 620.0 (= `MAX_RISE`) | Bird | permintaan pemilik repo |
| `WAVE_H` | 200.0 | Wave | puncak di y=100 |
| `WAVE_HALF` | 70.0 | Wave | lebar kolom ombak di sekitar `mid` |
| `HIT_PAD` | 18.0 | Wave | jari-jari kena untuk pusat burung |
| `FOAM_DIST` / `RISE_DIST` / `FULL_DIST` | 1900 / 750 / 200 | Wave | jarak `mid - bird.x` |
| `RECEDE_TIME` | 0.9 | Wave | surut setelah lolos |

Hitungan cek (paling lambat 357 px/dtk di tanah, dilempar dari `lip_x-40`): di tepi jauh ombak (`mid+70`) pusat burung ≈ y 25, jauh di atas puncak 100. Peluncur pelan 40 px di atas bibir tanpa menahan: di tepi dekat ombak pusatnya ≈ y 115, jadi kena. Kalau tes Task 3 tidak sesuai dengan hitungan ini, ubah **`WAVE_H` atau zona pelontar**, jangan `LIP_KICK`, dan catat angka akhirnya di tabel ini.

## Review Focus

1. **Burung yang bonk di lembah sebelum teluk** (`vel.x × 0.6`) lalu naik ke bibir: masih harus lolos, karena `vel.x` pulih di tanjakan 480 px. Tes ada di Task 3.
2. **"Lanjut" setelah mati di teluk:** respawn harus aman (tinggi di atas air) dan ombak teluk itu tidak membunuh lagi. Tes ada di Task 4.
3. **Mendarat di tepi seberang yang curam** setelah lompatan berhasil tidak boleh bonk/"Aduh!". Tes ada di Task 2.
4. **Dunia menu/toko** (`hazards=false`) melewati teluk: tanpa kematian, burung memantul dari air, ombak tetap tergambar. Tes ada di Task 3.
5. **Burung fever (cepat)** dilempar sangat jauh: tidak boleh ada error saat mendarat lewat tepi seberang, dan `wave_passed` tetap terkirim sekali. Tes ada di Task 3.

---

### Task 1: Teluk di terrain Pantai

**Files:**
- Modify: `scripts/world/terrain.gd`
- Test: `tests/test_bays.gd` (baru)

**Interfaces:**
- Produces:
  - `var bays: Array` berisi Dictionary `{"lip_x": float, "mid": float, "water_x0": float, "water_x1": float, "bank_x": float, "island": int}` (urut menurut x).
  - `static func pick_bay_hills(hills: int, rng: RandomNumberGenerator) -> Array[int]`: `BAYS_PER_ISLAND` index bukit terurut di `[2, hills-1]`, tidak ada dua yang berurutan.
  - `func is_water_at(x: float) -> bool`: `height_at(x) > WATER_Y` (laut atau teluk).
  - `func bay_at(x: float) -> int`: index teluk yang `water_x0 <= x <= water_x1`, atau -1.
  - `func is_sea_at(x: float) -> bool`: sekarang `is_water_at(x) and bay_at(x) < 0`.
  - `func next_bay(x: float) -> int`: teluk pertama dengan `water_x1 + Wave.WAVE_HALF > x`, atau -1. (Pakai literal 70.0 di sini kalau `Wave` belum ada; ganti di Task 3.)
  - `func kick_at(x: float) -> bool`: true di `[lip_x-KICK_BEFORE, lip_x+KICK_AFTER]` milik salah satu teluk.
  - `func soft_landing_at(x: float) -> bool`: true di `[water_x1, bank_x]` milik salah satu teluk.

- [ ] **Step 1: Tulis tes gagal di `tests/test_bays.gd`** (pola sama dengan `test_hazards.gd`: `var runner`, helper `_world(seed, start_island, hazards)`).
  - `test_pick_bay_hills_rule`: untuk seed 1..200 dan `hills` 9..15 → `size()==BAYS_PER_ISLAND`, semua `>=2` dan `<=hills-1`, terurut, tidak ada `b[i+1]-b[i]==1`.
  - `test_bays_only_on_pantai`: World `start_island=0` (pulau 0 sawah, 1 pantai) → semua teluk punya `island==1`, jumlahnya `BAYS_PER_ISLAND`. World `start_island=1` → `island==0`.
  - `test_bay_water_is_not_sea`: untuk tiap teluk (seed 4242, 7, 99): `is_water_at(mid)`, `not is_sea_at(mid)`, `bay_at(mid)==i`, `height_at(lip_x)==LIP_Y` (toleransi 0.01), `not is_water_at(water_x0-10)` dan `not is_water_at(water_x1+10)`; `boundaries.size()==2`.
  - `test_no_ground_coins_or_props_in_bay`: tidak ada `coins.items` atau `props` dengan x di `[water_x0, water_x1]` dan `y > WATER_Y - 60` (koin tanah; koin busur di udara boleh).
- [ ] **Step 2: Jalankan** `$G --headless --path . res://tests/run_tests.tscn -- --only=bay` → FAIL.
- [ ] **Step 3: Implementasi.** Di `_generate_island`, kalau `biome.id == "pantai"`, hitung `bay_hills := pick_bay_hills(hills, rng)` **setelah** angka acak untuk hill normal diambil (supaya pulau non-Pantai tetap identik untuk seed yang sama). Untuk `h` di `bay_hills`, ganti pasangan lembah/puncak dengan 4 key: lembah `(lx + roll*wid, BAY_VALLEY_Y)`, bibir `(+LIP_RAMP, LIP_Y)`, dasar `(+BAY_HALF, BAY_FLOOR_Y)`, tepi `(+BAY_HALF, BANK_Y)`. Hitung `water_x0/x1` secara numerik (langkah 2 px dari bibir/dasar) setelah key ditambahkan. `_build_water(lip_x, bank_x, biome)` per teluk. Di `_place_items`, lewati koin tanah dan props yang `is_water_at(x)`.
- [ ] **Step 4: Jalankan semua tes** → baru dan lama lulus (23 tes lama tidak berubah).
- [ ] **Step 5: Commit** `feat(world): bays in Pantai valleys, bay water is not sea`

### Task 2: Bibir pelontar dan pendaratan teluk

**Files:**
- Modify: `scripts/world/bird.gd`, `scripts/world/terrain.gd` (PropsLayer), `scripts/world/art.gd`
- Test: `tests/test_bays.gd`

**Interfaces:**
- Consumes: `Terrain.kick_at`, `soft_landing_at`, `is_water_at`, `bays`.
- Produces: `Bird.LIP_KICK := 620.0`; `signal kicked`; `Art.launch_ramp(ci: CanvasItem, surface: PackedVector2Array, col: Color, t: float) -> void` (pita warna sepanjang permukaan, ditambah 3 chevron putih ke kanan-atas yang berdenyut dan bergeser).

- [ ] **Step 1: Tulis tes gagal.**
  - `test_lip_kicks_grounded_bird`: bird `on_ground=true` di `lip_x - 150`, `vel.x = 0.85*SPEED_START`, `holding=false`. Panggil `bird.step(DT)` sampai x ≥ `lip_x+KICK_AFTER` → `kicked` terkirim sekali, `on_ground==false`, dan `vel.y <= -LIP_KICK + GRAVITY*DT*2` di frame terlempar.
  - `test_airborne_bird_not_kicked`: bird di udara 40 px di atas `LIP_Y` melintasi `lip_x` → `kicked` tidak terkirim.
  - `test_bank_landing_is_soft`: bird jatuh dengan `vel.y=MAX_FALL` ke titik `soft_landing_at` yang lerengnya `< BONK_SLOPE` → `landed(false)`.
  - `test_no_skim_over_bay`: bird terbang 40 px di atas air teluk dari `water_x0` ke `water_x1` (y dipaku tiap frame) → `skimmed` tidak terkirim.
- [ ] **Step 2: Jalankan** `-- --only=lip` dan `-- --only=bank` → FAIL.
- [ ] **Step 3: Implementasi.** Di `Bird.step`, setelah blok tanah: `if on_ground and terrain.kick_at(position.x)` → `on_ground=false`, `vel.y=-LIP_KICK`, `position.y -= GROUND_STICK + 1.0`, `kicked.emit()`. `_land(slope)`: `bonk` dipaksa false kalau `terrain.soft_landing_at(position.x)`. Zona skim pakai `not terrain.is_water_at(position.x)`. PropsLayer menggambar `Art.launch_ramp` untuk tiap teluk yang terlihat, dengan sampel permukaan `lip_x - 220 … lip_x + KICK_AFTER` tiap 14 px. Warna `Color("#ff7a59")` dengan pinggir `Color("#ffe066")`, supaya kontras dengan pasir Pantai. Di `World._ready`, sambungkan `bird.kicked` ke `Sfx.play("whoosh", 1.3)`.
- [ ] **Step 4: Jalankan semua tes** → lulus.
- [ ] **Step 5: Commit** `feat(world): launch lip before bays, soft landing on the far bank`

### Task 3: Ombak (`Wave`) dan sambungan World

**Files:**
- Create: `scripts/world/wave.gd`
- Modify: `scripts/world/world.gd`, `scripts/world/art.gd`, `scripts/autoload/sfx.gd`, `scripts/world/terrain.gd` (literal 70 → `Wave.WAVE_HALF`)
- Test: `tests/test_bays.gd`

**Interfaces:**
- Consumes: `Terrain.bays`, `next_bay`, `is_water_at`, `is_sea_at`; `Bird.kicked`.
- Produces:
  - `class_name Wave extends Node2D` dengan konstanta dari tabel; `var bay := -1`, `var state := "idle"` (`idle|foam|rise|recede`), `var height := 0.0`, `signal passed`.
  - `func update(delta: float, bird_center: Vector2, bird_x: float) -> bool` (true = kena). Pilih `bay = terrain.next_bay(bird_x)` saat idle. Dengan `d = mid - bird_x`: `d > FOAM_DIST` → idle; `> RISE_DIST` → foam, height 0; selain itu `height = WAVE_H * ease(clampf((RISE_DIST - d) / (RISE_DIST - FULL_DIST), 0, 1), -2.0)`. Saat `bird_x > mid + WAVE_HALF + 40` → `passed.emit()` sekali, lalu recede (height turun ke 0 dalam `RECEDE_TIME`), lalu lanjut ke teluk berikutnya. Kena kalau `absf(c.x - mid) < WAVE_HALF and c.y + HIT_PAD > WATER_Y - height`.
  - `func reset_current() -> void`: teluk sekarang dianggap lolos tanpa `passed`; langsung recede.
  - `World`: `var wave: Wave`; `signal wave_passed`; `bird_died` sekarang juga bisa `"ombak"`.
  - `Art.foam(ci, x0: float, x1: float, y: float, density: float, t: float) -> void`, `Art.wave(ci, mid: float, half_w: float, water_y: float, h: float, water: Color, foam: Color, t: float) -> void` (dinding tosca dengan bibir buih melengkung ke kiri; bayangan `Art.shadow` di dasar).
  - Sfx: `"fizz"` (`_noise(0.5, 0.12)`) saat foam mulai, `"surge"` (`_noise(0.7, 0.35)`) saat rise mulai.

- [ ] **Step 1: Tulis tes gagal.** Helper `_cross_bay(w, i, setup: Callable) -> Dictionary` yang menjalankan `w._physics_process(DT)` sampai `bird.x > bank_x + 50`, mati, atau 6 dtk, lalu mengembalikan `{deaths, kicked, passed}`.
  - `test_kick_clears_every_wave`: seed 4242, 7, 99, 1234, 555 × `start_island` 1 (paling lambat, x dekat awal) dan 0 (kecepatan khas di pulau ke-2) × fever false/true. Untuk **setiap** teluk, bird di tanah pada `lip_x - 200`, `vel.x` = 0.85 × target di x itu (×1.3 kalau fever), `holding=false` → `deaths==[]`, `kicked`, `passed==1`. Pesan gagal menyebut seed, teluk, kecepatan, dan y pusat terendah di kolom ombak.
  - `test_kick_clears_after_bonk`: seperti di atas tapi `start_island=1`, bird di lembah (`lip_x - LIP_RAMP`) dengan `vel.x = 0.6 × SPEED_START` → lolos.
  - `test_low_slow_glide_hits_wave`: `start_island=1`, tiap teluk: bird di udara di `(lip_x, LIP_Y - 40)`, `vel=(SPEED_START, 0)` → `deaths==["ombak"]`.
  - `test_holding_clears_wave`: sama seperti di atas tapi `w.input_enabled=true; w._touch_hold=true` → lolos.
  - `test_foam_before_rise`: bird di tanah 2000 px sebelum `mid` dengan kecepatan khas: urutan state yang teramati `idle → foam → rise`, foam mulai saat `mid - bird_x <= FOAM_DIST`, dan `height==WAVE_H` saat bird di `mid`.
  - `test_no_monster_in_bay`: bird dipaku 150 px di atas air teluk melintasi teluk → `monster.state=="idle"` sepanjang jalan.
  - `test_menu_world_bay_bounces`: `hazards=false`, bird di udara masuk teluk rendah → tidak mati, `bird.position.y < WATER_Y` di akhir, `wave.state != "idle"` di tengah jalan.
  - `test_fever_overshoot_passes_once`: fever, `vel.x = SPEED_MAX*1.3`, dilempar → `passed==1`, tanpa error.
- [ ] **Step 2: Jalankan** `$G --headless --path . --import` lalu `-- --only=wave` / `--only=kick` / `--only=glide` → FAIL.
- [ ] **Step 3: Implementasi.** `World._ready` membuat `wave` (z_index 2, `wave.terrain = terrain`). Di `_update_hazards`: `wave.update(...)` selalu dipanggil. Kalau `hazards` dan hasilnya true → `_die("ombak")` (`shake = 1.0`, `Sfx.play("splash")`, burst buih). Tenggelam dan pantulan menu memakai `terrain.is_water_at(x)`; monster tetap memakai `is_sea_at`. `clear_hazards()` memanggil `wave.reset_current()`. `BirdShadow` memakai `is_water_at`. `wave.passed` → `wave_passed.emit()` hanya kalau `not dead`.
- [ ] **Step 4: Jalankan semua tes** → lulus. Kalau `test_kick_clears_every_wave` atau `test_low_slow_glide_hits_wave` gagal, sesuaikan sesuai aturan di bagian "Angka" dan perbarui tabelnya.
- [ ] **Step 5: Commit** `feat(world): beach wave with foam warning in Pantai bays`

### Task 4: Aturan permainan (judul, popup, lanjut)

**Files:**
- Modify: `scripts/ui/game.gd`
- Test: `tests/test_game_rules.gd`

**Interfaces:**
- Consumes: `World.wave_passed`, `bird_died("ombak")`, `Terrain.is_water_at`, `World.clear_hazards`.
- Produces: `const WAVE_POINTS := 150`.

- [ ] **Step 1: Tulis tes gagal.**
  - `test_wave_death_title`: `g.world.bird_died.emit("ombak")` → `end_cause=="ombak"`, ada label "Terkena ombak".
  - `test_wave_passed_rewards`: `g.world.wave_passed.emit()` → `style_points == WAVE_POINTS`, ada label "LOLOS OMBAK!".
  - `test_continue_after_bay_death_is_safe`: `start_island` diset lewat `Game.dev["island"]=1` (hapus lagi di akhir tes). Bird di udara rendah dan pelan di bibir teluk pertama → mati "ombak" → `_continue_run()` → `bird.position.y <= WATER_Y - 500`, lalu `_frames(g, 2.0)` tanpa kematian kedua.
- [ ] **Step 2: Jalankan** `-- --only=wave` → FAIL.
- [ ] **Step 3: Implementasi.** Tambah `"ombak": "Terkena ombak"` ke `titles`. Handler `wave_passed` (hanya di state play/night): `style_points += WAVE_POINTS`, `Sfx.play("perfect", 1.2)`, `_popup("LOLOS OMBAK!", "+%d" % WAVE_POINTS, Color("#7ff0e6"))`. Di `_continue_run`, pakai `is_water_at` di tempat `is_sea_at`. Ganti komentar `end_cause` menjadi `senja | laut | monster | ombak`. Hint tutorial: tambahkan "Awas ombak!" hanya saat pulau Pantai pertama tercapai, sebagai popup sekali di `_on_island` kalau `biome.id == "pantai"`.
- [ ] **Step 4: Jalankan semua tes** → lulus.
- [ ] **Step 5: Commit** `feat(game): wave death title, LOLOS OMBAK bonus, safe continue in bays`

### Task 5: Autopilot, sim, screenshot, dokumen

**Files:**
- Modify: `scripts/world/world.gd` (`_ai_hold`), `CLAUDE.md`, `docs/superpowers/specs/2026-11-24-tanpa-batas-design.md`, plan ini
- Test: `tests/test_bays.gd`

- [ ] **Step 1: Tulis tes gagal** `test_autopilot_clears_bays`: seed 11, 22, 33, 44, 55, `start_island=1`, `autoplay=true`, `hazards=true`. Jalankan sampai `bird.x > bays[last].bank_x + 100` atau 90 dtk → tidak ada kematian `"ombak"` atau `"laut"` dan `passed == BAYS_PER_ISLAND`. Kematian `"monster"` sebelum teluk terakhir = gagal (laut antar-pulau ada setelah teluk, jadi seharusnya tidak terjadi).
- [ ] **Step 2: Jalankan** → FAIL.
- [ ] **Step 3: Implementasi di `_ai_hold()`.** Kalau `b = terrain.next_bay(x)` ada dan `x < lip_x + KICK_AFTER` dan `lip_x - x < 900`: mode mendekat, target = permukaan tanah (lepas supaya mendarat di tanjakan), tapi tahan kalau `vel.y > 380` (mendarat lembut). Kalau `x` di antara `lip_x + KICK_AFTER` dan `mid + Wave.WAVE_HALF`: tahan kalau pusat yang diprediksi (`+vel.y*0.25`) `> WATER_Y - wave.height - 80`. Pakai `_ai_rng` yang sudah ada untuk reaksi seeded `0.1 + pow(randf(), 4) * 0.3` dtk sejak foam mulai sebelum masuk mode mendekat.
- [ ] **Step 4: Jalankan semua tes** → lulus.
- [ ] **Step 5: Sim keseimbangan 5×** `$G --headless --path . --fixed-fps 120 res://scenes/game.tscn -- --island=1 --autoplay --sim --fresh --nosave` dan `--island=0` (2×). Kumpulkan baris `RUN …`; tidak boleh ada `cause=ombak`. Catat hasilnya untuk badan PR.
- [ ] **Step 6: Screenshot** `$G --path . res://scenes/game.tscn -- --island=1 --autoplay --nosave --shot=<scratchpad>/ombak_foam.png --shot-delay=N`. Atur N sampai burung berada di puncak sebelum teluk pertama: buih harus terlihat di sisi kanan layar dan bibir pelontar jelas berbeda warna. Ambil juga satu screenshot saat ombak penuh. Lihat kedua gambar.
- [ ] **Step 7: Dokumen.** Spec: Status jadi "disetujui", tambahkan "Bibir pelontar" ke "Yang diputuskan bersama", dan pindahkan angka akhir ke catatan tahap 1. `CLAUDE.md`: perintah screenshot ombak (`--island=1`). Plan ini: centang semua langkah, tambahkan bagian Status. Jalankan cek wajib (import, tes, headless).
- [ ] **Step 8: Commit** `feat(world): autopilot clears bays; docs: wave phase notes`
