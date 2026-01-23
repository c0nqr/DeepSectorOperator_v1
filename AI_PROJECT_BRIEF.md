# Deep Sector Operator — AI Project Brief

**Purpose:** This document gives an AI enough context to continue development without guessing. Follow existing patterns exactly. When adding systems, integrate with LevelManager, GlobalData, groups, and physics layers as described below.

---

## 1. Project overview

- **Engine:** Godot 4.5, Forward Plus.
- **Type:** 2D top-down space game.
- **Main scene:** `res://scenes/player/TestLevel.tscn` (UID `uid://cjjor362gsml6`).
- **Config:** `project.godot`. App name: **Deep Sector Operator**.

**Core loop:** Player scouts → calls freighter to resource nodes → freighter sends mining drone → drone mines and returns cargo → enemies spawn from nodes during mining → player defends. When freighter is full, it departs and level enters DEFENDING; boss/level-complete flow is stubbed.

---

## 2. Repository layout

```
deep-sector-operator/
├── project.godot          # Engine config, autoloads, input, physics layers
├── assets/                # Textures (PNG), icon (SVG). All .import files present.
├── scripts/
│   └── autoloads/
│       ├── GlobalData.gd
│       └── LevelManager.gd
└── scenes/
    ├── player/            # Player, Projectile, TargetIndicator, TestLevel
    ├── enemies/           # Enemy, EnemyProjectile
    ├── drones/            # MiningDrone
    ├── Freighter/         # Freighter (capital F)
    ├── resources/         # ResourceNode
    └── ui/                # HealthBar, CargoBar, WaveUI
```

- **No `scenes/levels/` folder.** `LevelManager.transition_to_vault()` changes scene to `res://scenes/levels/main_menu.tscn` — **that scene does not exist**. Creating it (or fixing the path) is required before that transition can work.

---

## 3. Autoloads (singletons)

Both are loaded in `project.godot`. Access as `GlobalData` and `LevelManager` (no `get_node`).

### 3.1 GlobalData (`scripts/autoloads/GlobalData.gd`)

- **Persistent (saved):** `vault` dictionary:
  - `vault.credits` (int)
  - `vault.unlocked_levels` (int)
  - `vault.unlocked_upgrades` (array)
- **Session-only (reset per run):** `cargo` dictionary:
  - `cargo.current_resources` (int)
  - `cargo.current_level` (int)
- **Save path:** `user://vault_save.dat` (`FileAccess.store_var` / `get_var`).
- **API:**
  - `add_credits(amount: int)` — adds to vault, saves, emits `credits_changed`.
  - `add_cargo(amount: int)` — adds to `cargo.current_resources`, emits `cargo_changed`.
  - `transfer_cargo_to_vault()` — adds `cargo.current_resources` to `vault.credits`, zeros cargo, saves, emits both signals.
  - `reset_cargo()` — zeros `cargo.current_resources`, emits `cargo_changed`.
  - `save_vault()` / `load_vault()` — file I/O.
- **Signals:** `credits_changed(new_amount: int)`, `cargo_changed(new_amount: int)`.

**Usage:** Enemies call `GlobalData.add_cargo(resource_drop_amount)` on death. Freighter calls `GlobalData.add_cargo(amount)` when drones deposit. Use `add_cargo` for session resources; use `add_credits` for permanent currency.

### 3.2 LevelManager (`scripts/autoloads/LevelManager.gd`)

- **References:** `player`, `freighter`, `current_level_root` (Node2D). Player and Freighter self-register in their `_ready()`. `register_level_root` exists but is **never called** in the project; `current_level_root` is unused.
- **State:** `LevelState` enum — `SCOUTING` | `MINING` | `DEFENDING` | `BOSS_FIGHT` | `LEVEL_COMPLETE`. Initial: `SCOUTING`.
- **Config:** `@export var boss_waiting_position: Vector2 = Vector2(1500, -500)` (used when freighter departs).

**API:**

