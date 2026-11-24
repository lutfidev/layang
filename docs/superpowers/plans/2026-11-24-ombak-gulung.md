# Ombak Gulung Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Ombak Pantai menjadi dinding gulung setinggi langit yang hanya bisa dilewati lewat terowongan di bawah gulungannya. Gambarnya terasa 3D.

**Architecture:** `Wave` memegang geometri kolom ombak (x0/x1 dari data teluk, atap `TUBE_TOP`, puncak naik sampai `CREST_Y`) dan cek kena. Gambar dipisah jadi dua: node `Wave` (z -1, di belakang burung dan bukit) menggambar dinding dan isi terowongan, sedangkan anak `WaveFront` (z 4) menggambar gulungan bibir dan tirai di depan burung. Pelontar bibir (`kick_at`, `LIP_KICK`, pita oranye) dihapus. Autopilot belajar terbang lewat terowongan.

**Tech Stack:** Godot 4.7.2, GDScript bertipe, gambar di kode (`Art.*`).

**Spec:** `docs/superpowers/specs/2026-11-24-ombak-gulung-design.md`

## Status (2026-11-24)

- **Selesai** di branch `feat/ombak-gulung` (Task 1–5, 64 tes hijau).
- Penyimpangan dari rencana (hasil screenshot):
  - Dinding setebal 260 px dan setinggi 2100 px terlihat seperti pilar air terjun. Bentuknya diubah: muka miring
    keluar ke arah burung sampai `MAX_OVER` = 900 px di puncak, punggung turun ke "ledge" `LEDGE` = 140 px
    setelah ujung terowongan, dan lebar puncak `CREST_W` = 300. Fungsi bentuk `Wave.face_x` / `Wave.back_x`
    dipakai bersama oleh cek kena dan gambar, jadi yang terlihat mematikan memang mematikan.
  - Terowongan **selalu aman**, juga saat ombak masih naik (aturan "gundukan rendah" dihapus karena membunuh
    burung yang berada di jalur yang benar).
  - Lolos dihitung setelah `col_x1 + LEDGE + PASS_MARGIN`.
  - "Lanjut" setelah mati di ombak: respawn melewati ledge (`Wave.safe_x_after`), karena burung yang menabrak
    muka miring mati *sebelum* teluk.
  - Koin langit di dalam bentuk ombak (+120 px) dibuang; 6 koin pemandu di tengah terowongan (y = 150).
  - Margin terukur: celah terkecil antara atas burung dan atap terowongan 261 px (pemain dengan pengendali
    "tahan kalau tenggelam ke setengah bawah terowongan"); bahaya utamanya air, bukan atap.

## Global Constraints

- Godot: `/d/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe` (`$G`). Tes `$G --headless --path . res://tests/run_tests.tscn [-- --only=name]`.
- Gambar hanya lewat helper `Art.*`, tanpa aset baru. GDScript bertipe; pakai `maxf/minf/absf/clampf` kalau di-assign dengan `:=`.
- Teks pemain berbahasa Indonesia, tanpa simbol ▶ ★ ←.
- y tumbuh ke bawah. `WATER_Y = 300`, `LIP_Y = -60`, `Bird.CEILING_HARD = -1500`.
- Sim/screenshot selalu `--nosave`.

## Angka (tes membaca konstanta)

| Konstanta | Nilai | Di mana |
|---|---|---|
| `COL_PAD` | 40.0 | Wave: kolom `[water_x0 - 40, water_x1 + 40]` |
| `TUBE_TOP` | -150.0 (`LIP_Y - 90`) | Wave |
| `CREST_Y` | -1800.0 | Wave |
| `HIT_PAD` | 18.0 | Wave |
| `FOAM_DIST` / `RISE_DIST` / `FULL_DIST` | 3200 / 2600 / 1500 | Wave (jarak ke `mid`) |
| `RISE_SPEED` | 2600.0 px/dtk | Wave (batas laju perubahan tinggi) |
| `RECEDE_TIME` | 0.9 | Wave |

`height` = tinggi puncak di atas air (0 … `WATER_Y - CREST_Y` = 2100). `crest_y() = WATER_Y - height`.
Kena kalau x pusat burung di kolom (± `HIT_PAD`) dan `center.y + HIT_PAD > crest_y()` dan
`center.y - HIT_PAD < TUBE_TOP` (selama `crest_y() < TUBE_TOP`). Saat ombak masih lebih rendah dari atap,
kena kalau `center.y + HIT_PAD > crest_y()`.

## Review Focus

1. **Burung fever (962 px/dtk) yang berlari di bibir** harus muat di bawah atap tanpa menahan (tes `test_tube_clears_every_speed`).
2. **Burung yang terbang tinggi di batas langit** harus tetap kena (tes `test_wave_blocks_high_path` di -1450).
3. **Teluk berikutnya dekat dengan teluk sebelumnya:** tinggi ombak tidak melompat dalam satu frame (tes `test_wave_height_is_rate_limited`).
4. **Lanjut setelah mati di ombak:** respawn di tanah kering, ombak teluk itu dilewati (tes lama `test_continue_*` tetap hijau).
5. **Dunia menu/toko:** tetap tanpa kematian dan tanpa suara (tes lama tetap hijau, autopilot demo melewati teluk).

