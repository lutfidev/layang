# Layang — mekanik baru "Tahan = Naik" + Monster Laut

Tanggal: 2026-11-24 · Status: menunggu persetujuan

## Kenapa
Mekanik lama (tahan = menukik, lepas = melayang, melambung dari lereng) membingungkan: saat
pemain menekan spasi/klik di tanah datar, tidak ada yang terlihat terjadi selain sayap
mengepak. Pemain mengharapkan "tekan = terbang". Mekanik diganti total ke kontrol yang
langsung terasa, tetap bisa dimainkan satu jari di HP.

## Tujuan
- Tekan/tahan langsung membuat burung naik — feedback instan.
- Tetap ada keputusan bermakna: stamina vs ketinggian vs risiko.
- Laut antar pulau jadi rintangan nyata (monster laut + tercebur = game over).
- Sistem yang sudah ada dipakai ulang: timer matahari, bonus waktu pulau, koin, fever, skin,
  shop, menu, rewarded "Lanjut terbang".

## Bukan tujuan
- Tidak membuat rintangan baru di darat (pohon, tiang, dll.) di iterasi ini.
- Tidak mengubah biome, skin, ekonomi, iklan.

## Anti-tujuan (gagal walau "jalan")
- Pemain bisa menahan terus di atas dan melewati semuanya tanpa risiko.
- Monster menggigit tanpa peringatan (terasa curang).
- Kontrol terasa "berat"/telat merespons di HP.

## Pendekatan yang dipertimbangkan
1. **Tahan = naik, lepas = meluncur turun + stamina** — DIPILIH. Respons instan, satu jari,
   terrain & pulau tetap relevan.
2. Ketuk = satu kepakan (ritme ketuk-ketuk) — lebih "rewel", capek di HP, butuh rintangan baru.
3. Lari di tanah + lompat/double jump (runner) — bukit jadi platform, menjauh dari tema "layang".

Pemain memilih 1 ("saran kamu saja").

## Desain

### Kontrol & fisika burung (`bird.gd`)
- Kecepatan horizontal maju otomatis, naik pelan sepanjang run (mis. 380 → ~700 px/s),
  fever ×1.3.
- **Tahan**: gaya angkat ke atas melawan gravitasi (burung naik cukup cepat, terasa responsif;
  kecepatan vertikal dibatasi). Animasi kepak cepat.
- **Lepas**: gravitasi normal tapi kecepatan jatuh dibatasi (meluncur, bukan jatuh batu).
  Sayap terbentang.
- **Stamina** 0..1: berkurang saat menahan (habis dalam ~2.5 dtk tahan terus), terisi saat
  tidak menahan (~penuh dalam 3 dtk), lebih cepat saat di tanah. Stamina 0 → tidak bisa naik
  sampai terisi ≥ 0.2 (hindari kedip on/off).
- **Langit-langit**: di atas ketinggian tertentu (≈ 2 layar di atas air) gaya angkat melemah
  hingga nol.
- **Tanah**: bukan mati. Burung menempel/berlari di permukaan (kecepatan horizontal turun
  sedikit, terus mengisi stamina). Menabrak tanjakan curam dengan kecepatan tinggi → "Aduh!",
  kecepatan dipotong, combo reset. Menahan saat di tanah = lepas landas.
- Rotasi/visual burung tetap seperti sekarang (mengikuti arah kecepatan).

### Combo: "NYEREMPET" (menggantikan "MULUS")
- Terbang dalam jarak dekat di atas bukit (mis. < 90 px dari permukaan) tanpa menyentuh tanah
  mengumpulkan poin gaya. Satu "serempetan" dihitung selesai saat burung keluar dari zona
  rendah setelah ≥ 0.6 dtk di dalamnya → popup "NYEREMPET ×n", poin 25·n.
- Menyentuh tanah atau "Aduh!" → combo reset.
- Combo ≥ 3 → fever (logika fever di `game.gd` tetap, hanya pemicunya diganti).
- "TERBANG TINGGI!" tetap ada (bonus melewati ketinggian tertentu).

### Laut & monster laut
- Burung menyentuh air laut → **game over** ("Tercebur ke laut!").
- **Monster laut**: makhluk laut fiksi yang lucu dan bulat (tubuh seperti ular/naga laut gemuk,
  mata besar, mulut bergigi besar), digambar di kode sebagai `Art.sea_monster(...)`.
  Bukan tiruan karakter game/film tertentu.
- Muncul hanya saat burung berada di atas laut. Telegraf **~1 dtk** sebelum lompat: gelembung +
  bayangan gelap di permukaan pada posisi depan burung, suara "blub" (Sfx baru, disintesis
  seperti efek lain).
- Lompatan berbentuk busur, puncak ±setengah tinggi layar di atas permukaan air, mulut terbuka
  di puncak. Kena hitbox burung → game over ("Digigit monster laut!").
- Kesulitan per pulau ke-k: laut awal 1 lompatan, makin jauh makin sering, hingga 2–3 per laut;
  posisi telegraf mengarah ke posisi burung + sedikit di depannya.
- Splash + partikel saat masuk/keluar air memakai `Ambient.burst` yang ada.

### Aturan run (`game.gd`)
- Run berakhir karena: matahari terbenam (seperti sekarang, burung mengantuk → lepas landas tidak
  bisa, turun pelan), tercebur, atau digigit.
- Saat mengantuk (malam), stamina tidak terisi → burung pasti turun; mencapai pulau di malam
  tetap membangunkan burung (aturan lama).
- Layar hasil menampilkan penyebab berakhir.
- "Lanjut terbang" (rewarded): burung ditempatkan aman di atas air/darat terdekat, stamina penuh,
  +12 dtk, 1x per run (aturan lama).

### UI & teks
- Layar siap: "Tahan untuk naik".
- Hint tutorial: "TAHAN untuk naik  •  LEPAS untuk turun  •  Awas monster laut!"
- Tutorial selesai setelah 2 kali NYEREMPET (menggantikan 2x MULUS).
- Bar stamina kecil di HUD (dekat time bar atau melayang di atas burung) — gambar di kode.

### Autoplay / simulasi (`world.gd`)
- `_ai_hold()` ditulis ulang: jaga ketinggian target di atas terrain, naik saat telegraf monster
  terlihat, kelola stamina di atas laut. Dipakai untuk menu/shop dan balance sim.
- Target balance sim (`--sim --fresh`): run rata-rata mencapai 2–4 pulau, AI sesekali mati di
  laut (bukti rintangan nyata).

## Diserahkan ke builder
- Angka persis (gravitasi, gaya angkat, laju stamina, jarak zona serempet, frekuensi monster)
  — tuning lewat sim + screenshot.
- Letak tepat bar stamina.
- Detail gambar monster asal lucu, terbaca jelas sebagai bahaya, dan sesuai palet.
- Memindahkan/menyesuaikan penempatan koin bila ada yang tak terjangkau dengan mekanik baru.

## Batasan
- Semua visual di kode (`Art.*`) / shader; tidak ada aset bitmap/audio baru.
- Typed GDScript, `maxf/minf/clampf` untuk `:=`.
- Teks pemain Bahasa Indonesia; hindari simbol di luar subset Fredoka (×, • sudah dipakai
  sekarang dan aman).
- Lolos headless error check dan balance sim dari CLAUDE.md.
