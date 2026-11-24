# Layang Tanpa Batas — design

Status: disetujui (tahap 1 selesai, PR #2; tahap 2 selesai, PR #3; tahap 3 menunggu persetujuan, `feat/layangan-sawah`) · 2026-11-24 · lanjutan dari `2026-11-24-tahan-naik-design.md`

## Intent (kenapa)

Timer "senja mengejar" terasa menekan dan bukan tantangan yang menyenangkan. Layang diubah menjadi
**game terbang tanpa batas**. Pemain kalah hanya karena rintangan. Inti kesenangannya:
**melihat bahaya dari jauh, lalu memutuskan kapan menukik dan kapan melambung**. Momen yang dicari:
"wah, hampir kena!". Kalau gagal, pemain paham apa yang harus dia lakukan berbeda di percobaan berikutnya.

## Goals

- Kontrol tetap seperti sekarang: tahan = naik (pakai stamina), lepas = meluncur turun.
- Lari tanpa batas. **Timer, bar waktu, bonus waktu pulau, dan item "+3 detik" dihapus.**
  Langit tetap berubah sesuai suasana tiap pulau (tidak lagi jadi tanda waktu habis).
- Tiga rintangan awal, masing-masing terikat pada tempatnya:
  1. **Ombak pantai.** Di teluk kecil di lembah pulau Pantai. Air mulai berbuih sebelum ombak naik.
     Tandanya terlihat sejak turunan sebelumnya. Pemain mengumpulkan momentum, lalu lepas di bibir
     bukit untuk melompati ombak.
  2. **Layang-layang warga di sawah.** Ekornya berkibar di jalur atas. Pemain yang biasanya melambung
     tinggi demi koin bisa memilih terbang rendah dan lewat di bawah ekornya.
  3. **Monster laut.** Sudah ada. Jadi kejutan sesekali, didahului **riak besar yang bergerak di permukaan**.
- Pengenalan bertahap: di awal permainan kenalkan satu rintangan dulu dan beri ruang belajar.
  Makin jauh, posisi dan urutannya makin bervariasi.
- **Setiap pola harus bisa dilewati dengan momentum yang tersedia.**
- Sesekali ada dua pilihan jalur. Contoh: jalur bawah aman, jalur atas dekat ekor layang-layang
  koinnya lebih banyak.
- Saat kalah: tampilkan penyebabnya (mis. "Terkena ombak") dan **tepat tiga tombol**:
  **Main Lagi**, **Menu**, **Lanjut (tonton iklan)**. Setelah iklan, burung kembali terbang di bagian
  lintasan yang aman dan skor tetap lanjut.

## Non-goals

- Tidak ada darah atau nyawa. Satu kena rintangan = kalah (lanjut lewat iklan adalah satu-satunya "nyawa").
- Tidak mengubah kontrol, toko, skin, atau ekonomi koin.
- Tidak ada rintangan selain ketiga di atas di putaran ini.

## Anti-goals (gagal walau "jalan")

- Bahaya yang muncul tanpa tanda, atau tandanya baru terlihat saat sudah terlambat bereaksi.
- Pola yang mustahil dilewati dengan kecepatan yang ada.
- Pemain kalah tanpa paham kenapa.
- Iklan yang terasa memaksa. Lanjut hanya lewat tombol yang dipilih pemain.

## Tahapan

| Tahap | Isi | Tujuan tes |
|---|---|---|
| **1 (prototipe)** | Ombak pantai saja | Apakah buih terlihat dari jauh? Apakah melompati ombak terasa puas? |
| 2 | Hapus timer + layar kalah 3 tombol + lanjut di tempat aman | Lari tanpa batas berfungsi |
| 3 | Layang-layang warga di sawah + jalur pilihan koin | Pilihan rendah vs tinggi |
| 4 | Riak besar sebelum monster laut, monster jadi kejutan sesekali | "Hampir kena!" di laut |
| 5 | Urutan pengenalan + variasi pola makin jauh | Kurva kesulitan |

Tiap tahap direncanakan dan dites terpisah. Dokumen ini mendetailkan **tahap 1**. Tahap 2–5 dicatat
di sini sebagai arah, dan didetailkan sebelum masing-masing mulai.

## Approaches (untuk ombak)

- **A. Teluk kecil di lembah bukit Pantai — DIPILIH.** Beberapa lembah di pulau Pantai diisi air menjadi teluk,
  dan ombak naik di sana. Dalam satu pulau ada 3–5 kesempatan, cukup untuk merasakan tandanya dan lompatannya.
  Biayanya: bentuk tanah perlu diubah agar ada air di tengah pulau.
- B. Ombak di tepi laut antar-pulau. Paling murah, tapi hanya sekali per pulau, terlalu jarang untuk belajar.
- C. Ombak bergulung yang bergerak mendekat. Dramatis, tapi susah dibaca dari jauh, bertentangan dengan intent.

Pemain memilih A (2026-11-24).

## Tahap 1 — Ombak pantai (detail)

### Yang diputuskan bersama
- Ombak ada di **teluk di lembah pulau Pantai** (biome `pantai`).
- Urutannya: **buih dulu (tanda), lalu ombak naik**. Buih terlihat sejak turunan sebelumnya.
- Cara melewatinya: momentum dari turunan, lalu lepas di bibir bukit untuk melompat.
- Kena ombak = kalah, judul hasil **"Terkena ombak"**.
- **Bibir pelontar** (diputuskan saat menulis plan): fisika sekarang tidak memberi momentum dari tanjakan
  (puncak bukit datar, gravitasi kuat), jadi bibir sebelum teluk adalah ramp. Burung yang menyentuh tanah di
  zona `[lip_x-40, lip_x+10]` dilempar ke atas dengan `vel.y = -620`. Ramp diberi pita oranye dan panah putih
  supaya terbaca. Mendarat di tepi seberang teluk tidak pernah dihitung bonk.
- Ada opsi dev untuk langsung mulai di pulau Pantai (`--island=1` sudah ada, karena Pantai biome ke-2).
- Dibuat serius, bukan buang-buangan. Timer tetap ada di tahap ini (dihapus di tahap 2). `--time=` bisa dipakai saat tes.

### Keputusan saya (bisa dikoreksi)
- **Teluk**: lembah yang dipilih di pulau Pantai diturunkan di bawah `WATER_Y` supaya terisi air, dengan lebar
  yang bisa dilompati. Bibir bukit sebelum teluk dibuat sebagai landasan (turunan lalu tanjakan pendek),
  dan bukit setelahnya cukup rendah untuk mendarat.
- **Jumlah dan letak**: 3 teluk per pulau Pantai. Teluk pertama tidak dalam 2 bukit pertama (ruang belajar),
  dan tidak pernah dua teluk berturut-turut.
- **Jatuh ke air teluk** tanpa kena ombak tetap kalah, dengan penyebab yang sama seperti laut ("Tercebur ke laut!").
  **Monster laut tidak muncul di teluk**: monster tetap hanya di laut antar-pulau.
- **Waktu ombak dipicu jarak, bukan jam**. Buih mulai saat teluk masuk ke tepi kanan layar, jadi pemain selalu
  melihat tandanya dari puncak sebelumnya. Ombak naik saat burung mendekati bibir bukit, mencapai puncak saat
  burung di atas teluk, lalu surut. Jadi ombak selalu menjadi tantangan, bukan kebetulan waktu.
- **Tinggi ombak**: cukup tinggi sehingga meluncur datar dari bibir bukit tanpa momentum akan kena, tapi lepas
  di bibir bukit setelah menukik melewatinya dengan jarak aman. Menahan (naik) juga boleh dipakai untuk
  melewati; itu pilihan yang sah, hanya menguras stamina.
- **Berhasil lewat**: popup kecil (mis. "LOLOS OMBAK!") plus poin gaya, supaya terasa puas. Angka poin diserahkan ke pembuat.
- **Tampilan**: buih = titik-titik putih yang bergolak dan makin padat; ombak = dinding air tosca warna biome
  `water`/`water_top` dengan bibir buih putih yang melengkung, digambar di kode (`Art.*`), dengan bayangan
  seperti monster. Suara: desis buih dan debur saat naik (`Sfx`, disintesis seperti suara lain).
- **Teluk bukan laut**: `Terrain` harus bisa membedakan air teluk dari laut antar-pulau (untuk monster dan
  hitungan pulau). Tidak ada koin tanah di atas air teluk, dan terbang rendah di atas teluk tidak dihitung NYEREMPET.
- **Kecepatan**: "bisa dilewati" berlaku di seluruh rentang kecepatan yang mungkin dimiliki burung di pulau
  Pantai, dari `SPEED_START` (kalau mulai dengan `--island=1`) sampai kecepatan khas di jarak itu dalam lari normal.
- **Menu/toko** (`hazards = false`): teluk tetap ada sebagai pemandangan, ombak tidak membunuh, dan air teluk
  memantulkan burung seperti laut sekarang.
- **Autopilot** (`--autoplay`, menu demo, sim) harus bisa melewati teluk dan ombak dengan reaksi manusiawi,
  supaya sim keseimbangan tetap berguna.

### Angka akhir tahap 1
- Teluk: lembah y=60, bibir y=-60 (tanjakan 480 px), dasar y=380, tepi seberang y=40, jarak bibir→dasar→tepi
  300 px; air ≈ 180 px lebar. 3 teluk per pulau Pantai, tidak di 2 bukit pertama, tidak berurutan.
- Ombak: tinggi 200 px (puncak y=100), kolom ±70 px di tengah teluk; buih mulai 1900 px sebelum tengah teluk,
  naik dari 750 px, penuh dari 200 px; surut 0,9 dtk. Lolos = +150 poin gaya, popup "LOLOS OMBAK!".
- Margin terukur: burung terlempar paling lambat berada di y≈-106 di atas kolom ombak (puncak y=100).
- Popup "Awas ombak!" saat pulau Pantai tercapai atau saat run dimulai di Pantai.

### Diserahkan ke pembuat
- Angka pasti: lebar/kedalaman teluk, tinggi dan durasi ombak, radius kena, jarak picu.
- Struktur kode (mis. kelas `Wave` mirip `SeaMonster`, data teluk dari `Terrain`).

### Bukti selesai (tahap 1)
- Tes headless: untuk **setiap** teluk yang dihasilkan pada beberapa seed, burung yang menukik lalu lepas di bibir
  bukit dengan kecepatan khas melewati ombak; burung yang meluncur pelan dan rendah kena ombak.
- Tes: kena ombak → `bird_died("ombak")` → judul "Terkena ombak"; monster tidak muncul di teluk.
- Sim autopilot di pulau Pantai tidak kalah di setiap teluk (ombak bisa dilewati, bukan lotre).
- Screenshot: buih terlihat di tepi kanan layar saat burung di puncak sebelumnya.
- Semua tes lama tetap lulus, dan menu/toko jalan tanpa error.
- Yang tidak bisa dibuktikan mesin: **apakah buih "kelihatan" dan lompatan "puas"**. Itu dites pemain.

## Tahap 2 — Tanpa timer + layar kalah 3 tombol (detail)

### Keputusan saya (bisa dikoreksi)
- **Dihapus:** `time_left`, bar waktu dan angka detik di HUD, status `night`/senja (burung mengantuk, `Bird.sleepy`),
  bonus waktu pulau (banner pulau tidak lagi menulis "+N detik"), bola matahari "+3 detik" (`CoinField.SUN`),
  flag dev `--time=`. Bonus pulau lain tetap: +500 poin, +20 koin.
- **Langit:** `sun_progress` tetap (0,8) dan `dusk` 0. Suasana langit tetap berganti per pulau lewat warna biome.
- **Layar kalah:** judul penyebab + satu baris saran ("Sentuh bibir oranye untuk melompat" dsb.) supaya pemain
  paham apa yang harus dicoba berbeda, skor, statistik, lalu **tepat tiga tombol**: **Main Lagi**, **Menu**,
  **Lanjut (tonton iklan)**. Tombol "Koin ×2 (iklan)" dihapus karena spec meminta tepat tiga tombol
  (asumsi baru: sedikit mengubah ekonomi koin, dicatat di PR).
- **Lanjut hanya sekali per run** (seperti sebelumnya). Setelah dipakai, tombolnya tetap tampil tapi nonaktif
  ("Lanjut sudah dipakai"), jadi layar selalu punya tiga tombol.
- **Tempat aman:** semua kematian terjadi di atas air (laut, teluk, ombak, monster). Saat lanjut, burung dipindah
  **maju** ke tanah kering pertama setelah air itu (+120 px), 200 px di atas tanah, kecepatan ≥ 500, stamina penuh,
  monster/ombak dibersihkan. Skor tidak pernah turun (jarak hanya bertambah sedikit). Popup "Terbang lagi!".
- **Sim keseimbangan:** karena lari tidak berakhir sendiri, mode `--sim` berhenti setelah `--sim-max=S` detik
  (bawaan 240) dengan `cause=batas`.

### Bukti selesai (tahap 2)
- Tes: tidak ada lagi `time_left`/`night`; berjalan 60 dtk tanpa rintangan tidak mengakhiri run.
- Tes: layar kalah punya tepat tiga tombol bernama Main Lagi, Menu, Lanjut; setelah lanjut sekali, tombol Lanjut nonaktif.
- Tes: lanjut setelah mati di laut dan di teluk menempatkan burung di atas tanah kering dan skor tidak turun.
- Sim `--sim` selesai dengan `RUN score=…`.

## Tahap 3 — Layang-layang warga di sawah (detail)

### Yang diputuskan bersama
- **Yang mematikan: badan layangan dan ekornya.** Tali dari tangan warga hanya hiasan dan bisa ditembus
  (boleh bergoyang sedikit saat burung lewat). Alasannya: kalau tali ikut mematikan, jalur bawah tidak lagi aman.
- **Cara membangun: node `Kite` sendiri, meniru pola ombak** (lihat Approaches di bawah).

### Approaches
- **A. Node `Kite` sendiri seperti `Wave` (dipilih).** `terrain` mencatat posisi layangan, `Kite` menggambar dan
  mengecek tabrakan, `world._update_hazards` memanggilnya. Polanya sama dengan ombak dan mudah dites headless.
- B. Sistem rintangan umum untuk ombak/layangan/monster. Lebih rapi, tapi merombak dua rintangan yang sudah
  teruji demi satu yang baru. Kalau perlu, dipertimbangkan di tahap 5.
- C. Layangan sebagai prop di `PropsLayer` plus cek tabrakan. Paling sedikit kode, tapi prop hanya hiasan tanah;
  animasi ekor dan tabrakan tidak cocok di sana dan sulit dites.

### Keputusan saya (bisa dikoreksi)
- **Tempat:** hanya di pulau biome `sawah`, **2 layangan per pulau**, di puncak bukit yang dipilih dengan RNG
  terpisah (seperti `pick_bay_hills`): tidak di 2 bukit pertama, tidak berurutan. `terrain.kites` diurutkan
  menurut x: `{x, peak_y, island}`, dengan `x` = x puncak.
- **Bentuk tetap dan terbaca dari jauh:** layangan **tidak berpindah**. Badan (belah ketupat ±34×44 px) bergoyang
  pelan ±8 px. Ekor (8–10 pita) tergantung dari badan ke bawah, berkibar **hanya ke samping** (±20 px), jadi ujung
  bawahnya selalu di ketinggian yang sama. Celah aman di bawahnya tidak pernah berubah.
- **Ukuran awal (disetel lewat tes):** badan di sekitar `peak_y − 400`, ujung ekor **≥ 170 px di atas tanah** di
  seluruh lebar ekor. Burung yang terbang menyusuri bukit (autopilot ±70 px, `SKIM_HEIGHT` 90) lewat di bawahnya.
  Jalur atas lewat di atas badan (masih jauh di bawah `CEILING_SOFT`).
- **Tabrakan memaafkan:** badan pakai jarak ke belah ketupat + `RADIUS`; ekor pakai jarak ke ruas-ruas polylinenya
  < 10 px + ukuran kecil burung. Lebih kecil dari gambarnya supaya serempetan terasa "hampir kena!", bukan kalah.
- **Pilihan koin:** di setiap layangan, busur koin biasa di puncak itu diganti **busur 10 koin** yang melengkung
  di atas badan layangan (jalur atas berisiko, hadiah lebih besar). Jalur bawah **tidak** dapat koin tambahan
  (aman tapi sedikit). Busur acak biasa tidak boleh ditaruh di dekat layangan.
- **Warga:** berdiri di lereng naik sebelum puncak, memegang tali yang naik miring ke badan layangan. Digambar
  sebagai `Art.*` (tanpa aset).
- **Tanda awal:** layangan pertama di run memunculkan popup "Awas layangan!" / "Terbang rendah di bawah ekornya"
  (seperti "Awas ombak!"). Layangan sudah terlihat sejak satu layar sebelumnya karena diam di tempat.
- **Kalah:** penyebab `"layangan"`, judul **"Tersangkut layangan!"**, saran
  **"Terbang rendah di bawah ekor, atau tinggi di atasnya"**. Getar layar dan percikan kertas warna-warni.
- **Lanjut:** kematian ini terjadi di atas darat. Burung dipindah maju ke
  `maxf(dry_ground_after(x), ujung_kanan_layangan + 200)`, aturan lain sama seperti tahap 2 (skor tidak turun).
- **Dunia menu/toko (`hazards = false`):** layangan tetap digambar, tidak mematikan. Autopilot (menyusuri ±70 px)
  sudah lewat di bawah ekor, jadi tidak perlu logika baru. Sim tetap mencapai batas 240 dtk.
- **Di luar tahap ini:** layangan di pulau lain, layangan yang bergerak, dan dua layangan berdekatan (tahap 5).

### Bukti selesai (tahap 3)
- Tes: untuk beberapa seed, setiap pulau Sawah punya tepat 2 layangan, tidak di 2 bukit pertama, tidak berurutan;
  ujung ekor ≥ 170 px di atas tanah di seluruh lebar ekor.
- Tes headless: burung yang menyusuri bukit lewat di bawah setiap layangan tanpa kalah; burung yang melintas setinggi
  badan layangan kalah dengan `bird_died("layangan")`; burung yang lewat di atas badan selamat.
- Tes: judul layar kalah "Tersangkut layangan!"; lanjut menempatkan burung di depan layangan dan skor tidak turun.
- Tes: dunia `hazards = false` tidak pernah mati karena layangan.
- Sim `--sim` (seed 11 dan 4242) tetap `cause=batas`. Screenshot pulau Sawah memperlihatkan layangan, warga, tali,
  dan busur koin.

## Constraints

- Godot 4.7.2, GDScript bertipe, semua gambar digambar di kode (`Art.*`) atau shader; tidak ada aset baru.
- Teks untuk pemain berbahasa Indonesia; font Fredoka (hindari simbol seperti ▶ ★).
- Target Android: performa gambar ombak harus ringan.
- Sim dan screenshot selalu pakai `--nosave`.
