# Petualangan (18 level) + Misi — design

Status: disetujui pemilik repo (2026-11-24). Langkah Petualangan selesai (`feat/peta-petualangan`) · lanjutan dari `2026-11-24-rintangan-pulau-design.md`

## Intent (kenapa)

Setelah mencoba di HP, pemilik repo merasa Layang seru, tapi "langkah-langkahnya masih sedikit" dan rintangannya
kurang. Karena sudah banyak game sejenis, mainnya terasa sekadar mengisi waktu ("gabut"). Penyebabnya: pemain hanya
punya satu tujuan, yaitu skor di lari tanpa batas. Tidak ada target berikutnya yang bisa dikejar, dan tidak ada
alasan untuk kembali besok.

Solusi yang dipilih: **arah A (Peta Petualangan) ditambah misi dari arah B**. Arah C (burung pengantar dan desa yang
tumbuh) dicatat sebagai tujuan jangka panjang, dan peta pulau ini nanti bisa menjadi fondasinya.

## Goals

- Menu punya dua mode: **Petualangan** (peta 18 level) dan **Tanpa Batas** (lari sekarang, tidak berubah).
- **18 level = 6 pulau × 3 tingkat (Pagi, Ramai, Badai).** Satu level = satu pulau dengan **seed tetap**, dari awal
  pulau sampai gerbang candi. Bentuknya selalu sama, jadi bisa dihafal dan diperbaiki.
- **3 bintang per level:** (1) sampai gerbang, (2) kumpulkan ≥ 60 % koin level, (3) selesai tanpa Lanjut.
- **Misi:** selalu ada 3 misi aktif yang berlaku di kedua mode. Misi yang selesai memberi koin, lalu diganti misi baru.
- Pulau yang rintangan khasnya belum dibuat (Gunung, Danau, Awan) tampil terkunci dengan label **"Segera hadir"**.
  Kuncinya terbuka di langkah rintangan masing-masing.

## Non-goals

- Tidak mengubah mode Tanpa Batas, fisika, kontrol, toko, atau skin.
- Tidak ada level yang digambar tangan. Level adalah data (seed + parameter).
- Belum ada cerita atau desa (arah C), papan peringkat, atau sistem nyawa/energi untuk membatasi main.

## Anti-goals

- Level yang terasa sama satu dengan lainnya (Pagi, Ramai, dan Badai harus jelas berbeda).
- Level kosong tanpa rintangan khas (karena itu pulau tanpa rintangan dikunci).
- Misi yang mustahil atau membosankan ("main 50 kali"), atau misi untuk konten yang masih terkunci.
- Iklan yang memaksa. Lanjut tetap hanya lewat tombol, dan menolaknya hanya mengorbankan bintang ketiga.

## Approaches

- **I. Level sebagai data — DIPILIH.** `scripts/data/levels.gd` berisi 18 entri. `Terrain` menerima "pengaturan level"
  (jumlah bukit dan jumlah rintangan) untuk pulau pertama. Polanya sama seperti biome dan skin, mudah dites headless,
  dan menambah level cukup menambah data.
- II. Level digambar tangan (titik bukit per level). Kontrolnya penuh, tapi berat tanpa editor visual. Ditolak.
- III. Level = lari tanpa batas dengan target jarak. Paling murah, tapi Pagi/Ramai/Badai tidak benar-benar berbeda,
  padahal justru itu masalahnya. Ditolak.

## Yang diputuskan bersama

- Arah A + misi dari B. Bentuk level: 6 pulau × 3 tingkat = 18 level (usulan saya, disetujui).
- Seluruh rancangan di bawah diusulkan dan disetujui ("udah cocok semua").
- Rintangan yang sudah direncanakan tetap dikerjakan sesuai pulaunya: lava (Gunung), kelelawar (Danau), petir (Awan),
  ditambah musik tiap pulau.

## Rancangan

### Urutan pengerjaan

1. **Petualangan** (plan `2026-11-24-peta-petualangan.md`): level, peta, layar selesai, bintang.
2. **Misi** (plan `2026-11-24-misi.md`).
3. Semburan lava, yang juga membuka level Gunung (`2026-11-24-semburan-lava.md`).
4. Kawanan kelelawar, yang juga membuka level Danau (`2026-11-24-kelelawar-danau.md`).
5. Gerbang awan petir, yang juga membuka level Awan (`2026-11-24-awan-petir.md`).
6. Musik tiap pulau (`2026-11-24-musik-pulau.md`). Tidak bergantung pada langkah lain.

### Data level

- `class_name Levels` (`scripts/data/levels.gd`), dengan `static func all() -> Array` berisi 18 dictionary berurutan:
  `{id: "sawah-1", island: 0, tier: 0, name: "Sawah Pagi", seed: int}`. `id` = `<biome.id>-<tier+1>`, dan nama
  tingkat: Pagi, Ramai, Badai.
- Parameter per tingkat (`Levels.TIERS`):

