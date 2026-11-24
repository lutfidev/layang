# Layang Tanpa Batas — design

Status: draft, menunggu persetujuan · 2026-11-24 · lanjutan dari `2026-11-24-tahan-naik-design.md`

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

## Constraints

- Godot 4.7.2, GDScript bertipe, semua gambar digambar di kode (`Art.*`) atau shader; tidak ada aset baru.
- Teks untuk pemain berbahasa Indonesia; font Fredoka (hindari simbol seperti ▶ ★).
- Target Android: performa gambar ombak harus ringan.
- Sim dan screenshot selalu pakai `--nosave`.
