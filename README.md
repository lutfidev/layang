# LAYANG
**Terbang tanpa batas melintasi Nusantara.**

Game arcade *one-touch* untuk Android (landscape) yang dibuat dengan Godot 4.7.2. Semua visual digambar lewat kode dan shader. Musiknya disintesis, jadi proyek ini tidak memakai aset gambar sama sekali dan ukurannya kecil.

---

## 1. Pitch
Seekor burung kecil terbang di atas bukit-bukit. **Tahan layar** = burung naik (menghabiskan stamina). **Lepas** = burung meluncur turun. Terbang rendah menyerempet bukit untuk combo, dan hati-hati di laut: tercebur atau digigit monster laut berarti run selesai. Tidak ada batas waktu: run hanya berakhir karena rintangan (laut, monster laut, ombak di teluk Pantai). Lihat bahayanya dari jauh, lalu putuskan kapan menukik dan kapan melambung. Setiap pulau baru menampilkan pemandangan baru.

* **Mudah dipahami dalam 3 detik, butuh waktu lama untuk mahir.** Formula ini sudah terbukti di Tiny Wings, Alto's Adventure, dan Hill Climb.
* **Sesi pendek (1–3 menit)**, sehingga cocok dengan iklan berhadiah di akhir run.
* **6 scene berbeda** yang mendorong pemain untuk "main sekali lagi biar bisa lihat pulau berikutnya".

## 2. Cara main
| Input | Efek |
|---|---|
| Tahan layar / Spasi / ↑ / W | Naik (stamina berkurang; habis = tidak bisa naik sampai terisi lagi) |
| Lepas | Meluncur turun, stamina terisi (lebih cepat di tanah) |
| Terbang rendah di atas bukit ≥ 0,6 dtk | **NYEREMPET!** +poin beruntun |
| 3× NYEREMPET beruntun | **FEVER**: koin ×2 + magnet koin |
| Menyentuh tanah | Combo reset; jatuh keras / tanjakan curam = **Aduh!** kecepatan turun |
| Menyentuh air laut | Run selesai (**Tercebur ke laut!**) |
| Monster laut (gelembung = peringatan ~1 dtk) | Terbang tinggi! Kena gigit = run selesai |
| Ombak di teluk Pantai (buih = tanda) | Sentuh bibir oranye untuk melompat; kena ombak = run selesai |
| Pulau baru | +20 koin, +500 poin |
| Kalah | Layar kalah: penyebab + saran, tombol **Lanjut (tonton iklan)**, **Main Lagi**, **Menu** |

## 3. Enam pulau
1. **Sawah Fajar**: terasering, lumbung, langit pink, biji ilalang melayang
2. **Pantai Siang**: pasir bergaris, nyiur, jukung di laut tosca, kilau air
3. **Hutan Hujan**: kabut, pohon tinggi, pakis, jamur, hujan
4. **Gunung Api Senja**: gunung berasap, pohon mati, bara melayang
5. **Danau Kunang-kunang**: malam berbintang, bulan, alang-alang, lentera, kunang-kunang
6. **Negeri Awan**: lautan awan pastel, bintang, gemerlap

Setelah pulau ke-6, siklusnya berulang dengan bukit yang lebih tinggi dan panjang. Setiap pulau berakhir di gerbang **candi bentar** dan laut sebelum pulau berikutnya.

## 4. Monetisasi (sudah ada di kode, sekarang masih mode demo)
| Sumber | Lokasi | Catatan |
|---|---|---|
| Rewarded: **Lanjut** (terbang lagi di tanah aman, skor lanjut) | Layar kalah | 1× per run |
| Interstitial | Setiap 3 run | Mati jika "Hapus Iklan" dibeli |
| IAP **Hapus Iklan** | Menu | Rp 25.000 |
| IAP **Garuda Emas** | Toko | Rp 15.000 (atau 3.500 koin) |
| IAP **1.500 koin** | Toko | Rp 15.000 |
| Hadiah harian | Menu | 50 → 500 koin, streak 7 hari |

Ekonomi (dari simulasi autopilot versi bertimer; dihitung ulang di tahap 5 "tanpa batas"): satu run menghasilkan ±70–100 koin. Skin pertama (300) bisa dibeli setelah ±3 run, sedangkan Garuda (3.500) butuh puluhan run. Celah inilah yang mendorong orang menonton iklan atau membeli IAP.