---

### Task 1: Hapus pelontar bibir

**Files:** Modify `scripts/world/bird.gd`, `scripts/world/terrain.gd`, `scripts/world/world.gd`, `scripts/world/art.gd` (hapus `launch_ramp`), `tests/test_bays.gd`.

- [x] Hapus `Bird.LIP_KICK`, sinyal `kicked`, `_kick_flight`, blok kick di `step`; `Terrain.kick_at`, `KICK_BEFORE/AFTER`, `LIP_COLOR/LIP_EDGE`, gambar pita di props layer; sambungan `bird.kicked` di World; `kick_at` di `dry_ground_after`.
- [x] Tes: hapus `test_lip_kicks_grounded_bird`, `test_kick_*`, `test_airborne_bird_not_kicked`; tambah `test_lip_does_not_kick` (burung di tanah melewati bibir: `vel.y` tidak pernah < -200 sampai x = lip_x + 40).
- [x] Commit `feat(world): drop the bay launch lip`.

### Task 2: Ombak gulung (logika)

**Files:** Modify `scripts/world/wave.gd`, `scripts/world/terrain.gd` (`next_bay` pakai `Wave.COL_PAD`), `tests/test_bays.gd`.

**Produces:** `Wave.col_x0() -> float`, `Wave.col_x1() -> float`, `Wave.crest_y() -> float`, konstanta tabel di atas; `update()` tetap mengembalikan bool kena.

- [x] Tes gagal:
  - `test_wave_blocks_high_path`: untuk semua `CROSS_SEEDS` × bay, burung dipaksa terbang lurus di `y` ∈ {-250, -900, -1450} dari `mid - 1800` → deaths == ["ombak"].
  - `test_tube_clears_every_speed`: seed × start {1,0} × fever × bay, burung mulai di tanah `lip_x - 200` dengan kecepatan tanah; pengendali: tahan kalau `center.y > WATER_Y - 150` dan x ≥ `water_x0 - 120`. Harus deaths kosong, passed == 1. Cetak margin terkecil ke atap.
  - `test_foam_before_rise` diperbarui ke jarak baru; tinggi saat burung di `mid` == `WATER_Y - CREST_Y`.
  - `test_wave_height_is_rate_limited`: tinggi tidak berubah lebih dari `RISE_SPEED * DT + 0.01` per langkah selama penyeberangan.
- [x] Implementasi sesuai tabel; tinggi target dari jarak lalu `move_toward(height, target, RISE_SPEED * delta)`; lolos kalau `bird_x > col_x1() + PASS_MARGIN`.
- [x] Commit `feat(world): sky-high curling wave with a tube`.

### Task 3: Autopilot lewat terowongan + teks

**Files:** Modify `scripts/world/world.gd` (`_ai_hold`), `scripts/ui/game.gd` (tips + popup).

- [x] Autopilot: kalau teluk berikutnya dalam `lip_x - 900 … col_x1`, target = `WATER_Y - 160` saat `x + vx*0.3 >= water_x0`, selain itu `maxf(top - 20, Wave.TUBE_TOP + 90)`.
- [x] `test_autopilot_clears_bays` hijau; balance sim `--island=1` tanpa `cause=ombak` di awal.
- [x] Teks: tips "Turun ke bawah gulungan ombak, tahan sedikit supaya tidak tercebur"; popup "Awas ombak raksasa!" / "Terbang rendah lewat gulungannya".
- [x] Commit `feat(game): autopilot and hints for the tube`.

### Task 4: Gambar 3D

**Files:** Modify `scripts/world/art.gd` (`Art.wave` diganti `Art.wave_wall` + `Art.wave_lip`), `scripts/world/wave.gd` (z -1, anak `WaveFront` z 4).

- [x] `Art.wave_wall(ci, x0, x1, water_y, crest_y, tube_top, water, water_top, t)`: punggung kedua pucat di belakang, badan bergradasi (gelap di kaki → tosca terang tembus cahaya di puncak) dengan puncak melengkung ke kiri, garis kilau yang mengalir naik, isi terowongan gelap dengan cincin lengkung, mulut elips di kiri dan cahaya di ujung kanan, buih di kaki.
- [x] `Art.wave_lip(ci, x0, x1, tube_top, water_top, t)`: pita gulungan buih tebal di atap, tirai air transparan tipis, tetesan dan semburan di ujung.
- [x] Screenshot `--island=1 --seed=4242 --autoplay --nosave` di beberapa delay; cek burung terlihat di dalam terowongan.
- [x] Commit `feat(world): 3D look for the curling wave`.

### Task 5: Akhir langkah

- [x] Cek wajib, balance sim, centang plan, catat angka akhir di spec, push, PR.