- `register_player(player_node: CharacterBody2D)`
- `register_freighter(freighter_node: CharacterBody2D)`
- `register_level_root(root_node: Node2D)` — currently unused.
- `request_freighter_with_node(target_position: Vector2, resource_node: Node)`  
  - Allowed only in `SCOUTING`.  
  - Calls `freighter.move_to_position(target_position, resource_node)`.  
  - Emits `freighter_called(target_position)`.
- `on_freighter_arrived()` — emits `mining_started`.
- `on_freighter_full()` — sets state to `DEFENDING`, emits `mining_completed`, calls `freighter.depart_to_waiting_area(boss_waiting_position)`.
- `on_boss_defeated()` — sets state to `LEVEL_COMPLETE`, emits `boss_defeated`.
- `transition_to_vault()` — calls `GlobalData.transfer_cargo_to_vault()`, then `get_tree().change_scene_to_file("res://scenes/levels/main_menu.tscn")` (scene missing).
- `transition_to_next_level()` — increments `GlobalData.cargo.current_level`, emits `level_transition_requested(next_level)`.

**Signals:** `freighter_called`, `mining_started`, `mining_completed`, `boss_defeated`, `level_transition_requested(next_level: int)`.

**ResourceNode** connects to `LevelManager.mining_started` and `LevelManager.mining_completed` to toggle `is_being_mined` and thus wave spawning.

---

## 4. Input actions

Defined in `project.godot`:

| Action           | Default binding | Usage |
|------------------|-----------------|--------|
| `move_action`    | Mouse button 1 (left) | Click = move to point; hold ≥ `hold_threshold` = chase cursor. |
| `fire_weapon`    | Space           | Toggle auto-fire on/off. |
| `target_cycle`   | Tab **or** Q    | Cycle locked target among in-range enemies. |
| `call_freighter` | M               | Call freighter to cursor; if hovering a resource node, to node’s parking position. |

All input is handled in **Player** via `_unhandled_input`; other systems do not read these actions. Use `get_viewport().set_input_as_handled()` when consuming an action.

---

## 5. Physics layers (2D)

**Layer names** in `project.godot`:

| Layer | Name            | Typical use |
|------:|-----------------|-------------|
| 1     | Player          | Player CharacterBody2D |
| 2     | Projectile      | Player projectiles (Area2D) |
| 3     | Environment     | Static world (e.g. walls) |
| 4     | Enemies         | Enemy CharacterBody2D |
| 8     | Resources       | Resource nodes (StaticBody2D) |
| 16    | Freighter       | Freighter CharacterBody2D |
| 20    | EnemyProjectiles| Enemy projectiles (Area2D) |
| 32    | Drones          | Mining drones (CharacterBody2D) |

**Collision setup (as used in scripts):**

- **Player:** `collision_layer = 1`, `collision_mask = 4` (collides with Enemies).
- **Freighter:** `collision_layer = 16`, `collision_mask = 4` (Enemies). Script sets these in `_ready`; scene overrides may exist but runtime values follow the script.
- **Enemy:** `collision_layer = 4`, `collision_mask = 1 + 2 + 16 + 32` (Player, Projectile, Freighter, Drones).
- **MiningDrone:** `collision_layer = 2147483648` (custom bit), `collision_mask = 524296`; scene values can differ, but scripts assume drones interact with environment, freighter, resources, etc. as set in `.tscn`.
- **Projectile (player):** `collision_layer = 2`, `collision_mask = 4`; `monitoring = true`, `monitorable = false`.
- **EnemyProjectile:** `collision_layer = 524288`, `collision_mask = 2147483649` (scene); hits Player, Freighter, Drones via `take_damage`.

When adding new physical or projectile entities, assign a dedicated layer and set mask so they interact only with intended layers. Do not repurpose existing layers (e.g. Projectile, Enemies) for unrelated systems.

---

## 6. Groups

Used for discovery and behavior:

