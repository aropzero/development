# SIEGE: FALLEN GATE — 3D Tactical Defense

A playable 3D gate-defense game built with WebGL (vendored three.js, no runtime
CDN dependency), using real **CC0** 3D models and sound effects downloaded from
Kenney.nl, plus an **Android APK build pipeline** that runs on GitHub Actions.

## The game
`index.html` redirects to `index3d.html` → SIEGE: FALLEN GATE.
- Defend your gate against 20 waves of blocky knights across a winding road.
- Deploy siege engines: **ballista** (rapid bolts), **catapult** (arcing
  explosive shells), **trebuchet** (heavy high-arc shells).
- Orbit the camera by dragging; zoom with the scroll wheel.
- Upgrade and scrap engines from the build bar.
- **Real CC0 sound effects** (downloaded `.ogg` samples) for explosions, bolts,
  shell impacts, placement, sell and upgrade — with automatic synthesized
  fallback so audio never breaks even offline.

## Assets (all CC0 from Kenney.nl)
- `assets/3d/castle-kit/` — siege engines, gate, walls, towers, rocks, trees
- `assets/3d/blocky-characters/` — enemy characters
- `assets/3d/retro-urban-kit/`, `assets/3d/modular-buildings/` — environment kits
- `assets/audio/interface-sounds/`, `assets/audio/impact-sounds/` — 230+ SFX
- `download_assets.sh` — reusable no-API-key downloader
- `assets/preview.html` — 3D viewer + SFX player

## Local preview
```bash
python3 -m http.server 8080
# Game: http://localhost:8080   (redirects to index3d.html)
# Preview: http://localhost:8080/assets/preview.html
```

## Android APK (GitHub Actions)
The `android/` folder is a minimal WebView wrapper that packages the **3D game**
(including its glTF models, textures and real audio samples) into an APK.
Pushing to `main` (or running the workflow manually) builds a debug APK and
uploads it as a build artifact.

```bash
# Build locally (Android SDK + JDK 17 required):
cd android
gradle :app:assembleDebug -PofflineMaven=/path/to/offline/maven
# APK at: android/app/build/outputs/apk/debug/app-debug.apk
```

Workflow: `.github/workflows/build-apk.yml` → artifact `iron-frontline-debug-apk`.