| Tingkat | Bukit | Rintangan khas | Kecepatan | Cuaca |
|---|---|---|---|---|
| Pagi (0) | 8 | 1 | normal | biome biasa |
| Ramai (1) | 10 | 2 | normal | biome biasa |
| Badai (2) | 12 | 3 | ×1,12 | hujan + langit lebih gelap |

- Rintangan khas = layangan (Sawah), teluk + ombak (Pantai), lorong (Hutan), kawah (Gunung), kawanan (Danau),
  gerbang petir (Awan). Jumlahnya menggantikan konstanta `*_PER_ISLAND` hanya untuk pulau level.
  Aturannya tetap: tidak di 2 bukit pertama, tidak berurutan.
- **Pulau siap**: `Levels.READY_ISLANDS := ["sawah", "pantai", "hutan"]`. Langkah lava, kelelawar, dan petir
  masing-masing menambah id pulaunya ke daftar ini.
- Seed tetap per level dipilih saat membangun, supaya semua bisa dilewati. Sim autopilot di tiap level harus sampai
  gerbang (lihat Bukti selesai).

### Jalannya level

- `Game.current_level: String` (`""` = Tanpa Batas). Peta mengisinya lalu memanggil `Game.goto("res://scenes/game.tscn")`.
  Flag dev `--level=<id>` mengisinya dari baris perintah.
- `World` mendapat `var level: Dictionary` (kosong = tanpa batas). `Terrain.setup(..., level)` memakai `level.seed`,
  `island = level.island`, bukit, dan jumlah rintangan untuk pulau 0. Pulau sesudahnya tetap dibuat seperti biasa
  sebagai pemandangan setelah gerbang.
- `Bird.speed_scale: float = 1.0` (Badai 1,12) dikalikan ke target kecepatan.
- Cuaca Badai: biome disalin dengan `ambient = "rain"` dan `tint` digelapkan 18 %.
- **Selesai** saat `bird.position.x ≥ terrain.island_finish[0]`. Burung terus meluncur, dan layar **"Level selesai!"**
  menampilkan 3 bintang yang muncul satu per satu (digambar dengan `Art.star`, karena font tidak punya ★), koin yang
  didapat, dan bonus bintang baru, dengan 3 tombol: **Lanjut** (level berikutnya, nonaktif kalau terkunci),
  **Ulangi**, dan **Peta**.
- **Kalah di level:** judul penyebab + saran seperti sekarang, dengan tepat 3 tombol: **Ulangi**, **Peta**, dan
  **Lanjut (tonton iklan)**. Lanjut tetap sekali per run. Memakai Lanjut membuat bintang ketiga tidak bisa didapat
  di run itu.
- **Koin level:** HUD menampilkan `terkumpul/total` (mis. `12/30`). Total = jumlah item koin dengan x < `island_finish[0]`
  saat level dibuat. Bintang kedua didapat kalau terkumpul ≥ ceil(60 % · total).
- **Hadiah:** koin yang terkumpul seperti biasa, ditambah **20 koin per bintang baru** (bintang yang sudah pernah
  didapat tidak dihitung lagi). Bonus pulau (+500 poin, +20 koin) tidak berlaku di level.
- Skor tetap dihitung, tapi tidak masuk rekor Tanpa Batas (`submit_run` hanya untuk Tanpa Batas).
- Level 1 (Sawah Pagi) sekaligus tutorial: petunjuk "Tahan untuk naik" yang sudah ada tampil di situ.

### Peta

- Scene baru `scenes/level_map.tscn` + `scripts/ui/level_map.gd`. Latarnya `World` autoplay (seperti menu) di pulau dari
  level terakhir yang terbuka.
- Daftar mendatar yang bisa digeser: 6 kelompok pulau, masing-masing berisi nama pulau dan 3 tombol level bulat
  (angka 1–18, tiga bintang kecil di bawahnya). Saat dibuka, posisi geser langsung menuju level terbuka terakhir.
- **Terbuka** kalau level pertama, atau level sebelumnya punya ≥ 1 bintang, dan pulaunya ada di `READY_ISLANDS`.
  Level terkunci berwarna abu-abu. Pulau yang belum siap mendapat pita **"Segera hadir"**.
- Di pojok ada total bintang (`Bintang 14/54`) dan tombol **Kembali** ke menu.

### Menu

- Tombol **MAIN** diganti **Petualangan** (besar) dan **Tanpa Batas**. Tombol lain tetap.
- Panel **Misi** (3 baris) ada di sisi kanan menu.

### Misi

- `class_name Missions` (`scripts/data/missions.gd`) berisi daftar templat `{id, kind, target, reward, text}`. `text`
  memakai `%d` untuk target. Isi awal (bisa ditambah):

