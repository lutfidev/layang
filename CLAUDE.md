# Layang — notes for Claude

Godot 4.7.2, GDScript, GL Compatibility renderer, landscape 1280x720 (stretch canvas_items/expand). Android target.

## Architecture
- No bitmap/audio assets except the font + `assets/audio/gamelan_loop.ogg`. All visuals are drawn in code (`scripts/world/art.gd`) or shaders (`shaders/`). Keep it that way: add new art as `Art.*` static helpers.
- Scenes are thin: each `.tscn` is a root Node2D + script; UI is built in code via `UIKit` (`scripts/ui/ui_kit.gd`).
- `World` (scripts/world/world.gd) is reused by game, menu and shop (menu/shop use `autoplay = true`, `input_enabled = false`).
- Game rules (endless run — no timer, islands bonus, combos, fever, 3-button lose screen, continue on dry ground past kites) live in `scripts/ui/game.gd`; physics in `bird.gd`; terrain in `terrain.gd` (cosine-interpolated key points, islands separated by a sea at `boundaries`). Hazards: `sea_monster.gd`, `wave.gd` (Pantai bays: sky-high curling wall, pass through the tube under the curl), `kite.gd` (Sawah kites), wired in `World._update_hazards`.
- Content is data: islands in `scripts/data/biomes.gd`, skins in `scripts/data/skins.gd`.
- Autoloads: `Game` (save/economy/dev flags/scene fade via `Game.goto(path)`), `Sfx` (`Sfx.play("coin")`), `Ads` (rewarded/interstitial/IAP facade — demo mode; integrate real plugins only inside ads.gd).

## Conventions
- Typed GDScript. Use `maxf/minf/absf/clampf` (not `max/min/abs`) when the result is assigned with `:=`, otherwise Godot fails with "Cannot infer the type".
- Player-facing text is Indonesian.
- Fredoka font is a latin subset: avoid symbols like ▶ ★ ← (they render as boxes).

## Testing
- `godot` is not on PATH: use `/d/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe` (Bash) or `D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe` (PowerShell).
- Unit tests: `godot --headless --path . res://tests/run_tests.tscn` (add `-- --only=name` to filter) prints `TESTS passed=N failed=M`. New `class_name` scripts need `godot --headless --path . --import` once first.
- Pass `--nosave` to sims/screenshots so they never overwrite the player's save (`--fresh` only skips loading).
- Sea monster screenshot scene: `res://tests/monster_shot.tscn -- --shot=out.png --shot-delay=1.6`
- Headless error check: `godot --headless --path . --quit-after 600 res://scenes/game.tscn -- --autoplay`
- Balance sim: `godot --headless --path . --fixed-fps 120 res://scenes/game.tscn -- --autoplay --sim --fresh --nosave` prints `RUN score=…` (endless: `--sim` stops after `--sim-max=S`, default 240 s, `cause=batas`)
- Lose screen screenshot: `... res://scenes/game.tscn -- --island=1 --autoplay --nosave --die=ombak --shot=out.png --shot-delay=4.5`
- Screenshot: `... res://scenes/game.tscn -- --island=4 --autoplay --shot=out.png --shot-delay=8`
- Kite screenshot (Sawah, fixed seed): `... res://scenes/game.tscn -- --island=0 --seed=4242 --autoplay --nosave --shot=out.png --shot-delay=7.5` (seed 7 + delay 12 = bird passing right under a tail).
- Beach wave screenshot (Pantai, fixed seed): `... res://scenes/game.tscn -- --island=1 --seed=4242 --autoplay --nosave --shot=out.png --shot-delay=9` (delay 7.5 = curling wall ahead, 9 = bird inside the tube). `--seed=N` fixes the run seed.

## Alur git per langkah

Satu "langkah" = satu rencana di `docs/superpowers/plans/` (atau satu fase dari spec di `docs/superpowers/specs/`). Pemilik repo biasanya `/clear` setelah tiap sesi, jadi aturan ini yang berlaku, bukan ingatan percakapan. Kerjakan sendiri tanpa bertanya dan tanpa menyuruh pemilik repo menjalankan perintah. Remote: `origin` = `github.com/lutfidev/layang`, branch utama `main`.

- **Cek wajib** (dipakai di awal dan akhir langkah): `godot --headless --path . --import` (cek tidak ada error parse/script), unit test `godot --headless --path . res://tests/run_tests.tscn` harus `failed=0`, dan cek error headless `godot --headless --path . --quit-after 600 res://scenes/game.tscn -- --autoplay --nosave` tanpa `SCRIPT ERROR`/`ERROR`.
- **Awal langkah:** `git fetch`, pastikan tidak ada PR terbuka (`gh pr list --state open` kosong) dan PR langkah sebelumnya sudah di-merge ke `origin/main`, lalu `git checkout main && git pull --ff-only`, buat `feat/<nama-langkah>`, hapus branch lokal yang sudah di-merge, jalankan cek wajib. Kalau masih ada PR yang belum di-merge, jangan bercabang dari `main` lama; beri tahu pemilik repo.
- **Selama langkah:** commit kecil, pesan bahasa Inggris singkat (`feat(game): ...`, `feat(world): ...`, `feat(ui): ...`, `fix: ...`, `test: ...`, `docs: ...`).
- **Akhir langkah** (cek wajib bersih, temuan review sudah diperbaiki, semua checkbox di file plan-nya sudah dicentang dan status plan ditandai selesai): `git push -u origin <branch>` lalu `gh pr create --base main` langsung, tanpa menu pilihan. Kirim link PR-nya. Judul PR `feat: <nama langkah>`. Badan PR berbahasa Indonesia: kalimat pembuka "Langkah: ..." (sebut file plan/spec-nya), daftar perubahan, asumsi baru (kalau ada, juga dicatat di file spec terkait di `docs/superpowers/specs/`), lalu baris "Verifikasi:" berisi hasil import, jumlah test yang lulus (`TESTS passed=N failed=0`), hasil cek error headless, dan cek lain yang dijalankan (balance sim `RUN score=…`, screenshot).
- **Merge PR** dilakukan pemilik repo di GitHub; jangan merge sendiri kecuali diminta.
- **Tambahan ke PR yang sudah ada:** sebelum push, cek `gh pr view <nomor> --json state` masih `OPEN`. Kalau sudah di-merge, buat branch baru dari HEAD sekarang dan buka PR baru dengan judul dan badan lengkap. Jangan mengubah badan PR yang sudah di-merge.
- **Atribusi:** commit dan PR atas nama akun git pemilik repo. Jangan tambahkan `Co-Authored-By: Claude`, "Generated with Claude Code", atau atribusi Claude lain di pesan commit maupun badan PR.
- Kesepakatan baru soal alur kerja langsung dicatat di file ini, jangan hanya diucapkan di chat.
