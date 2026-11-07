# IRON FRONTLINE — 2D Tactical Defender (+ SIEGE 3D)

This repo contains two playable HTML5 games built with pure Canvas / WebGL (no
runtime CDN dependency), plus the real CC0 asset pack we downloaded and an
**Android APK build pipeline** that runs on GitHub Actions.

## Games
| Game | File | Description |
|---|---|---|
| IRON FRONTLINE (2D) | `index.html` | Realistic top-down tactical defender: MG, cannon, missiles, railgun, flamethrower; armor system, 25 waves. Real CC0 sound effects with automatic synthesis fallback. |
| SIEGE: FALLEN GATE (3D) | `index3d.html` | 3D gate defense using downloaded glTF models (castle kit + blocky characters) via vendored three.js. |

## Assets (all CC0 from Kenney.nl)
- `assets/3d/castle-kit/` — 76 models (siege engines, walls, towers…)
- `assets/3d/blocky-characters/` — enemy characters
- `assets/3d/retro-urban-kit/`, `assets/3d/modular-buildings/` — environment
- `assets/audio/interface-sounds/`, `assets/audio/impact-sounds/` — 230+ SFX
- `download_assets.sh` — reusable no-API-key downloader
- `assets/preview.html` — 3D viewer + SFX player

## Local preview
```bash
python3 -m http.server 8080
# 2D: http://localhost:8080   3D: http://localhost:8080/index3d.html
# preview: http://localhost:8080/assets/preview.html
```

## Android APK (GitHub Actions)
The `android/` folder is a minimal WebView wrapper that packages the 2D game
into an APK. Pushing to `main` (or running the workflow manually) builds a debug
APK and uploads it as a build artifact.

```bash
# Build locally (Android SDK + JDK 17 required):
cd android
gradle :app:assembleDebug -PofflineMaven=/path/to/offline/maven
# APK at: android/app/build/outputs/apk/debug/app-debug.apk
```

Workflow: `.github/workflows/build-apk.yml` → artifact `iron-frontline-debug-apk`.
