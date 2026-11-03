# Beyond Tuning

**Car Tuning** brings a desktop-style calibration workspace to the computers in **Drive Beyond Horizons**. Seven live gauges, a torque correction table, a live trace and a rotatable 3D hologram of the installed engine sit inside a native in-game window.

Built using the computer-window and input-surface approach established by Beyond Apocalypse's Hangar app. Beyond Tuning is a separate mod and does not replace Beyond Apocalypse files.

![Car Tuning with the rotatable installed-engine view](docs/screenshots/engine-view.png)

## Install

Windows x64, Drive Beyond Horizons build 26106988, and a compatible UE4SS installation are required. Developed alongside Beyond Apocalypse 1.0.10. Beyond Apocalypse is optional; when installed, Beyond Mod Manager loads it first.

**Beyond Mod Manager:** import `BeyondTuning-1.0.0-Nexus.zip`, inspect the preview, and install. The manifest supplies identity, version, load order, GitHub updates and preservation rules for your presets and settings.

**Manual:** exit the game and extract the ZIP into the main `Drive Beyond Horizons` game folder. The resulting path is `DriveBeyondHorizons/Binaries/Win64/ue4ss/Mods/BeyondTuning/Scripts/main.lua`. The included `enabled.txt` enables the mod. This package does not include or replace UE4SS.

## Your first tune

1. Sit in the car you want to tune. Leave it and open an in-game computer.
2. Open **Car Tuning**. Check the car and engine listed at the top. **Vehicle** shows exact class identifiers and installed hardware.
3. Use **File** to load Street or Economy, or adjust a main control. All changes start as a draft.
4. Stop the car, then press **Apply to car**. Application requires host authority and a speed below 2 km/h.
5. Drive the same route and compare the **Live log**. Apply has already saved the calibration to disk. Save the game to keep the car itself and your game progress.

The target remains the last car you sat in during this game session. A different car or engine starts its own calibration. Presets are reusable across cars; applied tunes belong to a particular chassis and engine pair.

## What the controls actually change

| Control | Effect |
| --- | --- |
| Engine output | Multiplies the game's native torque result. Higher output also increases native fuel consumption and heat production. |
| Final drive | Shortens or lengthens native gear speed ranges and shift thresholds, with corresponding gear torque changes. Higher values favor acceleration. |
| Rev ceiling | Changes the tuning limiter and free-rev ceiling. Torque cuts above the selected ceiling; the engine's original gearbox RPM ranges remain the reference. |
| Shift duration | Changes the native time spent changing gears. Lower values shift more quickly. |
| Pedal response | Changes part-throttle torque delivery. It does not add full-throttle output on its own. |
| Individual turbos | Scales each fitted turbo's native boost contribution independently, from 25–200%. Unfitted slots are ignored. |
| Nitrous injection | With Beyond Apocalypse and a fitted bottle: 25–200% injection. Half injection gives half force and approximately twice the bottle duration; double injection reverses the tradeoff. BA keeps its activation and safety rules. |
| Torque table | Applies a smoothly interpolated correction across five pedal rows and eight RPM columns. 100 is neutral. |

**Restore stock** restores the captured native settings and removes that car/engine's saved tune. **Revert draft** discards unapplied edits. Power and the torque table multiply together, so make small changes and compare.

Curve previews the engine correction before turbo/nitrous effects, not measured horsepower or a simulated fuel/ignition ECU. Live log shows real RPM, vehicle speed and pedal readings over the last 15 seconds. Engine view captures the actual installed engine and attached-part meshes with a transparent background. Drag to orbit, use tilt/zoom buttons, or press Top. All 21 current engine catalog classes were checked at two angles. This is an exterior hologram view, not an internal mechanical simulation.

**Boost** lists each installed turbo by its slot. Turbo percentages describe the game's boost contribution, not PSI. Nitrous shows **Unavailable** without Beyond Apocalypse, or when no BA bottle is attached. Hold Shift while driving to activate BA nitrous after applying the tune. An empty bottle produces no extra force. Standalone engine, gearbox and turbo tuning do not require BA.

## Presets and appearance

- **Save preset:** enter a name under File and save the current draft into the mod's `presets` folder.
- **Export:** choose a destination in the Windows Save As dialog, then share the JSON file.
- **Import / drop JSON:** drag one JSON preset onto the dedicated import window, or select Browse. It is validated and permanently saved in the preset library. A conflicting name gets a numbered copy. Return to the game, review the draft, then Apply. JSON is never executed.
- **Open preset folder:** opens the folder in Explorer. You can also copy JSON files there and press Refresh presets.
- **Settings:** Classic or Dark, five interface accents, five graph/hologram colors, km/h or mph, and Simple view.
- **Help:** includes the same beginner workflow and import/export instructions inside the app.

The drop target is the small Windows import window, not the game's viewport. Use a windowed or borderless game if you want to drag from Explorer without switching away from exclusive fullscreen.

## Saves, compatibility and removal

**Presets and applied tunes persist through game saves, crashes and restarts.** Apply writes the active calibration to `BeyondTuning/state` immediately, before changing the car, and creates a reusable **Last applied** preset for that chassis/engine pair. Imported and manually saved presets live in `BeyondTuning/presets` independently of game saves. Backup files provide recovery if a write is interrupted.

Loading an older save of the same world retains the latest applied calibration for matching car/engine identities. Native save revisions also receive calibration snapshots. Keep both `state` and `presets` when moving to another PC. The mod cannot recover a car the game itself never saved; its Last applied preset remains available for another car. Draft edits are temporary until Apply or Save preset. Restore stock is an intentional calibration reset; reusable presets remain available.

The mod runs on the game thread and uses the same native computer UI methodology as Hangar. It does not replace Apocalypse files or hooks, ship private companion code, or redistribute game meshes. The optional nitrous adapter adjusts measured native fluid consumption and the corresponding native boost force while BA owns activation. At 100% it leaves the behavior unchanged. Engine images are generated locally at runtime. Presets contain data only. The small native DLL provides Windows file dialogs, drag/drop, pointer position while dragging the model, and image contour conversion; it has no network access.

Tuning is host-authoritative. Clients may inspect their local telemetry, but cannot apply tunes. A separate multiplayer host/client session has not been validated. Other mods which replace native torque, gear arrays or engine calibration can conflict. Future game builds may change the reflected APIs.

Use Beyond Mod Manager to disable or uninstall while the game is closed. Save desired reusable presets first. Re-enabling restores access to the retained state. For manual removal, remove the `BeyondTuning` folder after backing up `state` and `presets` if you want to keep them.

## Source and build

Lua 5.4 scripts are under `mod/BeyondTuning/Scripts`. The Windows helper source is `native/preset_bridge.c`. Build the DLL with Zig 0.14.1 and package with Python 3:

```powershell
.\build.ps1 -Zig C:\path\to\zig.exe
```

Run pure Lua tests from the repository root with `lua tests/policy.lua`. See `TESTING.md` for runtime checks and coverage limits. Packaging uses an explicit allowlist so runtime images, tuning journals, personal presets and development tools are excluded.

Source: https://github.com/lionlord513/beyond-tuning

Drive Beyond Horizons and Unreal Engine assets belong to their respective owners. Beyond Tuning is an unofficial mod. The interface is inspired by common automotive calibration tools and uses original UI code and graphics.