Semua pemanggilan iklan/IAP lewat `scripts/autoload/ads.gd`. Untuk go-live, ganti bagian yang bertanda `# INTEGRATE:` dengan plugin **AdMob** (misalnya Godot AdMob by poing-studios) dan **Google Play Billing**. Bagian game lainnya tidak perlu diubah.

## 5. Menjalankan
1. Install **Godot 4.7.x** (dites dengan 4.7.2).
2. Godot, lalu *Import*, lalu pilih `project.godot`, lalu ▶ (F5).
3. Di PC: klik mouse / Spasi / ↑ / W = tahan. Esc = jeda.

### Flag dev (untuk testing)
Jalankan dari terminal: `godot --path . res://scenes/game.tscn -- --island=3 --autoplay --die=ombak`
* `--island=N` mulai dari pulau N (0–5)
* `--autoplay` burung dimainkan AI
* `--die=penyebab` (laut/monster/ombak) langsung kalah setelah 2 dtk, untuk mengetes layar kalah
* `--seed=N` seed lintasan tetap
* `--sim --sim-max=S` (di `game.tscn`) run autopilot berhenti setelah S detik (bawaan 240) dan mencetak `RUN score=…`
* `--coins=N`, `--fresh` (abaikan save)
* `--shot=path.png --shot-delay=4` ambil screenshot lalu keluar
* `scenes/dev_world.tscn -- --sim --sim-time=60` simulasi headless untuk balancing

## 6. Struktur
```
scenes/          main_menu, game, shop, dev_world (semua root + script, UI dibangun di kode)
scripts/autoload game_state.gd (Game: save, koin, skin, harian, transisi)
                 sfx.gd (Sfx: SFX sintetis + musik), ads.gd (Ads: iklan & IAP)
scripts/data     biomes.gd (6 pulau = data), skins.gd (6 burung)
scripts/world    world.gd (kamera, langit, transisi), terrain.gd (bukit prosedural, laut, props)
                 bird.gd (fisika + gambar burung), backdrop.gd (parallax 3 lapis)
                 ambient.gd (partikel cuaca), coin_field.gd, art.gd (semua gambar vektor)
scripts/ui       game.gd (aturan + HUD + jeda + hasil), main_menu.gd, shop.gd, ui_kit.gd
shaders/         hill (garis/terasering/titik), sky (gradien, matahari, bintang, senja), water
tools/           gen_music.py (bikin ulang loop gamelan: python3 tools/gen_music.py)
```
Menambah pulau baru cukup dengan menambah satu dictionary di `biomes.gd`. Menambah burung cukup dengan menambah satu entri di `skins.gd`.

## 7. Lanjut pakai Claude + godot-mcp
```bash
# Claude Code (Windows: arahkan ke exe Godot kamu)
claude mcp add godot -e GODOT_PATH="D:/Tools/Godot/Godot_v4.7.2-stable_win64.exe" -- npx @coding-solo/godot-mcp
```
Setelah itu buka folder proyek ini di Claude Code. File `CLAUDE.md` berisi peta arsitekturnya. Contoh perintah: *"jalankan proyek pakai godot mcp dan cek error"*, *"tambah pulau ke-7: Kota Lama Malam"*.

## 8. Rencana 7 hari sampai rilis
| Hari | Target |
|---|---|
| 1 | Main di HP (export debug APK), rasakan fisika, setel `DIVE_MULT`, `START_TIME`, dan bonus pulau |
| 2 | Pasang plugin AdMob (pakai ID uji), sambungkan ke `ads.gd` |
| 3 | Google Play Billing + uji IAP (license tester) |
| 4 | Polish: getar (haptic) saat MULUS, ikon, splash, layar pengaturan |
| 5 | Misi harian sederhana (mis. "3× FEVER") untuk retensi |
| 6 | Internal testing di Play Console + Firebase Analytics (opsional) |
| 7 | Screenshot store (pakai `--shot`), deskripsi, rilis closed/open testing |

## Lisensi aset
Font Fredoka: SIL Open Font License 1.1 (`assets/fonts/OFL.txt`). Kode, visual, dan musik dibuat khusus untuk proyek ini.