| kind | contoh teks | target | hadiah |
|---|---|---|---|
| `skim` | "NYEREMPET %d kali" | 10, 25, 50 | 50, 100, 150 |
| `coins` | "Kumpulkan %d koin" | 150, 400, 1000 | 50, 100, 200 |
| `pass` | "Lolos %d rintangan" | 5, 15 | 75, 150 |
| `pass_ombak` | "Lolos %d ombak" | 3 | 75 |
| `pass_layangan` | "Lewati %d layangan" | 3 | 75 |
| `pass_hutan` | "Lolos %d lorong hutan" | 2 | 75 |
| `stars` | "Dapatkan %d bintang" | 3, 9 | 75, 150 |
| `endless_island` | "Sampai pulau ke-%d di Tanpa Batas" | 3, 5 | 100, 200 |
| `level_clean` | "Selesaikan %d level tanpa Lanjut" | 1, 3 | 75, 150 |

- Progres **dijumlahkan lintas run**, kecuali `endless_island` (nilai tertinggi dalam satu run).
- Ada 3 misi aktif. Misi pengganti diambil dari templat berikutnya menurut `Game.mission_seq`, dengan dua syarat:
  kind-nya tidak sama dengan misi aktif lain, dan kontennya tersedia (mis. `pass_lava` hanya kalau `gunung` sudah di
  `READY_ISLANDS`; langkah rintangan menambah templatnya).
- **Hadiah diberikan di akhir run** (layar hasil, layar selesai, atau saat keluar lewat jeda): baris misi menampilkan
  "Selesai! +100", koin ditambahkan, lalu misi diganti.
- Misi tampil di **menu** (3 baris dengan bilah progres), **layar jeda**, dan **layar hasil/selesai** (progres run itu).
- `pass_layangan` butuh sinyal baru `Kite.passed` (tiap layangan yang dilewati tanpa kena).
- Simpanan: `Game.level_stars: Dictionary` (id → 0..3), `Game.missions: Array` (`{id, progress}`), `Game.mission_seq: int`.
  Save lama tanpa kunci ini tetap terbaca (nilai bawaan).

## Constraints

- Godot 4.7.2, GDScript bertipe, `maxf/minf/absf/clampf` saat hasil di-assign dengan `:=`. UI dibangun di kode lewat
  `UIKit`, dan gambar (bintang, gembok, pita) lewat `Art.*`. Tidak ada aset baru.
- Teks pemain bahasa Indonesia. Font Fredoka subset latin (tanpa ★ ▶ ←).
- Layar landscape 1280×720, tombol cukup besar untuk jari (tinggi ≥ 72 px).
- Tes dan sim selalu `--nosave`.

## Angka akhir (langkah Petualangan)

- Nama level memakai id pulau ("Sawah Pagi", "Awan Badai"), bukan kata pertama nama pulau (yang menghasilkan "Negeri Pagi").
- Seed level: `1000 + 7·i`. Kesembilan level siap selesai lewat sim autopilot (`cause=selesai`):
  sawah 1100/1354/1531 m, pantai 1090/1388/1692 m, hutan 1119/1301/1575 m. Waktu ±30–45 dtk per level.
- Koin level: sawah 35/54/63, pantai 27/66/82, hutan 53/55/56. Sekitar separuhnya ada di busur tinggi, jadi bintang
  koin menuntut jalur atas yang berisiko. Autopilot tidak mengejar koin, sehingga angka koinnya bukan ukuran kesulitan.
- Layar selesai menampilkan satu baris saran untuk bintang yang belum didapat.
- Perbaikan bug lama: `CoinField.add_item` sekarang menyisipkan koin terurut menurut x. Sebelumnya busur koin dimasukkan
  sebelum koin tanah segmen berikutnya, dan `check()` berhenti di koin pertama di depan burung, sehingga sebagian koin
  tidak pernah bisa diambil (juga di Tanpa Batas).
- Peta tidak memakai gambar gembok atau pita: level terkunci berwarna abu-abu dan nonaktif, dan pulau belum siap diberi
  label "Segera hadir".

## Diserahkan ke pembuat

- Seed tiap level (dipilih supaya bentuknya enak, lalu dikunci), tata letak peta, animasi bintang, dan warna.
- Urutan templat misi.

## Bukti selesai

- Tes data: 18 level, id unik, urutannya sesuai pulau dan tingkat, dan jumlah rintangan pulau 0 sama dengan tingkatnya
  untuk setiap level siap.
- Tes: level selesai saat melewati gerbang. Bintang dihitung benar (tanpa Lanjut, dengan Lanjut, koin di bawah dan di
  atas 60 %). Bonus hanya untuk bintang baru. Level berikutnya terbuka. Pulau belum siap tetap terkunci.
- Tes: layar kalah level punya tepat 3 tombol (Ulangi, Peta, Lanjut), dan layar selesai punya Lanjut, Ulangi, Peta.
- Tes misi: progres tiap kind bertambah dari kejadian yang benar, hadiah diberikan sekali, pengganti tidak dobel kind,
  dan misi untuk pulau terkunci tidak muncul. Save lama terbaca.
- Sim autopilot `--level=<id>` untuk setiap level siap sampai gerbang (`RUN … cause=selesai`).
- Screenshot peta, layar selesai, dan menu dengan panel misi.
- Yang dites pemilik repo: apakah level terasa bertahap dan tidak gabut, dan apakah misi memberi alasan untuk main lagi.
