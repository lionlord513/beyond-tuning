# Validation

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

Application is host-only. A separate multiplayer host/client session and every possible vehicle/mod combination have not been tested. Other mods which replace the same torque or gear values can conflict. Future game or loader updates may require adapter changes. Draft edits are temporary until Apply or Save preset; restoring stock intentionally resets the active calibration.

The engine preview uses GPU scene capture and runtime contour conversion. It does not read unavailable CPU mesh buffers. Gear updates edit existing native entries rather than marshal replacement gear arrays through the loader.
