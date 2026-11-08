# 🏙️ Horizon City

**A calm, beautiful 3D city builder for Android and desktop — built with Godot Engine 4.**

Place homes, shops and parks on a little island, keep the lights on, keep your
citizens smiling, and watch your skyline rise from a sleepy outpost to a
gleaming megacity. Gentle music, soft light and a living diorama make it a
relaxing place to spend a few minutes — or a few hours.

![Godot](https://img.shields.io/badge/Godot-4.7-478cbf?logo=godotengine&logoColor=white)
![Android](https://img.shields.io/badge/Android-arm64-34a853?logo=android&logoColor=white)
![License](https://img.shields.io/badge/code-MIT-46dfc3)
![Assets](https://img.shields.io/badge/assets-CC0%20%2B%20CC%20BY-ffc857)

---

## ✨ Features

| | |
|---|---|
| 🏝️ **Living 3D diorama** | A hand-built island with a procedural animated ocean, volumetric-style sky with drifting clouds, stars, a sun and moon, real day/night lighting, bloom, ACES tonemapping and soft shadows. |
| 🌇 **Day / night cycle** | The sun moves across the sky, the city warms up at dusk, windows light up at night and street lamps glow along the roads. |
| 🏗️ **20 buildings, 4 districts** | Homes, Shops, Industry and Civic — each with three upgrade levels and several real 3D model variants. |
| 🤖 **Living traffic** | Cars, taxis, vans, trucks and police cars drive along your actual road network, choosing turns at every junction. |
| 🎯 **Progressive, dynamic goals** | A seven-step tutorial chain flows into an endless, procedurally generated quest list that scales with your city's size and tier. |
| 📈 **Real simulation** | Population growth, taxes, upkeep, power grid, jobs, unemployment, pollution, happiness and eight settlement tiers. |
| 📱 **Made for touch** | One-finger orbit, pinch-to-zoom, two-finger pan, hardware back button, safe-area insets, immersive full-screen, 60 fps friendly. |
| 🎨 **Hand-crafted UI** | A complete code-generated theme, vector-drawn icon set, 3D-baked building thumbnails, toasts, task panel and pause menu. |
| 🎵 **Calm audio** | A rotation of ambient piano tracks and soft, warm UI / building sound effects. |
| 💾 **Autosave** | The city, quests and settings persist between sessions. |

---

## 🎮 How to play

1. Open the build bar at the bottom and pick a **Cottage**.
2. Tap (or drag across) a green plot to place it.
3. Build a **Wind Turbine** so the lights come on, then a **Shop** for jobs.
4. Keep an eye on the four pills at the top: **coins, citizens, happiness, power**.
5. Complete the **City Goals** on the right — they pay coins and unlock new buildings as your population grows.
6. Tap any placed building to **upgrade** or **sell** it.

### Controls

| Action | Touch | Desktop |
|---|---|---|
| Orbit camera | One-finger drag | Left-drag / right-drag |
| Pan | Two-finger drag | Middle-drag or `WASD` / arrows |
| Zoom | Pinch | Mouse wheel or `+` / `-` |
| Rotate view | ⟲ ⟳ buttons | `R` / `F` |
| Place building | Pick a card, tap a tile | Pick a card, click a tile |
| Pause | ⏸ button | `Esc` / `Space` |
| Game speed | `1×` button | `1` `2` `3` |

---

## 🚀 Running the project

1. Install [Godot Engine 4.7](https://godotengine.org/download) (standard, not .NET).
2. Open `project.godot`.
3. Press **F5**.

The game runs at 1280×720 and scales to any window or phone resolution.

### Building an Android APK locally

```bash
# 1. install the Godot 4.7.2 export templates (Editor → Manage Export Templates)
# 2. point Editor Settings → Export → Android at your SDK + JDK 17
godot --headless --path . --import
godot --headless --path . --export-release "Android" build/HorizonCity.apk
```

The APK is written to `build/HorizonCity.apk` (arm64-v8a, Android 7.0+).

### Building an APK on GitHub

Every push to `main` (and every manual **workflow_dispatch**) runs
[`.github/workflows/build.yml`](.github/workflows/build.yml), which:

1. installs JDK 17, the Android SDK (platform 36, build-tools 35.0.0) and Godot 4.7.2,
2. caches the Godot binary and export templates,
3. imports the project and exports a signed **release** APK (falling back to debug),
4. uploads it as a downloadable **artifact**,
5. publishes / updates the rolling **`latest`** GitHub Release with the APK attached.

No secrets are required — the build self-signs with a generated debug keystore so
the APK installs on any Android device.

---

## 🗂️ Project structure

```
project.godot              # engine + autoload configuration
export_presets.cfg         # Android export preset
scenes/                    # Boot, MainMenu, Game
scripts/
  autoload/                # GameConfig, BuildingDB, GameState, QuestManager,
                           # SaveManager, AudioManager, SceneManager
  game/Game.gd             # gameplay scene: input, placement, camera, HUD wiring
  world/                   # CityWorld, CityBuilding, RoadTile, Traffic, CameraRig
  ui/                      # HUD, BuildBar, TaskPanel, PauseMenu, UIKit, Glyph…
  *.gdshader               # sky, water, ground, road, highlight, vignette
assets/
  models/                  # Kenney City Kit / Nature Kit / Car Kit (.glb)
  audio/music/             # ambient tracks
  audio/sfx/               # impacts, bells and UI sounds
  fonts/                   # Nunito + Quicksand
tools/                     # headless gameplay smoke test
.github/workflows/build.yml
```

### Smoke test

A headless test exercises the whole simulation — catalogue integrity, placement,
upgrading, demolishing, 25 simulated days, quest generation, save/load round-trips
and the full 3D game scene:

```bash
godot --headless --path . res://tools/SmokeTest.tscn
# → SMOKE RESULT: PASS (100+ checks)
```

---

## 📜 Credits

All 3D models and sound effects are **CC0** by [Kenney](https://kenney.nl);
the ambient music is **CC BY 4.0** by Kevin MacLeod.
See [CREDITS.md](CREDITS.md) for the full list.

## License

The game code is released under the [MIT License](LICENSE).
Assets keep their original licenses (CC0 / CC BY 4.0 / OFL).