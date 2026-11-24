# Perbaikan Temuan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Menyelesaikan semua temuan kecil yang ditunda dari review akhir PR #7 (lorong kanopi), PR #9 (peta
petualangan), dan PR #10 (misi), sebelum langkah semburan lava dimulai.

**Architecture:** Tidak ada fitur baru. Setiap temuan dibuktikan dulu dengan tes yang gagal, lalu diperbaiki di
tempatnya (`game.gd`, `game_state.gd`, `canopy.gd`, `world.gd`, `kite.gd`, tes, spec).

**Tech Stack:** Godot 4.7.2, GDScript bertipe.

**Spec:** `docs/superpowers/specs/2026-11-24-petualangan-design.md` (Petualangan + Misi) dan
`docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md` (rintangan pulau).

**Butuh:** PR #10 (misi) sudah di-merge.

## Status

- **Selesai** (2026-11-24, branch `feat/perbaikan-temuan`). Semua temuan T1-T13 diperbaiki. Pemilik repo meminta
  langkah ini dikerjakan **sebelum** semburan lava.
- Catatan: T10 langsung lulus (kekurangan tes, bukan bug). T11 dibuat umum: `World._die` memakai `hit_color` dari
  setiap rintangan pulau. Review akhir menemukan burung membeku di gerbang pada kasus T1 (`world.dead` masih true),
  dan itu sudah diperbaiki. Baris `ERROR: 2 resources still in use at exit` di akhir sim sudah ada sebelum langkah ini
  (muncul karena `quit()` dipanggil di tengah run).

## Global Constraints
- Ikuti alur git di CLAUDE.md: branch `feat/perbaikan-temuan`, PR `feat: perbaikan temuan`.
- Tiap perbaikan: tes gagal dulu (RED), lalu perbaikan (GREEN), lalu seluruh suite `failed=0`.
- Perilaku yang sudah benar tidak berubah. Sim Tanpa Batas seed 11 tetap `cause=batas`, dan 9 level siap tetap `cause=selesai`.
- Teks pemain berbahasa Indonesia. Tes dan sim pakai `--nosave`.

## Daftar temuan

| # | Asal | Temuan | Arah perbaikan (usulan) |
|---|---|---|---|
| T1 | PR #9 | Burung yang kena rintangan di frame yang sama saat melewati gerbang memunculkan layar kalah, bukan "Level selesai!". | Di `game.gd`, cek gerbang sebelum kematian diproses: kalau mode level dan `bird.position.x >= island_finish[0]`, `_on_died` memanggil `_finish_level()`. |
| T2 | PR #9 + #10 | Koin yang diambil setelah "Level selesai!" tidak masuk ke koin pemain, tapi tetap menambah progres misi koin. | `_on_item` mengabaikan koin kalau `state != "play"`, jadi tidak dihitung di mana pun. Hasilnya konsisten. |
| T3 | PR #9 | Monster laut yang sedang melompat akan membeku kalau suatu saat level berakhir di atas air (`world.finished`). Belum bisa terjadi sekarang. | Saat `world.finished` menjadi true, `monster.reset()`. Tes memaksa lompatan, lalu `finished`, lalu memastikan monster tidak tertahan di udara. |
| T4 | PR #9 | `Game.current_level` tetap terisi setelah kembali ke menu. | `main_menu.gd` `_ready` mengosongkan `Game.current_level`. |
| T5 | PR #10 | Setelah Lanjut lalu kalah lagi, layar hasil terakhir tidak menampilkan misi yang sudah dibayar saat kalah pertama. | `_settle_missions` menggabungkan hasil per run: `missions_done` ditambah, bukan diganti, dan snapshot `missions_run` diambil sekali per run. Baris misi pengganti tidak ditampilkan. |
| T6 | PR #10 | Keluar lewat jeda ("Ulang"/"Menu Utama") menghanguskan koin run itu, tapi progres misi koin tetap naik. | `_leave_run` menyimpan `coins_run - coins_banked` ke `Game.add_coins` sebelum settle. Keluar lewat jeda tidak lagi menghanguskan koin. |
| T7 | PR #10 | Setelah keluar lewat jeda, permainan masih berjalan sekitar 0,3 detik di bawah layar pudar. Burung bisa mati, lalu `_finish` jalan lagi. | `_leave_run` mengisi `state = "over"` dan `world.running = false` sebelum `Game.goto`. |
| T8 | PR #10 | Terbang tinggi di atas layangan juga dihitung "Lewati layangan" dan "Lolos rintangan", jadi misi lolos terlalu mudah di Sawah. | `Kite.passed` hanya dipancarkan kalau burung melewati rentang layangan **di bawah** badan layangan (`bird_center.y > body_center.y`). Simpan tanda per layangan saat burung di dalam rentangnya. |
| T9 | PR #10 | `test_mission_pause_menu_settles` memanggil `Game.goto` sungguhan. Tes aman hanya karena runner berjalan sinkron. | `game.gd` mendapat `var goto_scene: Callable = Game.goto`, yang dipakai `_leave_run`. Tes menggantinya dengan fungsi pencatat. |
| T10 | PR #7 | Tes peringatan hutan tidak membuktikan peringatannya hanya muncul sekali. | Tes Hutan memajukan burung ke lorong kedua dan memastikan popup "Awas lorong hutan!" tidak muncul lagi, seperti `test_sawah_warns_about_kites`. |
| T11 | PR #7 | `Canopy.hit_color` tidak dipakai. | Pakai untuk percikan saat mati di lorong (`Ambient.burst` di `World`, seperti `kite.hit_color`), atau hapus kalau tidak cocok. Usulan: pakai. |
| T12 | PR #7 | `Canopy` menggambar ulang setiap frame walaupun tidak ada lorong di layar. | `queue_redraw()` hanya kalau ada lorong yang beririsan dengan `view_left..view_right`, atau baru keluar dari layar. |
| T13 | PR #7 | Bagian "Antarmuka bersama" di spec rintangan pulau berbeda dengan kode (`update(delta, center, x, on_ground)`, `passed`, `safe_x_after` dengan float biasa). | Perbarui spec supaya sesuai `canopy.gd`, karena langkah lava, kelelawar, dan petir akan mengikutinya. |