| Group           | Who joins        | Purpose |
|-----------------|------------------|---------|
| `player`        | Player           | Single player ref; enemies and others query this. |
| `enemies`       | Enemy            | Targeting, wave UI, player projectiles. |
| `drones`        | MiningDrone      | Enemy targeting; drone logic. |
| `freighter`     | Freighter        | Enemy targeting; level flow. |
| `resource_nodes`| ResourceNode     | Player hover detection for “call freighter” (optional parking target). |

**Conventions:**

- Add entities to the correct group in `_ready()`.
- Use `get_tree().get_nodes_in_group("...")` for lookups. Always validate `is_instance_valid()` before using references.

---

## 7. Scenes and required node paths

### 7.1 Player (`scenes/player/Player.tscn`)

- Root: `CharacterBody2D`.
- **Required children:**  
  - `WeaponMount` (Node2D) — projectiles spawn at `weapon_mount.global_position`.  
  - `BarsContainer` → `HealthBar` (Control) — script uses `$BarsContainer/HealthBar`.
- **Exports:** `projectile_scene` (PackedScene), `target_indicator_scene` (PackedScene). Must be assigned.
- **Optional:** Camera2D, Sprite2D, CollisionShape2D.

### 7.2 Freighter (`scenes/Freighter/Freighter.tscn`)

- Root: `CharacterBody2D`.
- **Required children:**  
  - `DroneSpawnPoint` (Marker2D) — drones spawn at `drone_spawn_point.global_position`.  
  - `BarsContainer` → `HealthBar`, `CargoBar` (Control). Script uses `$BarsContainer/HealthBar` and `$BarsContainer/CargoBar`.
- **Exports:** `drone_scene` (PackedScene). Must be assigned.
- Starts at `jump_in_point` (default `Vector2(-500, 0)`), `visible = false`, until first `move_to_position` call.

### 7.3 MiningDrone (`scenes/drones/MiningDrone.tscn`)

- Root: `CharacterBody2D`.
- **Required children:**  
  - `BarsContainer` → `HealthBar`, `CargoBar` (Control). Script uses `has_method("initialize")` / `update_health` / `update_cargo` on these.
- **No scene refs in script;** instantiated by Freighter, which calls `initialize(assigned_resource_node, self)`.

### 7.4 ResourceNode (`scenes/resources/ResourceNode.tscn`)

- Root: `StaticBody2D`.
- **Required children:**  
  - `HoverDetector` (Area2D) — has `mouse_entered` / `mouse_exited`; also hover is faked in `_process` via `get_global_mouse_position()` distance and a `CircleShape2D` radius on the first child.  
  - `ParkingMarker` (Node2D) — `get_parking_position()` returns `parking_marker.global_position`.  
  - `EnemySpawnPoint` (Marker2D) — wave enemies spawn at `enemy_spawn_point.global_position`.
- **Exports:** `enemy_scene` (PackedScene). Must be assigned.

### 7.5 Enemy (`scenes/enemies/Enemy.tscn`)

- Root: `CharacterBody2D`.
- **Required child:** `DetectionArea` (Area2D) — `body_entered` / `body_exited` connected; used to wake from IDLE.
- **Exports:** `projectile_scene` (PackedScene). Must be assigned.

### 7.6 HealthBar / CargoBar (`scenes/ui/HealthBar.tscn`, `scenes/ui/CargoBar.tscn`)

- Root: `Control` with child `Fill` (ColorRect). Script expects `$Fill`.
- **HealthBar:** `initialize(max_hp: int)`, `update_health(new_health: int)`. Drives `fill.scale.x` from `current_health / max_health`.
- **CargoBar:** `initialize(max_capacity: int)`, `update_cargo(new_cargo: int)`. Same pattern for cargo ratio.

### 7.7 WaveUI (`scenes/ui/WaveUI.tscn`)

- Root: `CanvasLayer` with `Container` → `WaveLabel` (Label). Script uses `$Container/WaveLabel`.
- Updates every `_process` with `"Enemies: " + str(get_tree().get_nodes_in_group("enemies").size())`.

