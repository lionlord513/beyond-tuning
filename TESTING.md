# Validation

## Version 1.2.2

Checked the desktop shortcut with insufficient funds and an exact $1,000 charge for one delivered laptop. The native player primary action took a folded laptop through its real physical mesh, kept it in hand while moving, and released it on drop. The same check passed for an older generic carrier. The loot regression selected 59 of 4,096 test sites and skipped revisits and non-host players. The 10,000-update idle laptop regression passed. Separate-PC multiplayer was not exercised.

## Version 1.2.1

On build 26106988, the Boost purchase button delivered a full Stage II 10 L bottle within reach and charged $4,400. A cold reload retained the original car ID, mounted bottle ID and 3.75 L. A simulated missing bottle was recovered once at its saved mount with 1.25 L. With both gameplay mods and the local host tools enabled, the host menu delivered a laptop at no charge. The idle laptop regression completed 10,000 updates without engine calls. Two separate networked PCs were not used for these checks.

## Version 1.2.0

A disposable copy of a player's autosave loaded the same world and vehicles. A newly delivered laptop was mounted there. Nine traces across its folded surface selected the laptop, including the corners. The native Remove action released it. After Take, the visible native mesh stayed about one metre from the camera and appeared in a capture from the player's viewpoint. Dropping it restored world interaction and its open prompt read Use laptop.

With Beyond Apocalypse absent, buying a Stage I five-litre bottle in that world produced a textured bottle holding five litres of native nitrous. The policy checks cover all six variants, 25–200% injection, partial bottles, safety cutoffs, and immutable save revisions. Separate-PC multiplayer was not exercised for this release.

## Version 1.1.2 laptop fixes

In a disposable solo world, a real car's attachment list lost the mounted laptop after native Remove from either the closed lid or the body. A loose laptop was taken into hands. Beyond Apocalypse's actual backpack transfer code stored it, returned its Tuner Laptop name and texture, retrieved it into hands, and restored its closed lid and usable desktop. Forcing the screen snapshot to throw during exit still removed the fullscreen HUD and restored mouse, look and movement input. These checks did not use a second networked PC.

## Version 1.1.1 controls

Focused callback checks cover closed-lid left-click pickup, right-click open/close, ignored button-release events, open-screen access, forwarding pickup to the native physical body, and closed-lid rejection at both local and host entry points. The idle-update and existing policy checks pass. This patch did not rerun the full native-world suite below.

## Version 1.1 additions

- All scripts compile and the original 31 policy/JSON checks pass. All 42 example files validate as exactly one Drift/Race pair for each of 21 catalog engines.
- Native Drift / Race / Stock transitions check real drift assist and grip restoration. Gear arrays retain their native size.
- Laptop purchase, imported meshes, convex collision physics, native pickup/release, folding, screen interaction, native desktop, driver-seat opening, frozen PNG output and native car mounting were exercised in a disposable solo world.
- A cold native-save reload restores the original laptop identity and car mounting. The tuning journal is separate from native item saving.
- A mounted idle laptop reports every component tick disabled after capture completes. A 10,000-update mock check makes no engine calls, captures or file accesses from the idle laptop update path. This is a behavior check, not a promise of literally zero rendering/physics cost or a measured FPS benchmark.
- The existing native reliable RPCs pass local hello, tune-request, host-side persistence and saved-acknowledgement checks. Full operation across separate host/client PCs, packet loss and reconnects has not been tested. The implementation includes replicated persistent identity, late-join record distribution and driver telemetry while an app watches that car.
- Heat colors use actual engine temperature; no additional engine capture runs just to update heat color. A frozen laptop screen is local to each player's installation; other players see their own last image or the static wallpaper.

Run `lua tests/laptop_idle.lua` for the idle behavior check. The native QA harness and disposable save files are excluded from the release.

Validated on Windows x64 with Drive Beyond Horizons build 26106988, the installed UE4SS runtime and Beyond Apocalypse 1.0.10. Runtime checks used a separate solo QA world. No player save was used as a test fixture.

## Automated checks

- 31 Lua policy/JSON checks: neutral stock, interpolation, real control multipliers, rev cutoff, gearing tradeoff, immutable baselines, strict schema/range validation, malformed JSON, nonfinite numbers, Unicode, depth limits, saved-baseline validation, old-preset upgrades and hardware preset round trips.
- Native Windows transfer harness: exact preset bytes copied through the same atomic transfer function used by the import dialog; preset enumeration completes.
- Actual Beyond Mod Manager assembly: Nexus ZIP recognition, standalone dependency detection, fresh installation, update preservation of settings and customized presets, load order, disable, enable and uninstall. Apocalypse files remain untouched.

Run the Lua suite from the repository root using Lua 5.4:

```
lua tests/policy.lua
```

Build `tests/native.c` with Zig's Windows x64 C compiler, `-municode`, and the same libraries as `build.ps1`. Pass an isolated fixture directory containing `state/`, `presets/` and `input.json`. The harness does not open dialogs or send input.

## In-game checks

- Fourteen native integration assertions cover output, pedal/map multiplication, native gear speed and torque values, shift duration, free-rev ceiling, fuel/heat costs, real torque cutoff, stock restoration, stock nitrous behavior, real fluid telemetry, saved preset reload and validated/rejected imports.
- The native wheel torque path produced **23.831058 → 29.788822**, exactly **+25%**, after applying 125% output. This exercises `UpdateWheelTorque`, beyond checking a preview graph.
- Native widget callback checks cover the table editor, reset, File, Vehicle, Settings, Help, Classic/Dark and speed units. Screenshots verify native window layout and text.
- All 21 engine catalog classes rendered at top and angled views (42 captures). Pixel checks confirm transparent backgrounds, visible contours and distinct camera orientations. The native image owns the texture; rendering survives forced Unreal garbage collection.
- Two fitted turbos produced independently adjusted native torque contributions at 50% and 175%; shared curve assets remained unchanged and stock restoration returned both originals. Applied turbo settings persisted.
- Marked native BA bottle fixtures exercised real fluid quantities and native BoostForce at 25/50/100/200% injection, non-compounding force, final-drop fuel limits and persistent injection settings. These are adapter integration tests, not a physical keyboard driving test.
- A clean installed launch with Beyond Apocalypse removed passed native app startup, optional nitrous detection, real +10% torque, applied hardware persistence, repeated save capture and rotated engine rendering. BA was restored afterward, with all original files verified unchanged. A second installed cold launch with BA passed the same checks plus a real +50% turbo contribution. Temporary QA hooks are removed from the delivered installation.
- Removing an engine disables its tune. Installing a different native engine starts stock with a different identity. Reinstalling the original engine restores its saved tune.
- Immediate active-state writes, fresh storage reload, interrupted-rename backup recovery, orphaned preset backup discovery and non-destructive import name collisions pass.
- A deliberate game-process termination after applying 125% output, followed by loading the older native game save, restored the newer tune's actual torque and shift settings. The independently saved preset also survived.

## Boundaries

The 1.0 checks below predate client tuning support. A separate multiplayer host/client session and every possible vehicle/mod combination have not been tested. Other mods which replace the same torque or gear values can conflict. Future game or loader updates may require adapter changes. Draft edits are temporary until Apply or Save preset; restoring stock intentionally resets the active calibration.

The engine preview uses GPU scene capture and runtime contour conversion. It does not read unavailable CPU mesh buffers. Gear updates edit existing native entries rather than marshal replacement gear arrays through the loader.
