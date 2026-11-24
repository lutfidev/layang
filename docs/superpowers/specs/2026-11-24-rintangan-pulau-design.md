# Rintangan khas tiap pulau + musik tiap pulau — design

Status: disetujui pemilik repo (2026-11-24, "lanjut"). Langkah 1 selesai (`feat/lorong-kanopi`) · lanjutan dari `2026-11-24-tanpa-batas-design.md`

## Intent (kenapa)

Layang punya 6 pulau (`scripts/data/biomes.gd`): Sawah, Pantai, Hutan, Gunung Api, Danau, Awan. Baru Sawah
(layangan) dan Pantai (ombak gulung) yang punya rintangan khas. Empat pulau lain hanya berbeda warna. Pemilik repo
ingin **rintangan di tiap map sesuai map itu** dan **musik sendiri untuk tiap map**. Dengan begitu tiap pulau
punya rasa dan tantangannya sendiri, dan pindah pulau terasa seperti masuk tempat baru.

Burung selalu maju sendiri. Pemain hanya mengatur **ketinggian** (tahan = naik pakai stamina, lepas = meluncur
turun). Karena itu tiap rintangan menguji cara berbeda dalam mengatur ketinggian:

| Pulau | Rintangan | Keterampilan yang diuji |
|---|---|---|
| Sawah | Layangan warga (sudah ada, PR #4) | pilih rendah atau tinggi, bahaya diam |
| Pantai | Ombak gulung (PR #5) | masuk jendela tinggi yang sempit (terowongan) |
| **Hutan Hujan** | **Lorong kanopi**: atap dahan + semak berduri di tanah | terbang stabil di tengah lorong, tidak menyentuh atas maupun bawah |
| **Gunung Api Senja** | **Semburan lava** dari kawah di lembah | melambung tepat waktu di atas tiang lava |
| **Danau Kunang-kunang** | **Kawanan kelelawar** yang terbang mendekat | membaca ketinggian kawanan dari jauh, lalu lewat di atas atau di bawahnya |
| **Negeri Awan** | **Gerbang awan petir** | membidik celah yang tingginya berubah-ubah |

Semua prinsip dari spec Tanpa Batas tetap berlaku: tanda bahaya terlihat dari jauh, setiap pola bisa dilewati
dengan momentum yang ada, dan pemain paham kenapa dia kalah.

## Goals

- Empat rintangan baru, masing-masing hanya muncul di pulau biome-nya (`hutan`, `gunung`, `danau`, `awan`).
- Tiap rintangan punya **tanda awal** (terlihat ≥ 1 layar sebelumnya), **popup pertama kali** ("Awas ...!"),
  **judul kalah + saran** sendiri, dan cara **Lanjut (iklan)** yang menaruh burung di depan rintangan.
- **Musik sendiri untuk 6 pulau.** Tetap disintesis offline oleh `tools/gen_music.py` tanpa sampel. Saat masuk pulau
  baru, lagu lama memudar ke lagu baru.
- Menu, toko, autopilot, dan sim keseimbangan tetap jalan. Autopilot bisa melewati semua rintangan baru, jadi
  `--sim` tetap berakhir `cause=batas`.

## Non-goals

- Tidak mengubah kontrol, fisika burung, toko, skin, atau ekonomi koin. Tiap rintangan boleh menambah busur koin hadiah.
- Tidak mengubah layangan Sawah dan ombak Pantai.
- Belum ada rintangan campuran antar-pulau, dan belum ada kurva kesulitan. Itu tahap 5 spec Tanpa Batas.
  Riak monster laut (tahap 4 spec Tanpa Batas) tetap di sana.
- Tidak ada aset gambar. Musik adalah satu-satunya aset baru (file `.ogg` hasil generator).

## Anti-goals

- Rintangan yang terasa seperti tembok acak, yaitu muncul atau berubah bentuk saat sudah terlalu dekat.
- Rintangan yang selalu dilewati dengan cara yang sama ("selalu terbang tinggi") di semua pulau.
- Musik yang melelahkan saat diulang, atau berhenti/meletup saat pindah pulau.
- File musik besar yang membuat APK membengkak (> 4 MB total untuk 6 lagu).

## Approaches

- **A. Satu node per rintangan, meniru `Kite`/`Wave` — DIPILIH (keputusan saya).** `Terrain` memilih tempat dan
  mencatat datanya (`canopies`, `vents`, `bat_flocks`, `storm_gates`). Node rintangan menghitung bentuknya sebagai
  fungsi statis yang bisa dites, menggambar dirinya, dan mengecek tabrakan. Polanya sudah teruji dua kali dan
  mudah dites headless.
- B. Sistem rintangan umum yang juga merombak ombak, layangan, dan monster. Lebih rapi, tapi merombak kode yang
  sudah teruji. Ditunda ke tahap 5.
- C. Rintangan sebagai prop di `PropsLayer`. Paling sedikit kode, tapi prop hanya hiasan dan tidak punya animasi
  atau tabrakan. Ditolak.

Ambil sedikit dari B tanpa merombak: di langkah pertama `World` mendapat daftar `_island_hazards` berisi node
rintangan baru yang berbagi antarmuka kecil (lihat "Antarmuka bersama"). Dengan begitu `_update_hazards`,
`clear_hazards`, dan Lanjut tidak perlu disentuh ulang untuk tiap rintangan. `Wave`, `Kite`, dan `SeaMonster`
tetap seperti sekarang.

## Antarmuka bersama (keputusan saya)

Tiap node rintangan baru (`Canopy`, `LavaVent`, `BatFlock`, `StormGate`) adalah `Node2D` dengan:

- `var terrain: Terrain`, `var view_left/view_right: float`, `var hazards := true`
- `signal spotted` (dipancarkan sekali per run saat rintangan pertama ≤ `SPOT_DIST` di depan burung)
- `func update(delta: float, bird_center: Vector2, bird_x: float, bird_on_ground: bool) -> bool`, yang mengembalikan true kalau kena
- `func safe_x_after(x: float) -> float`, yang memajukan x melewati rintangan untuk Lanjut
- `func reset_current() -> void`, yang membersihkan keadaan animasi rintangan terdekat saat Lanjut
- `const CAUSE: String`, `var hit_color: Color`
- statis `span(item) -> Vector2` (rentang x tempat rintangan bisa mengenai) dan `hits(item, t, p) -> bool`

`World` menyimpan `_island_hazards: Array[Node2D]`, memanggil `update` untuk semuanya, dan `_die(h.CAUSE)` saat kena.
`game.gd` mengambil judul/saran dari `CAUSE_TITLES`/`CAUSE_TIPS`. Lanjut memanggil `safe_x_after` semua rintangan
sampai x tidak berubah lagi, karena satu rintangan bisa mendorong burung ke rintangan lain.

Penempatan tiap rintangan memakai RNG terpisah per pulau (seperti layangan: `run_seed * P + k * Q` dengan bilangan
prima baru per rintangan), lewat `Terrain.pick_hills`: **tidak di 2 bukit pertama, tidak berurutan**. RNG bentuk
tanah tidak berubah, jadi seed lama tetap menghasilkan pulau yang sama.

## Langkah 1 — Lorong kanopi (Hutan Hujan)

### Bentuk
- Di pulau `hutan` ada **2 lorong per pulau**. Tiap lorong menutupi satu bukit utuh, dari lembah sebelum puncak
  sampai lembah sesudahnya (kira-kira 900–1400 px).
- **Atap**: massa dahan dan daun gelap yang turun dari atas layar. Tepi bawahnya mengikuti bentuk tanah:
  `atap_y(x) = height_at(x) − GAP`, dengan `GAP` awal **300 px**, dihaluskan supaya tidak bergerigi.
  Pohon raksasa berdiri di mulut lorong sebagai "pintu", dan akar/sulur menjuntai sedikit dari tepi atap.
- **Semak berduri**: menutupi tanah di dalam lorong, tinggi ±40 px, dengan duri merah tua yang terbaca jelas.
- Lorong **diam** (tidak bergerak), jadi celahnya bisa dibaca sejak mulut lorong masuk ke tepi kanan layar.

### Aturan
- Kena atap (tepi bawah atap + radius burung ringan) **atau** menyentuh semak (burung di tanah, atau pusatnya
  < 40 px di atas tanah) di dalam lorong = kalah, penyebab `"hutan"`.
- Burung yang **masuk lorong dari atas atap** juga kalah karena menabrak dahan. Atap tidak punya celah atas:
  tingginya sampai `CEILING_HARD`. Atap dibuat cukup tebal sampai tepi atas layar supaya ini terbaca.
- Jalur bersih di tengah lorong diberi **jalur 8 koin** sebagai pemandu dan hadiah.
- Koin acak biasa tidak ditaruh di zona atap/semak.

### Teks
- Popup pertama: **"Awas lorong hutan!"** / **"Terbang di tengah, jangan sentuh duri"**.
- Kalah: **"Tersangkut di hutan!"**, saran **"Terbang di tengah lorong: jauhi dahan dan semak berduri"**.
- Lolos: popup **"LOLOS HUTAN!"** + 150 poin gaya (sama dengan ombak).

### Keputusan saya (bisa dikoreksi)
- `GAP` 300 px cukup lebar untuk naik/turun mengikuti bukit dengan kecepatan naik 620 dan jatuh 520. Angkanya
  disetel lewat tes "burung yang mengikuti garis tengah lolos" di seluruh rentang kecepatan, termasuk fever ×1,3.
- Stamina: lorong pendek (≤ 1,5 dtk terbang), jadi stamina penuh cukup. Tes memastikan burung yang masuk dengan
  stamina ≥ 0,5 bisa lolos.
- Autopilot: di dalam lorong targetnya garis tengah (`height_at − GAP/2`), dan dia mulai naik sebelum mulut lorong.

### Angka akhir langkah 1
- Bukit lorong dibuat landai: lembah y=40, puncak y=−40, termasuk lembah penutup lorong. Bukit terakhir pulau tidak
  pernah dipilih (`pick_hills(hills − 1, 2, …)`). Alasannya, bukit acak (turun ±400 px dalam 420 px) tidak bisa
  diikuti di lorong 300 px pada kecepatan fever. Urutan RNG bentuk tanah tetap.
- `GAP` 300, semak 40 px, radius tabrakan burung 16 px. Atap digambar dan mematikan sampai y=−2600.
  `roof_y` = rata-rata tinggi tanah di x−60, x, x+60, dikurangi 300.
- 8 koin di garis tengah (10–90 % lebar lorong). Koin acak dijauhkan 60 px dari lorong.
- Pohon raksasa "pintu" di mulut lorong tidak dipakai, karena batangnya menutup lorong secara visual.
- Autopilot sudah lewat lorong dengan ketinggian menyusurinya (±70 px). Tetap ditambah target garis tengah di lorong.
- Sim `--island=2` seed 11: `RUN score=21746 cause=batas`. Seed 4242: `RUN score=21538 cause=batas`.

## Langkah 2 — Semburan lava (Gunung Api Senja)

### Bentuk
- Di pulau `gunung` ada **3 kawah per pulau** di dasar lembah yang dipilih. Lembahnya sedikit diperdalam
  (dasar ≥ y 150) supaya kawah terlihat.
- Urutan tanda dipicu **jarak** (seperti ombak, bukan jam):
  1. **Asap**: mulai saat kawah masuk tepi kanan layar (± 2400 px).
  2. **Menyala**: mulut kawah merah membara dan bergetar (± 1500 px).
  3. **Semburan**: tiang lava naik (± 800 px). Tingginya penuh saat burung ± 300 px dari kawah dan bertahan sampai
     burung lewat, lalu surut 0,9 dtk.
- Tiang lava: lebar ± 120 px, puncaknya **260 px di atas puncak bukit tertinggi di kiri-kanannya**. Dengan begitu
  meluncur datar dari puncak sebelumnya pasti kena, dan harus menahan untuk naik.
- Percikan bara kecil di puncak tiang hanya hiasan (tidak mematikan) supaya bentuk bahayanya tetap jelas.

### Aturan
- Kena tiang (kotak membulat + radius burung yang memaafkan) = kalah, penyebab `"lava"`.
- **Busur 8 koin** di atas tiang sebagai hadiah melambung.

### Teks
- Popup pertama: **"Awas lava!"** / **"Saat kawah menyala, tahan untuk naik"**.
- Kalah: **"Tersembur lava!"**, saran **"Tahan lebih awal saat kawah menyala, lalu terbang di atas semburan"**.
- Lolos: **"LOLOS LAVA!"** + 150 poin gaya.

### Keputusan saya (bisa dikoreksi)
- Tinggi semburan dihitung per kawah dari data bukit sekitarnya, jadi selalu "260 px di atas" bukit di sana,
  bukan angka tetap.
- Tes "bisa dilewati": burung yang mulai menahan saat kawah menyala (1500 px) lolos di seluruh rentang kecepatan.
  Burung yang hanya meluncur kena.
- Autopilot: begitu kawah menyala, targetnya puncak tiang − 120 px.
- Suara: desis (`fizz`) saat menyala dan debur rendah saat menyembur (disintesis di `Sfx`).

## Langkah 3 — Kawanan kelelawar (Danau Kunang-kunang)

### Bentuk
- Di pulau `danau` ada **3 kawanan per pulau**, masing-masing ditautkan ke satu puncak bukit terpilih.
- Kawanan berisi 7 kelelawar dalam **pita mendatar** (± 320 × 90 px) pada ketinggian tetap. Ada dua jenis yang
  dipilih RNG:
  - **Rendah**: pusat pita di `peak_y − 150`. Pemain lewat di atasnya.
  - **Tinggi**: pusat pita di `peak_y − 400`. Pemain lewat di bawahnya (menyusuri bukit).
- Kawanan **terbang ke kiri** mendekati burung dengan kecepatan tetap (± 150 px/dtk) mulai saat masuk layar, sambil
  mengepak. Kepakan menggerakkan tiap kelelawar ± 12 px naik-turun, tapi pita tidak pernah pindah ketinggian.
  Kelelawar tidak mengejar burung.
- **Tanda**: pasangan **mata kuning menyala** yang terlihat jelas di langit malam, ditambah cicit (`Sfx`) saat
  kawanan masuk layar.

### Aturan
- Kena kelelawar (lingkaran kecil per kelelawar, lebih kecil dari gambarnya) = kalah, penyebab `"kelelawar"`.
- Jalur aman yang berlawanan dari pita diberi **6 koin** (di atas kawanan rendah, di bawah kawanan tinggi).

### Teks
- Popup pertama: **"Awas kelelawar!"** / **"Lihat matanya, lewat di atas atau di bawah"**.
- Kalah: **"Ditabrak kelelawar!"**, saran **"Lihat ketinggian kawanan dari jauh, lalu lewat di atas atau di bawahnya"**.
- Lolos: **"LOLOS KAWANAN!"** + 100 poin gaya.

### Keputusan saya (bisa dikoreksi)
- Posisi kawanan dihitung dari waktu sejak terlihat, jadi tetap bisa dites. Di tes, x kawanan pada waktu t =
  `x_awal − 150·t`. `x_awal` dipilih supaya kawanan bertemu burung tepat di atas puncak yang ditautkan untuk
  kecepatan burung khas. Kalau burung lebih cepat atau lambat, titik temunya bergeser sedikit tapi bentuknya sama.
- Gelapnya malam tetap. Mata kelelawar dan pantulan kunang-kunang cukup untuk membacanya.
- Autopilot: pita rendah → target `pita_atas − 90`. Pita tinggi → menyusuri bukit seperti biasa.

## Langkah 4 — Gerbang awan petir (Negeri Awan)

### Bentuk
- Di pulau `awan` ada **3 gerbang per pulau**, masing-masing di x puncak bukit terpilih.
- Satu gerbang terdiri dari **dua awan petir gelap**: awan bawah dari tanah sampai tepi bawah celah, dan awan atas
  dari tepi atas celah sampai `CEILING_HARD` (digambar sampai tepi atas layar).
- **Celah terang** setinggi **260 px**. Pusatnya dipilih RNG antara `peak_y − 220` dan `peak_y − 620`, jadi
  tingginya berbeda di tiap gerbang. Celah diberi pinggiran cahaya lembut supaya terbaca sebagai "pintu".
- Tebal gerbang ± 160 px. Kilat kecil berkedip di dalam awan tiap ± 1,2 dtk sebagai tanda bahaya (hiasan, tidak
  mengubah bentuk). Awan bergoyang pelan ± 10 px, celahnya tetap.

### Aturan
- Masuk awan petir = kalah, penyebab `"petir"`.
- **5 koin** berderet di tengah celah.

### Teks
- Popup pertama: **"Awas awan petir!"** / **"Lewat celah terang di antaranya"**.
- Kalah: **"Tersambar petir!"**, saran **"Bidik celah terang sejak awan terlihat"**.
- Lolos: **"LOLOS PETIR!"** + 100 poin gaya.

### Keputusan saya (bisa dikoreksi)
- Celah tertinggi `peak_y − 620` masih jauh di bawah `CEILING_SOFT`. Tes "bisa dilewati": burung yang mulai
  membidik saat gerbang masuk layar (± 1300 px) lolos di semua tinggi celah dan rentang kecepatan.
- Autopilot: target pusat celah sejak gerbang ≤ 1500 px di depan.
- Suara: gemuruh rendah (`Sfx.play("thunder")`, noise + nada rendah) saat gerbang pertama masuk layar.

## Langkah 5 — Musik tiap pulau

### Isi
- `tools/gen_music.py` diberi parameter per pulau dan menulis **6 file** `assets/audio/music_<id>.ogg`
  (`sawah`, `pantai`, `hutan`, `gunung`, `danau`, `awan`). Lagu Sawah menggantikan `gamelan_loop.ogg` (file lama dihapus).
  Generator tetap berupa sintesis murni (numpy + ffmpeg). Hasilnya di-commit, jadi build tidak perlu Python.
- Karakter tiap lagu (keputusan saya):

| Pulau | Rasa | Tangga nada / tempo | Instrumen sintesis |
|---|---|---|---|
| Sawah | pagi tenang | slendro, 84 BPM (lagu sekarang) | saron, bonang, kenong, gong, pad |
| Pantai | ceria, siang | slendro tinggi, 104 BPM | saron cepat, kendang (noise ber-envelope), angklung (bambu bergetar) |
| Hutan | lembab, misterius | pelog, 76 BPM | suling (sinus + napas noise), gambang kayu, rintik hujan (noise berbintik) |
| Gunung | tegang, senja | pelog rendah, 92 BPM | gong ageng sering, bonang rendah berulang, kendang berat |
| Danau | malam, lembut | pelog, 66 BPM | gender lembut, celempung petik, jangkrik halus |
| Awan | melayang, terang | slendro, 72 BPM | lonceng tinggi bergema panjang, pad lebar |

- Panjang tiap lagu 32–48 ketukan, loop mulus (indeks dibungkus seperti sekarang), ogg `-q:a 3`, maksimal 600 KB per file.
- **`Sfx.play_music(id: String)`**: dua `AudioStreamPlayer` dengan crossfade 1,5 dtk. Memanggil id yang sedang diputar
  tidak berbuat apa-apa. Pengaturan Musik on/off tetap dihormati (off = keduanya berhenti, on = lanjut lagu terakhir).
- **Kapan dipanggil**: `World` memanggil `Sfx.play_music(biome.id)` saat dunia dibuat dan saat `_change_biome`.
  Menu dan toko jadi ikut memutar lagu pulau yang tampil.
- CLAUDE.md diperbarui: aset audio = `assets/audio/music_*.ogg`, dibuat oleh `tools/gen_music.py`.

### Keputusan saya (bisa dikoreksi)
- Crossfade dimulai di awal `_change_biome` (saat lewat batas laut), bersamaan dengan langit yang berganti.
- Volume tiap lagu dinormalkan ke puncak yang sama supaya tidak ada pulau yang tiba-tiba keras.

## Constraints

- Godot 4.7.2, GDScript bertipe, `maxf/minf/absf/clampf` saat hasil di-assign dengan `:=`.
- Semua gambar digambar di kode (`Art.*`) atau shader. Target Android, jadi gambar harus ringan: gambar hanya item
  yang terlihat (`view_left/right`), polygon sederhana.
- Teks pemain bahasa Indonesia. Font Fredoka subset latin, jadi jangan pakai simbol ▶ ★ ←.
- Dunia `hazards = false` (menu/toko): rintangan tetap digambar, tidak mematikan.
- Sim dan screenshot selalu `--nosave`. Tiap rintangan mendapat perintah screenshot dengan seed tetap di CLAUDE.md.

## Diserahkan ke pembuat

- Angka pasti (GAP, tinggi tiang, jarak picu, ukuran kawanan/celah, radius kena) yang disetel lewat tes
  "bisa dilewati" + "kena kalau salah" dan screenshot.
- Bentuk gambar `Art.*` dan detail struktur kode di dalam antarmuka bersama.

## Bukti selesai (tiap langkah rintangan)

- Tes penempatan: untuk beberapa seed, tiap pulau biome itu punya jumlah rintangan yang benar, tidak di 2 bukit
  pertama, tidak berurutan. Pulau lain tidak punya.
- Tes jalur: burung yang mengikuti jalur benar lolos di seluruh rentang kecepatan (`SPEED_START` sampai `SPEED_MAX`,
  plus fever). Burung yang salah jalur kalah dengan penyebab yang benar.
- Tes: judul/saran layar kalah benar. Lanjut menaruh burung di depan rintangan dan skor tidak turun.
  `hazards = false` tidak pernah mati.
- Sim `--sim --island=<pulau>` dengan seed 11 dan 4242 berakhir `cause=batas`.
- Screenshot dengan seed tetap memperlihatkan tanda awal dan rintangannya.
- Yang tidak bisa dibuktikan mesin: apakah rintangan **terbaca** dan **seru**. Itu dites pemilik repo.

## Bukti selesai (musik)

- 6 file ogg ada, masing-masing ≤ 600 KB, loop mulus (sampel akhir ≈ awal, dicek di generator).
- Tes: `Sfx.play_music("hutan")` lalu `play_music("hutan")` tidak memulai ulang. Ganti id memulai crossfade.
  Musik off menghentikan keduanya.
- Cek headless tanpa error, termasuk menu.

## Urutan langkah dan plan

| Langkah | Plan |
|---|---|
| 1 Lorong kanopi (Hutan) + daftar `_island_hazards` | `docs/superpowers/plans/2026-11-24-lorong-kanopi.md` |
| 2 Semburan lava (Gunung) | `docs/superpowers/plans/2026-11-24-semburan-lava.md` |
| 3 Kawanan kelelawar (Danau) | `docs/superpowers/plans/2026-11-24-kelelawar-danau.md` |
| 4 Gerbang awan petir (Awan) | `docs/superpowers/plans/2026-11-24-awan-petir.md` |
| 5 Musik tiap pulau | `docs/superpowers/plans/2026-11-24-musik-pulau.md` (tidak bergantung pada 1–4) |

Langkah 2–4 butuh langkah 1, karena antarmuka bersama dibuat di sana. Sesudahnya baru tahap 4 (riak monster) dan
tahap 5 (urutan + kurva kesulitan) dari spec Tanpa Batas, yang sekarang mencakup keenam rintangan.