### 7.8 TargetIndicator (`scenes/player/TargetIndicator.tscn`)

- Root: `Node2D`. Instantiated by Player and added as **child of the locked target** (Enemy). No required children; script animates rotation and scale.

### 7.9 Projectiles

- **Player:** `Projectile` (Area2D). `initialize(direction: Vector2, spawn_rotation: float)`. Moves with `position += velocity * delta`; `body_entered` → checks `is_in_group("enemies")` and `has_method("take_damage")`, then `take_damage(damage)` and optional pierce.
- **Enemy:** `EnemyProjectile` (Area2D). Same `initialize` signature. `body_entered` → any `take_damage` body receives damage, then projectile is freed.

Projectiles are added to **scene root**: `get_tree().root.add_child(projectile)`, and `global_position` set by spawner.

---

## 8. Damage and health contract

- Any damageable entity implements **`take_damage(amount: int) -> void`**.
- Player projectiles only damage nodes in `enemies` **and** with `take_damage`.
- Enemy projectiles damage any body with `take_damage` (player, freighter, drones).
- **Health display:** Entities with health use a `HealthBar` instance; they call `initialize(max_health)` once and `update_health(current_health)` when damaged. Same idea for CargoBar where applicable.

---

## 9. Level and TestLevel layout

**TestLevel** (`scenes/player/TestLevel.tscn`):

- Root: `Node2D`.
- Children: `Parallax2D` / `Parallax2D2` (backgrounds), `ResourceNode`, `Freighter`, `Enemy`, `Player`, `WaveUI`.
- Player, Freighter, ResourceNode, Enemy are instanced from their scene files. WaveUI is a CanvasLayer.

**Level flow (current):**

1. **SCOUTING:** Player calls freighter via M (possibly over a resource node). LevelManager `request_freighter_with_node` → Freighter `move_to_position`.
2. Freighter travels → parks → `on_freighter_arrived` → `mining_started` → ResourceNodes start wave spawning.
3. Drone mines, returns, deposits. Freighter calls `GlobalData.add_cargo`, updates CargoBar.
4. When freighter `is_cargo_full` → `on_freighter_full` → `DEFENDING`, `mining_completed`, freighter `depart_to_waiting_area(boss_waiting_position)`.
5. `on_boss_defeated` and `transition_to_vault` / `transition_to_next_level` are wired but **boss fight and level transitions are not implemented**. `transition_to_vault` also points at a non-existent `main_menu` scene.

---

## 10. Coding conventions and patterns

- **GDScript:** Typed signatures and variables where used (`: int`, `-> void`, etc.).
- **State machines:** Use `enum` + `match` in `_physics_process` (e.g. Player `MoveState`, Enemy `EnemyState`, Drone `DroneState`, Freighter `FreighterState`). Keep state transitions explicit and in one place.
- **Exports:** Tune numbers and scene refs via `@export`; avoid magic numbers in logic.
- **Signals:** Use for cross-system events (LevelManager ↔ Freighter/ResourceNode, etc.). Prefer signals over direct references when decoupling.
- **Null/instance checks:** Always `is_instance_valid(node)` (or check `node != null` where appropriate) before using stored node refs. Enemies, drones, and freighter use this pattern.
- **Spawns:** Instantiate from `PackedScene`, add to `get_tree().root`, set `global_position`, then call any `initialize(...)` used by that scene.
- **Debug prints:** The project uses `print(...)` extensively. When adding systems, you can follow the same style for key events, or reduce if you standardize logging later.

---

## 11. Deferred / stub behavior

- **Player death:** `take_damage` reduces health; at `current_health <= 0` it only `print("Player would die here (death deferred to Phase 4)")`. No respawn, no `reset_cargo`, no scene change yet.
- **Boss fight:** `LevelState.BOSS_FIGHT` exists but is never set. `on_boss_defeated` is never called.
- **Level transitions:** `transition_to_vault` and `transition_to_next_level` exist but:
  - `main_menu` scene is missing;
  - Nothing triggers these functions in gameplay yet.
