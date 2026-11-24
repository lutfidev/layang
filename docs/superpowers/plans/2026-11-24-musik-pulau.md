# Musik Tiap Pulau (Rintangan Pulau, langkah 5) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tiap pulau punya lagu loop sendiri (6 lagu disintesis oleh `tools/gen_music.py`). Lagu memudar ke lagu
berikutnya saat pindah pulau, di game maupun di menu/toko.

**Architecture:** Generator Python diberi tabel "resep" per pulau (tangga nada, tempo, instrumen) dan menulis
`assets/audio/music_<id>.ogg`. `Sfx` mendapat dua `AudioStreamPlayer` dan `play_music(id)` dengan crossfade 1,5 dtk.
`World` memanggil `Sfx.play_music(biome.id)` saat dibuat dan saat `_change_biome`.

**Tech Stack:** Python 3 + numpy + ffmpeg (offline, hasilnya di-commit), Godot 4.7.2 GDScript bertipe.

**Spec:** `docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md` (bagian "Langkah 5").

**Butuh:** tidak bergantung pada langkah 1–4. Boleh dikerjakan kapan saja setelah PR sebelumnya di-merge.

## Status

- Belum dimulai.

## Global Constraints
- Sintesis murni, tanpa sampel. Hasil `.ogg` di-commit, jadi build tidak butuh Python.
- 6 id: `sawah`, `pantai`, `hutan`, `gunung`, `danau`, `awan`. `gamelan_loop.ogg` (+ `.import`) dihapus, dan Sawah memakai resep lagu lama.
- Tiap lagu 32–48 ketukan, loop mulus, ogg `-q:a 3`, ≤ 600 KB per file, total ≤ 4 MB. Puncak dinormalkan sama.
- Resep (tangga nada / BPM / instrumen) sesuai tabel di spec: Sawah slendro 84, Pantai slendro tinggi 104,
  Hutan pelog 76, Gunung pelog rendah 92, Danau pelog 66, Awan slendro 72.
- Crossfade 1,5 dtk. `play_music` dengan id yang sama tidak berbuat apa-apa. Pengaturan Musik off menghentikan semua.
- CLAUDE.md diperbarui: aset audio = font + `assets/audio/music_*.ogg` dari `tools/gen_music.py`.

## Review Focus
- Toggle Musik off lalu on di tengah crossfade → yang lanjut adalah lagu pulau terakhir yang diminta, bukan lagu lama → tes Task 2.
- Pindah scene (game → menu lewat `Game.goto`) dengan pulau yang sama tidak memulai ulang lagu → tes id sama di Task 2.
- Pause game (`process_mode` Sfx = ALWAYS) tetap mengizinkan crossfade selesai → crossfade memakai Tween dari node Sfx, dicek di Task 2.
- Lagu yang hilang atau gagal dimuat (`load` null) tidak boleh crash: fallback ke `music_sawah` → tes Task 2.
- Klik di titik loop: sampel awal dan akhir harus nyambung → cek di generator (Task 1).

---

### Task 1: Generator 6 lagu

**Files:**
- Modify: `tools/gen_music.py` (fungsi `render(recipe) -> np.ndarray`, tabel `RECIPES`, argumen CLI opsional `id`)
- Create: `assets/audio/music_{sawah,pantai,hutan,gunung,danau,awan}.ogg`
- Delete: `assets/audio/gamelan_loop.ogg`, `assets/audio/gamelan_loop.ogg.import`

**Interfaces:**
- Produces: file `res://assets/audio/music_<id>.ogg` untuk 6 id.
- Resep per pulau: `{"bpm", "beats", "scale": [rasio], "base": Hz, "seed", "voices": [...]}`. Suara yang tersedia:
  `saron`, `bonang`, `kenong`, `gong`, `pad` (lagu sekarang), plus baru `kendang` (noise ber-envelope, ketuk 1/8 + aksen),
  `angklung` (nada dengan tremolo 12 Hz), `suling` (sinus + vibrato 5 Hz + napas noise lolos-tinggi), `gambang`
  (pukul kayu, peluruhan cepat), `rain` (noise berbintik acak, pelan), `gender` (nada lembut peluruhan panjang),
  `celempung` (petik, harmonik ganjil), `crickets` (sinus 4,5 kHz termodulasi, sangat pelan),
  `bells` (lonceng tinggi + gema: salinan tertunda 3/8 ketukan ×0,4, dibungkus loop).
- Pelog: `[1.0, 1.08, 1.19, 1.36, 1.47, 1.59, 1.79, 2.0]`. Slendro: `SLENDRO` yang ada.