## Review Focus
- T1: burung mati tepat setelah gerbang, padahal level selesai di frame yang sama → harus "Level selesai!", bukan layar kalah.
- T5 + T6: run dengan Lanjut lalu keluar lewat jeda → koin dan hadiah misi dibayar tepat sekali.
- T8: layangan yang dilewati di bawah tetap dihitung, termasuk saat FEVER (kecepatan tinggi, langkah x besar).
- T2: magnet FEVER yang menarik koin setelah gerbang tidak menambah apa pun.

---

### Task 1: Level dan akhir run (T1, T2, T3, T4)

**Files:** `scripts/ui/game.gd`, `scripts/ui/main_menu.gd`, `scripts/world/world.gd`, `tests/test_levels.gd`

- [x] **Step 1: Tes gagal:**
  - `test_death_at_gate_finishes_level`: posisikan burung tepat di gerbang dan picu `bird_died` → `state == "done"`.
  - `test_coins_after_done_ignored`: setelah `_finish_level`, emit `item_collected` → `coins_run` dan progres misi koin tidak berubah.
  - `test_monster_reset_when_finished`.
  - `test_menu_clears_current_level`.
- [x] **Step 2:** Jalankan, FAIL.
- [x] **Step 3:** Perbaikan sesuai tabel.
- [x] **Step 4:** PASS, dan seluruh suite `failed=0`.
- [x] **Step 5: Commit** `fix: level end edge cases (death at the gate, coins after done, monster, current level)`

### Task 2: Misi dan keluar lewat jeda (T5, T6, T7, T9)

**Files:** `scripts/ui/game.gd`, `tests/test_missions.gd`

- [x] **Step 1: Tes gagal:**
  - `test_mission_results_keep_first_payout`: misi selesai, kalah, Lanjut, kalah lagi → layar hasil masih memuat "Selesai! +N" untuk misi pertama.
  - `test_mission_pause_exit_banks_coins`: `coins_run` 7, lalu "Menu Utama" → `Game.coins` +7 plus hadiah.
  - `test_mission_pause_exit_stops_run`: setelah tombol, `state == "over"` dan `world.running == false`.
  - Ubah `test_mission_pause_menu_settles` supaya memakai `goto_scene` palsu.
- [x] **Step 2:** FAIL.
- [x] **Step 3:** Perbaikan sesuai tabel.
- [x] **Step 4:** PASS, dan seluruh suite `failed=0`.
- [x] **Step 5: Commit** `fix: pause exit banks coins and stops the run; results keep every mission paid this run`

### Task 3: Layangan dihitung hanya kalau dilewati di bawah (T8)

**Files:** `scripts/world/kite.gd`, `tests/test_missions.gd`

- [x] **Step 1: Tes gagal:** `test_mission_kite_over_not_counted`: burung melintas di atas badan layangan (y = `peak_y - 600`) → tidak ada `passed`. `test_mission_kite_pass_signal` (di bawah) tetap 2.
- [x] **Step 2:** FAIL.
- [x] **Step 3:** Perbaikan sesuai tabel.
- [x] **Step 4:** PASS. Sim Sawah (`--island=0 --seed=4242 --autoplay --sim --fresh --nosave`) tanpa error.
- [x] **Step 5: Commit** `fix: a kite only counts as passed when the bird goes under it`

### Task 4: Lorong hutan (T10, T11, T12, T13)

**Files:** `scripts/world/canopy.gd`, `scripts/world/world.gd`, `tests/test_game_rules.gd`, `tests/test_canopy.gd`, `docs/superpowers/specs/2026-11-24-rintangan-pulau-design.md`

- [x] **Step 1: Tes gagal:**
  - `test_hutan_warns_once`: lorong kedua tidak memunculkan peringatan lagi.
  - `test_canopy_death_burst_color`: percikan saat mati memakai `Canopy.hit_color`, misalnya dengan mencatat warna burst terakhir di `World`.
  - `test_canopy_redraw_only_on_screen`: tanpa lorong di layar, `update` tidak meminta redraw. Pakai penanda `_needs_draw` atau penghitung.
- [x] **Step 2:** FAIL. Catatan: `test_hutan_warns_once` mungkin langsung PASS, karena temuan ini soal tes yang kurang, bukan bug. Kalau begitu, catat di ledger dan lanjutkan.
- [x] **Step 3:** Perbaikan sesuai tabel. Spec "Antarmuka bersama" disamakan dengan `canopy.gd`.
- [x] **Step 4:** PASS, dan seluruh suite `failed=0`. Screenshot Hutan (perintah di CLAUDE.md, delay 7) tetap terlihat benar.
- [x] **Step 5: Commit** `fix: canopy warns once, uses its hit colour and redraws only on screen; shared interface spec matches code`

### Task 5: Verifikasi + dokumen

- [x] **Step 1:** Cek wajib bersih.
- [x] **Step 2:** Sim Tanpa Batas seed 11 (`cause=batas`) dan sim 9 level siap (`cause=selesai`).
- [x] **Step 3:** Centang plan, set status selesai, dan catat keputusan baru di spec terkait.
- [x] **Step 4: Commit** `docs: findings step notes, plan status`, lalu push dan buat PR.