- **`LevelManager.register_level_root`:** Implemented but unused. `current_level_root` is never read.

---

## 12. Adding new systems — checklist

1. **Scene placement:** New gameplay objects live under `scenes/` in the appropriate folder (e.g. `scenes/enemies/`, `scenes/drones/`). UI under `scenes/ui/`. Level-specific scenes can go in `scenes/levels/` once you introduce it.
2. **Physics:** Assign a **new** physics layer for the new entity type; update `project.godot` `[layer_names]` and set `collision_layer` / `collision_mask` so it interacts only with what it should.
3. **Groups:** Add to a group only if something will `get_nodes_in_group(...)` for it. Use existing groups when the new entity is “the same kind” as current members (e.g. new enemy type → `enemies`).
4. **LevelManager:** If the system affects level flow (e.g. new phase, new win condition), extend `LevelState` and LevelManager API; emit signals and call LevelManager from the right places.
5. **GlobalData:** Use `add_cargo` for temporary session resources and `add_credits` for persistent currency. Connect to `cargo_changed` / `credits_changed` if UI or other systems need to react.
6. **Damage:** If the new entity can be hit, implement `take_damage(amount: int)`. If it shoots, use an Area2D projectile with `initialize(direction, spawn_rotation)` and `body_entered` → `take_damage` on valid targets; set projectile layers/masks consistently with Projectile/EnemyProjectile.
7. **Scene hierarchy:** If you add new dependency nodes (e.g. spawn points, bars), use `@onready` and fixed `$Path` references. Document required children in a similar way to this brief.
8. **Input:** New input actions go in `project.godot` `[input]`. Prefer handling in one place (e.g. Player or a dedicated input handler) and `set_input_as_handled` where appropriate.

---

## 13. Do not assume

- **Main menu / levels:** `res://scenes/levels/main_menu.tscn` does not exist. Do not assume any level-select, main menu, or vault UI exists.
- **Player death:** There is no death handler, respawn, or `reset_cargo` on player death. Only a print statement.
- **Boss fight:** `BOSS_FIGHT` exists in `LevelState` but is never entered. Nothing calls `on_boss_defeated`.
- **Level progression:** Nothing calls `transition_to_vault` or `transition_to_next_level` during play. LevelManager has the API only.
- **`register_level_root`:** It is never called. `current_level_root` is unused. Do not assume level root is registered.
- **Hover on ResourceNode:** Hover is implemented via distance check in `_process` and via `HoverDetector` Area2D. Both exist; do not assume only one is used.
- **Projectile debug prints:** `Projectile.gd` contains several `print` calls for debugging. The game runs with them; remove or reduce only if you add proper logging.

---

## 14. Assets

- **Location:** `assets/`. All textures are PNG except `icon.svg`.
- **Usage:** Sprites reference them via `res://assets/...` in `.tscn` files. Reuse or add new assets under `assets/` and follow existing naming.

---

## 15. Quick reference

| Need to…                    | Use |
|-----------------------------|-----|
| Add session resources       | `GlobalData.add_cargo(amount)` |
| Add permanent currency      | `GlobalData.add_credits(amount)` |
| React to cargo/credits      | Connect to `GlobalData.cargo_changed` / `credits_changed` |
| Call freighter              | `LevelManager.request_freighter_with_node(pos, node)` (SCOUTING only) |
| React to mining start/stop  | Connect to `LevelManager.mining_started` / `mining_completed` |
| Change level state          | LevelManager methods + `LevelState` |
| Spawn projectiles           | Same layer/mask and `initialize` pattern as Projectile/EnemyProjectile |
| Damage something            | Call `take_damage(amount)` on Node with that method |
| Find player / enemies etc.  | `get_tree().get_nodes_in_group("player")` etc. |
| Spawn at world root         | `get_tree().root.add_child(instance)` then set `global_position` |

---

*End of AI Project Brief. Prefer extending this file when you add new systems or conventions so future AI or developers stay in sync.*