- [ ] **Step 1:** Refactor lagu sekarang menjadi resep `sawah` tanpa mengubah bunyinya (seed sama, urutan RNG sama). Hasil ogg
  baru harus berdurasi sama dengan yang lama (32 ketukan pada 84 BPM ≈ 22,86 dtk).
- [ ] **Step 2:** Tambah 5 resep sesuai tabel spec. Tiap suara memakai pembungkusan indeks `% N` supaya loop mulus.
- [ ] **Step 3:** Di akhir render, tambah cek: `abs(out[0] − out[−1]) < 0.02` per kanal (setelah normalisasi), dan ukuran file ≤ 600 KB.
  Kalau tidak lolos, skrip keluar dengan kode ≠ 0.
- [ ] **Step 4:** Jalankan `python3 tools/gen_music.py`, lalu pastikan ke-6 file ada dan ukurannya dicetak. Dengarkan sekilas lewat
  `godot` (Task 2) atau pemutar lokal. Hapus `gamelan_loop.ogg*` lalu jalankan `godot --headless --path . --import`.
- [ ] **Step 5: Commit** `feat(audio): six island music loops from the synth generator`

### Task 2: `Sfx.play_music` + crossfade + pemanggilan dari World

**Files:**
- Modify: `scripts/autoload/sfx.gd` (dua player, `play_music`, `_apply_settings`), `scripts/world/world.gd` (`_ready` dan `_change_biome`)
- Test: `tests/test_music.gd` (baru)

**Interfaces:**
- Produces: `func play_music(id: String) -> void`, `func current_music() -> String`, `const MUSIC_FADE := 1.5`,
  `const MUSIC_DB := -9.0`, `func music_path(id: String) -> String` (= `"res://assets/audio/music_%s.ogg" % id`,
  fallback `sawah` kalau `ResourceLoader.exists` false).

- [ ] **Step 1: Tes gagal** (`tests/test_music.gd`, memakai autoload `Sfx` dan `Game`):
  - `test_play_music_sets_current`: `play_music("hutan")` → `current_music() == "hutan"`.
  - `test_same_id_no_restart`: `play_music("hutan")` dua kali → player aktif yang sama, `get_playback_position()` tidak kembali ke 0.
  - `test_switch_crossfades`: `play_music("pantai")` lalu `play_music("gunung")` → dua player sedang memutar segera sesudahnya, dan player lama memudar ke volume ≤ −40 dB lalu berhenti setelah fade selesai (jalankan `Sfx._finish_fade()` di tes atau tunggu Tween dengan `process_frame` di runner).
  - `test_music_off_stops_all` dan `test_music_on_resumes_last`: off → tidak ada yang memutar. `play_music("danau")` saat off,
    lalu on → yang memutar `danau`.
  - `test_unknown_id_falls_back`: `play_music("xyz")` → stream = lagu sawah, tidak ada error.
  - `test_world_plays_biome_music`: `World` dengan `start_island = 3` → `current_music() == "gunung"`. Setelah `_change_biome(Biomes.get_biome(4))` → `"danau"`.
  - Tes mengembalikan `Game.music_on` ke nilai awal di akhir tiap tes.
- [ ] **Step 2:** import + `--only=music` → FAIL.
- [ ] **Step 3: Implementasi.** Ganti `_music` tunggal dengan `_players_music: Array[AudioStreamPlayer]` (2) dan `_active: int`.
  `play_music` memuat stream (cache per id, `loop = true`), lalu memulai player cadangan di `−40 dB` dan me-Tween keduanya
  (`MUSIC_FADE`). Player lama `stop()` di akhir. `_ready` tidak lagi memuat `gamelan_loop.ogg`, dan lagu pertama datang dari
  `World`. Main menu/toko cukup lewat World mereka. `_apply_settings`: on → putar ulang `_current` kalau tidak ada yang memutar.
- [ ] **Step 4:** `--only=music` PASS, semua tes `failed=0`.
- [ ] **Step 5: Commit** `feat(audio): per-island music with crossfade`

### Task 3: Verifikasi + dokumen

- [ ] **Step 1:** Cek wajib bersih (termasuk headless `res://scenes/main_menu.tscn --quit-after 300` tanpa error).
- [ ] **Step 2:** Sim `--sim` seed 11 → `RUN score=…`, tanpa error audio.
- [ ] **Step 3:** Ubah CLAUDE.md (baris Architecture tentang aset audio), tulis "Angka akhir langkah 5" di spec (ukuran tiap file, durasi), centang plan, dan set status selesai.
- [ ] **Step 4:** Minta pemilik repo mendengarkan di perangkat (rasa tiap lagu dan kehalusan crossfade tidak bisa dites mesin). Catat ini di badan PR.
- [ ] **Step 5: Commit** `docs: island music notes, plan status`, lalu push + PR.
