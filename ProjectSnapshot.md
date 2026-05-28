# Project Snapshot

Snapshot date: 2026-05-26

Scope: current project infrastructure. `src/Attribute.zig` is excluded from this snapshot by request.

## Repository Layout

- `build.zig` - Zig build graph for the executable, package module, run step, test step, and external dependencies.
- `build.zig.zon` - package metadata, minimum Zig version, dependency pins, and packaged paths.
- `src/main.zig` - application entry point and main simulation/render loop.
- `src/root.zig` - package root module; currently minimal.
- `src/GameState.zig` - central runtime state, entity type registry, Lua config loading, grid setup, frame timing, collision insertion, and render dispatch.
- `src/EntDb.zig` - generic entity database infrastructure.
- `src/SlotQueue.zig` - reusable slot/id allocator used by the entity database.
- `src/config.zig` - typed Zig config schema.
- `src/config.lua` - runtime config values loaded through LuaJIT.
- `src/Spec.zig` - circle entity with movement, random spawning, rendering, and collision state.
- `src/Food.zig` - rendered food entity.
- `src/FpsBox.zig` - rendered FPS overlay entity.
- Generated/cache directories:
  - `.zig-cache/` - Zig build cache.
  - `zig-out/` - installed build outputs.
  - `zig-pkg/` - local package cache.

## Build Infrastructure

The project targets Zig `0.16.0` or newer via `build.zig.zon`.

`build.zig` defines:

- Package module `EvolSimZig` rooted at `src/root.zig`.
- Executable `EvolSimZig` rooted at `src/main.zig`.
- Standard target and optimize options from Zig's build system.
- `zig build run` step for running the installed executable.
- `zig build test` step that runs both:
  - module tests for `src/root.zig`
  - executable-root tests for `src/main.zig`

External dependencies are pinned in `build.zig.zon`:

- `raylib_zig` from `raylib-zig/raylib-zig`, `devel` ref pinned to commit `97be2c7...`
- `smart_soa` from `austinrtn/SmartSoA`, pinned to commit `dcb02b4...`
- `luajit_build` from `sackosoft/zig-luajit-build`, pinned to commit `83801ee...`
- `SpacialGrid` from `austinrtn/SpacialGrid`, pinned to commit `31789ac...`

The executable imports and links:

- `raylib` and `raygui` modules from `raylib_zig`
- raylib C artifact from `raylib_zig`
- `SmartSoA` from `smart_soa`
- `ZigGridLib` from `SpacialGrid`
- `lua` from `luajit_build`

## Runtime Flow

`src/main.zig` is the executable entry point.

Startup flow:

1. Uses `std.process.Init` for allocator and IO access.
2. Creates `GameState`.
3. Loads config from `src/config.lua` into the typed `Config` struct.
4. Initializes raylib using config values.
5. Queues an `FpsBox`.
6. Spawns initial `Food` and `Spec` entities.
7. Inserts collidable entities into the spatial grid.
8. Updates grid cell size.

Per-frame flow:

1. Begin raylib drawing.
2. Clear the background.
3. Update frame timing and FPS in `GameState`.
4. Reset and move `Spec` entities.
5. Reinsert collidable entities into the spatial grid.
6. Run grid collision update.
7. Mark collision participants as colliding in the entity database.
8. Draw all renderable entities by render layer.
9. Flush queued entity spawns and deletes.
10. Process keyboard controls.

Current controls:

- `r` deletes the first `Spec` entity directly.
- `t` queues a random `Spec` for spawning.

## Game State Infrastructure

`GameState.zig` defines a generic `GameState(GridConfig, EntTypes)` and exports `GameStateT`.

Current registered entity types:

- `Spec`
- `Food`
- `FpsBox`

At comptime, `GameState` derives:

- `Collidables` from entity types declaring `pub const collidable = true`.
- `Renderables` from entity types declaring `pub const renderable = true`.
- Sorted renderables by each type's `render_layer`.

Renderable validation happens at comptime:

- Renderable types must expose `draw(state: *GameState)`.
- Renderable types must expose `render_layer`.

