# Aset Gratis & Bebas Royalti — sudah terunduh

Semua aset di folder `assets/` **sudah benar-benar diunduh dari Internet** dalam sesi ini
(memakai skrip `download_assets.sh` — bukan sekedar contoh).

## Ringkasan apa yang sudah diunduh

| Folder | Isi | Jumlah | Lisensi |
|---|---|---|---|
| `assets/audio/interface-sounds` | Sound effect UI (klik, konfirmasi, buka/tutup panel) | 100 file | CC0 |
| `assets/audio/impact-sounds` | Sound effect benturan/foley (logam, kayu, kaca, pukulan) | 130 file | CC0 |
| `assets/3d/castle-kit` | Model 3D glTF (**.glb**) — menara, gerbang, jembatan, alat perang (trebuchet, catapult, ballista, ram) | 76 model | CC0 |
| `assets/3d/blocky-characters` | Karakter low-poly (dipakai sebagai musuh di game 3D) | 18 model | CC0 |
| `assets/3d/retro-urban-kit` | Perlengkapan lingkungan urban (pagar, lampu, reruntuhan, dll.) | 124 model | CC0 |
| `assets/3d/modular-buildings` | Bangunan modular (rumah, menara, sudut bangunan) | 108 model | CC0 |
| `js/vendor/` | **three.js r160** + GLTFLoader + BufferGeometryUtils (dijual lokal — tanpa CDN saat runtime) | — | MIT |
| `assets/preview.html` | Halaman preview: render 3D glb + pemutar SFX asli | — | — |

> File `License.txt` asli dari Kenney sudah ada di dalam tiap folder.

## Integrasi yang sudah selesai (di sesi ini)

1. **SFX asli masuk ke game 2D `IRON FRONTLINE`** — `js/game.js` sekarang memuat file
   `.ogg` CC0 yang sudah diunduh (ledakan, tembakan, benturan, klik UI) lewat WebAudio
   `decodeAudioData`. Kalau file belum termuat (mis. dibuka langsung dari disk tanpa server
   lokal), otomatis **fallback ke suara sintesis** — audio tidak pernah rusak.
2. **Game 3D baru: `SIEGE: FALLEN GATE`** (`index3d.html` + `js/game3d.js`) — game
   pertahanan gerbang yang **dapat dimainkan**, memakai model glb asli dari `castle-kit`
   (gerbang, tembok, menara, trebuchet/catapult/ballista) dan `blocky-characters`
   (musuh). three.js + GLTFLoader dijalankan dari `js/vendor/` lokal → **tidak butuh CDN**
   saat runtime. Termasuk: pergerakan musuh di jalan, matematika proyektil (panah lurus &
   peluru parabola yang meledak), gelombang (20), supplies, integritas gerbang, upgrade/jual,
   kamera orbit (drag) & zoom (scroll), dan suara sintesis.

## Cara memainkan game 3D
```bash
cd /workspace/gamedeveloper
python3 -m http.server 8080
# buka http://localhost:8080/index3d.html
```
Klik ground kosong untuk memasang alat perang dari bar bawah, klik alat yang sudah terpasang
untuk retrofit/jual. Selamatkan gerbang dari 20 gelombang.

## Perlu API key? Tidak.
Pipeline unduh (`download_assets.sh`) memakai endpoint publik **`download-link`** milik
Kenney.nl, tanpa akun dan tanpa API key. Yang diperlukan cuma:
1. `curl` (memakai User-Agent browser biasa).
2. `python3` (untuk menghitung id hex nama paket).

Semua paket Kenney.nl berlisensi **CC0** → public-domain-like: bebas dipakai di engine
apa pun (Unity, Unreal, Godot, three.js, Bevy, dll.), untuk proyek komersial,
**tanpa atribusi**.

## Cara memakai skrip (unduh paket lain)
```bash
cd /workspace/gamedeveloper
./download_assets.sh <nama-paket> [folder-tujuan]
```
Contoh:
```bash
./download_assets.sh interface-sounds assets/audio/interface-sounds
./download_assets.sh impact-sounds   assets/audio/impact-sounds
./download_assets.sh castle-kit      assets/3d/castle-kit
```
Cari nama paket di https://kenney.nl/assets → copy bagian setelah `/assets/` di URL.

## Cara melihat preview 3D + mendengar SFX
Jalankan server lokal lalu buka `assets/preview.html`:
```bash
cd /workspace/gamedeveloper
python3 -m http.server 8080
# buka http://localhost:8080/assets/preview.html
```
- **3D:** pilih model dari dropdown (glTF .glb dirender dengan three.js — drag untuk rotate, scroll untuk zoom).
- **Suara:** pilih grup, klik tombol untuk memutar file `.ogg` asli.

## Mengimpor ke engine lain
- **three.js / Babylon.js / Godot / Unity / Unreal:** impor file `.glb` langsung.
  glTF adalah format universal — tidak perlu konversi.
- **Godot:** drag `.glb` ke jendela FileSystem.
- **Unity:** taruh `.glb` di folder Assets (Unity 2020+ / paket `glTFast`).
- **Unreal:** `Import` → pilih `.glb`.
- **Suara:** `.ogg` diterima langsung oleh Godot/Unity/Unreal/WebAudio.

## Sumber tambahan (semua bebas royalti)
- **3D:** Poly Haven (CC0), Quaternius (CC0), Sketchfab (filter "CC0"/"CC BY"),
  OpenGameArt (cek lisensi per file).
- **Suara:** Freesound (CC — filter CC0), Pixabay (lisensi bebas komersial),
  Mixkit, Kenney Audio (CC0).

> Catatan lisensi: CC0 = paling aman (tanpa atribusi). CC BY = wajib atribusi.
> CC BY-SA = "share-alike" (hindari untuk game komersial tertutup).

## Ide lanjutan (bisa dikerjakan berikutnya)
- 🗂️ Mengunduh paket tambahan (tekstur, animasi karakter, suara lain) dengan `download_assets.sh`.
- 🎬 Menambahkan animasi serangan/berjalan pada musuh (paket karakter beranimasi).
- 🗺️ Membuat sistem peta/path ganda di game 2D & 3D.
- 💾 Menambahkan sistem save/load.
