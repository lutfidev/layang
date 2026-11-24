# Tanpa Timer (Tanpa Batas, tahap 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Lari tanpa batas: timer dan semua turunannya dihapus, kalah hanya karena rintangan, layar kalah dengan tepat tiga tombol (Main Lagi, Menu, Lanjut lewat iklan) dan lanjut di tanah aman.

**Spec:** `docs/superpowers/specs/2026-11-24-tanpa-batas-design.md` (bagian "Tahap 2").

## Status

- Sedang dikerjakan di branch `feat/tanpa-timer`.

## Tasks

### Task 1: Hapus timer
- [ ] `game.gd`: hapus `START_TIME`, `NIGHT_GRACE`, `time_left`, `night_t`, state `night`, `_nightfall`, `TimeBar`, `lbl_time`, flag `--time`; `sun_progress` tetap 0,8, `dusk` 0.
- [ ] Bonus pulau tanpa waktu; banner tanpa "+N detik".
- [ ] Hapus bola matahari (`CoinField.SUN`, spawn di `terrain.gd`, cabang `+3 detik`).
- [ ] Hapus `Bird.sleepy` dan tesnya; ganti `test_night_over_sea_ends_run` dengan `test_no_timer_endless`.
- [ ] Sim: `--sim-max=S` (bawaan 240) → `_finish("batas")`.

### Task 2: Layar kalah 3 tombol
- [ ] Judul per penyebab + saran; hapus tombol Koin ×2.
- [ ] Tepat tiga tombol: Main Lagi, Menu, Lanjut (tonton iklan); Lanjut nonaktif setelah dipakai.
- [ ] Tes `test_lose_screen_three_buttons`, `test_continue_button_once`.

### Task 3: Lanjut di tanah aman
- [ ] `Terrain.dry_ground_after(x)`; `_continue_run` memindah burung maju ke sana.
- [ ] Tes lanjut di laut dan teluk: burung di atas tanah kering, skor tidak turun, tidak mati lagi.

### Task 4: Dokumen dan cek
- [ ] README, CLAUDE.md (flag `--time` dihapus, `--sim-max`), tagline menu.
- [ ] Cek wajib, sim, screenshot layar kalah.