Runtime `GameState` owns:

- allocator
- `std.Io`
- loaded `Config`
- Lua state pointer
- generic `EntDb`
- pointer to `Grid.SpacialGrid`
- frame delta time
- FPS value

The spatial grid is initialized from configured window dimensions with:

- `multi_threaded = true`
- `cell_size_multiplier = 2`

`insertAll` inserts all collidable entity data into the grid based on each entity's declared `shape`. The current implementation routes `Circle`, `Rect`, and `Point` branches through `grid.insert.Circle.many(...)`, so shape-specific insertion behavior should be reviewed if rectangle or point collidables become important.

## Entity Database Infrastructure

`EntDb.zig` builds a type-specialized database from the registered entity type list.

Entity type requirements:

- Must be a struct.
- Must declare `pub const location: []const u8`.
- Must contain `id: u32`.

Generated data structures:

- `EntLocation` enum generated from each entity type's `location`.
- `EntData` struct with one `*SmartSoA(EntityType)` field per entity type.
- Spawn queue struct with one `std.ArrayList(EntityType)` per entity type.
- Delete queue struct with one `std.ArrayList(u32)` per entity type.

Main entity operations:

- `spawnEnt` directly inserts an entity.
- `queueEntForSpawn` queues entity insertion.
- `flushSpawnQueueAll` inserts all queued spawns.
- `deleteEnt` directly deletes an entity.
- `queueEntForDeletion` queues entity deletion by id.
- `flushDeletionQueueAll` deletes all queued ids.
- `getEnt`, `setEnt`, `getEntDb`, `getEntIdx`, and location/type lookup helpers provide typed access.

Deletion uses swap-and-pop on the entity SoA. When an entity is swapped from the last row into a removed row, the swapped entity's slot metadata is updated to preserve id-to-row lookup.

## Slot Infrastructure

`SlotQueue.zig` provides reusable ids for `EntDb`.

Each slot stores:

- `id`
- entity row index
- entity location enum
- active flag

Behavior:

- `init` preallocates slots and a free-id queue up to the configured capacity.
- `setNextSlot` reuses a queued id when available, or appends a new slot beyond the initial capacity.
- `getSlot` rejects inactive slots.
- `sendSlotToQueue` marks a slot inactive and returns the id to the free queue.

## Config Infrastructure

`src/config.zig` defines the typed config contract:

- window dimensions and monitor index
- target FPS
- entity count
- min/max spawn bounds
- min/max radius
- min/max velocity
- FPS overlay toggle

`src/config.lua` is the runtime config source. It currently returns:

- `800x800` window
- monitor `0`
- target FPS `60`
- initial entity count `1`
- radius range `26..32`
- velocity range `8..12`
- FPS overlay enabled
- spawn bounds padded by `50` pixels around the window

`GameState.initLua` loads `src/config.lua`, executes it, and maps fields into `Config` using Zig reflection over `std.meta.fields(Config)`.

## Entity Rendering And Behavior

Current render order:

1. `Food` with `render_layer = 0`
2. `Spec` with `render_layer = 1`
3. `FpsBox` with `render_layer = 100`

`Spec`:

- Collidable circle.
- Tracks `x`, `y`, `r`, velocity, color, id, and collision state.
- Moves based on `state.dt`.
- Draws gray normally and its assigned color when colliding.
- Random spawn values come from config and `std.Random.IoSource`.

`Food`:

- Renderable and collidable.
- Stores position, radius, color, and id.
- Draws as a raylib circle.

`FpsBox`:

- Renderable overlay.
- Queued into the database during initialization.
- Draws only when `state.config.show_fps` is true.

## Current Working Tree State

At snapshot time, the working tree has existing modifications in:

- `src/Food.zig`
- `src/FpsBox.zig`
- `src/GameState.zig`
- `src/Spec.zig`
- `src/config.lua`
- `src/main.zig`

There is also an untracked file excluded from this snapshot:

- `src/Attribute.zig`

## Verification

Command run:

```sh
zig build test
```

Result: passed with exit code `0`.
