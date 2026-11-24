# Ombak Gulung — design (perbaikan ombak Pantai)

Status: disetujui pemilik repo (2026-11-24) · perbaikan tahap 1 dari `2026-11-24-tanpa-batas-design.md`

## Intent (kenapa)

Hasil main tahap 1 menunjukkan dua masalah:
1. **Ombak bukan rintangan.** Puncaknya cuma sampai y=100, sedangkan bibir teluk ada di y=-60. Pemain yang
   memang terbang tinggi lewat begitu saja di atasnya (jalur atas selalu bebas). Burung bisa melayang di
   ketinggian mana pun karena stamina cukup kalau menahan ±45% waktu.
2. **Ombak terasa 2D.** Bentuknya satu poligon datar berwarna rata, tanpa kedalaman.

## Goals

- Ombak menutup **semua jalur atas** di atas teluk, sampai batas langit (`Bird.CEILING_HARD` = -1500).
  Satu-satunya celah ada di bawah, di **terowongan gulungan ombak** antara bibir gulungan dan air.
  Terbang tinggi berarti menabrak dinding ombak. Terlalu rendah berarti tercebur.
- Tandanya terlihat dari jauh. Ombak sudah berdiri penuh saat pemain yang terbang tinggi masih sempat turun.
- Ombak terlihat 3D: gradasi badan, terowongan yang dalam, lapisan depan dan belakang, kilau, semburan.
- Bisa dilewati di semua kecepatan, dari `SPEED_START` sampai fever (×1.3).

## Non-goals

- Tidak menambah rintangan lain dan tidak mengubah kontrol.
- Tidak mengubah bentuk teluk (lembah, bibir, dasar, tepi seberang tetap).

## Anti-goals

- Celah yang mustahil dilewati di kecepatan tertentu.
- Dinding yang muncul tiba-tiba di depan burung tanpa sempat bereaksi.
- Menyembunyikan burung di balik ombak sampai pemain tidak bisa melihat posisinya.

## Approaches

- **A. Ombak gulung raksasa, lewat terowongan — DIPILIH.** Dinding setinggi langit, celah di bawah gulungan.
  Memaksa keputusan "turun dan masuk", dengan momen "hampir kena".
- B. Tinggi ombak mengikuti ketinggian burung. Dibuang karena terasa curang.
- C. Celah berdasarkan waktu (ombak naik-turun). Dibuang karena pemain tidak bisa mengatur kecepatan.

## Yang diputuskan bersama

- Dinding ombak setinggi langit. Celah terowongan ada di bawah gulungan.
- **Pelontar bibir oranye dihapus.** Bibir jadi tempat mulai menukik, dan petunjuknya diganti.
- Koin pemandu melewati terowongan.
- Tampilan 3D: gradasi, mulut terowongan elips gelap, punggung kedua yang pucat, kilau, semburan, buih di kaki.

## Keputusan saya (bisa dikoreksi)

- **Kolom ombak** `[water_x0 - 40, water_x1 + 40]`. Burung yang menyeberang teluk di ketinggian berapa pun
  pasti melewati kolom ini.
- **Atap terowongan** `TUBE_TOP = LIP_Y - 90 = -150`. Burung yang berlari di bibir (pusat ±-90) muat,
  sedangkan yang terbang >40 px di atas bibir kena. Kena = pusat burung − `HIT_PAD` < atap, atau
  pusat + pad > puncak saat ombak masih rendah.
- **Puncak** `CREST_Y = -1800` (di atas batas langit dan jari-jari burung).
- **Jarak picu** (diukur ke `mid` teluk): buih dari 3200, naik dari 2600, penuh dari 1500. Tinggi naik
  maksimal 2600 px/dtk, jadi ombak teluk berikutnya tidak muncul tiba-tiba. Pemain yang terbang tinggi
  sudah melihat dinding dari jauh (zoom 0.36 memperlihatkan ±2500 px ke depan).
- **Lewat terowongan butuh menahan:** tanpa pelontar, burung yang lepas di bibir jatuh ke air. Jadi
  tantangannya menahan secukupnya di dalam terowongan: tidak menyentuh atap, tidak tercebur.
- **Lapisan gambar:** dinding dan isi terowongan di belakang burung (di bawah bukit, supaya lereng teluk
  menutupi kaki ombak). Gulungan bibir depan (pita buih tebal tepat di atap) dan tirai air transparan
  digambar di depan burung, sehingga burung terlihat ada *di dalam* gulungan.
- **Teks:** popup "Awas ombak raksasa!" / "Terbang rendah lewat gulungannya". Tips kalah: "Turun ke bawah
  gulungan ombak, tahan sedikit supaya tidak tercebur".
- **Autopilot:** di dekat teluk, terbang rendah menyusuri tanah, lalu menjaga ketinggian di tengah terowongan.

## Angka akhir (2026-11-24)

- `TUBE_TOP` -150, `CREST_Y` -1800, `HIT_PAD` 18, kolom terowongan `[water_x0 - 40, water_x1 + 40]`.
- Bentuk di atas atap: muka miring keluar sampai 900 px di puncak (`face_x`, pangkat 1.3), punggung dari
  ledge 140 px setelah ujung terowongan ke puncak selebar 300 px (`back_x`). Bentuk ini dipakai untuk cek kena
  dan gambar.
- Buih 3200, naik 2600, penuh 1500 (jarak ke `mid`); laju tinggi maks 2600 px/dtk; surut 0,9 dtk.
- Terowongan selalu aman. Lolos setelah ledge + 40 px. Respawn "Lanjut" melewati ledge.
- Tidak ada koin dalam 120 px dari bentuk ombak; 6 koin pemandu di y = 150 sepanjang air teluk.
- Pelontar bibir dihapus seluruhnya (`kick_at`, `LIP_KICK`, pita oranye).

## Diserahkan ke pembuat

Angka pasti diverifikasi oleh tes fisika (lewat di semua kecepatan, kena di jalur atas) dan dicatat di plan.
