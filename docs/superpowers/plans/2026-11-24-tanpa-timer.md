# Tanpa Timer (Tanpa Batas, tahap 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [x]`) syntax.

**Goal:** Lari tanpa batas: timer dan semua turunannya dihapus, kalah hanya karena rintangan, layar kalah dengan tepat tiga tombol (Main Lagi, Menu, Lanjut lewat iklan) dan lanjut di tanah aman.

**Spec:** `docs/superpowers/specs/2026-11-24-tanpa-batas-design.md` (bagian "Tahap 2").

## Status

- **Selesai** di branch `feat/tanpa-timer` (Task 1–4, 49 tes hijau).
- Tambahan: flag dev `--die=penyebab` untuk screenshot layar kalah; `distance` tidak pernah turun (`maxi`);
  `UIKit.SunIcon` dan suara `sun`/`night` dihapus karena tidak dipakai lagi.
- Sim autopilot (seed 11 dan 4242) bertahan sampai batas 240 dtk: `RUN score≈21.300, islands=8, cause=batas`.
  Autopilot belum pernah kalah, jadi kurva kesulitan dibahas di tahap 5.

## Tasks

### Task 1: Hapus timer
- [x] `game.gd`: hapus `START_TIME`, `NIGHT_GRACE`, `time_left`, `night_t`, state `night`, `_nightfall`, `TimeBar`, `lbl_time`, flag `--time`; `sun_progress` tetap 0,8, `dusk` 0.
- [x] Bonus pulau tanpa waktu; banner tanpa "+N detik".
- [x] Hapus bola matahari (`CoinField.SUN`, spawn di `terrain.gd`, cabang `+3 detik`).
- [x] Hapus `Bird.sleepy` dan tesnya; ganti `test_night_over_sea_ends_run` dengan `test_no_timer_endless`.
- [x] Sim: `--sim-max=S` (bawaan 240) → `_finish("batas")`.

### Task 2: Layar kalah 3 tombol
- [x] Judul per penyebab + saran; hapus tombol Koin ×2.
- [x] Tepat tiga tombol: Main Lagi, Menu, Lanjut (tonton iklan); Lanjut nonaktif setelah dipakai.
- [x] Tes `test_lose_screen_three_buttons`, `test_continue_button_once`.

### Task 3: Lanjut di tanah aman
- [x] `Terrain.dry_ground_after(x)`; `_continue_run` memindah burung maju ke sana.
- [x] Tes lanjut di laut dan teluk: burung di atas tanah kering, skor tidak turun, tidak mati lagi.

### Task 4: Dokumen dan cek
- [x] README, CLAUDE.md (flag `--time` dihapus, `--sim-max`), tagline menu.
- [x] Cek wajib, sim, screenshot layar kalah.
