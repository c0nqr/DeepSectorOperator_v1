Signals and Event Contracts (project-wide)

Overview
- This document lists the primary signals (events) used across the project and the expected payloads and consumers.
- The project follows an event-first pattern: gameplay objects emit domain events; `GlobalData` and manager nodes (e.g., `LevelManager`, `EnemySpawner`) listen and mutate state or react.

GlobalData (autoload) signals
- `credits_changed(new_amount: int)`
  - Emitted by `GlobalData` when vault credits change.
  - Consumers: UI (`HomeMapUI`) and any systems showing vault credits.

- `cargo_changed(new_amount: int)`
  - Emitted by `GlobalData` when session cargo changes.
  - Consumers: UI (`HomeMapUI`), save/state systems.

- `entity_died(source: Node, drop_amount: int)`
  - Emitted by gameplay entities when destroyed (e.g., `Enemy`, `Boss`).
  - Consumers: `GlobalData` (adds dropped resources to cargo), analytics, loot systems.

- `cargo_collected(amount: int)`
  - Emitted by collectors (e.g., `Freighter.add_cargo`) to indicate resources were collected.
  - Consumers: `GlobalData` (adds to session cargo), UI listeners.

- `transfer_to_vault_requested()`
  - Emitted to request transferring session cargo to the vault (persistent credits).
  - Consumers: `GlobalData` (performs vault mutation and saving).

- `cargo_reset_requested()`
  - Emitted to request resetting session cargo (e.g., on player death).
  - Consumers: `GlobalData` (resets cargo and emits `cargo_changed(0)`).

Level/Flow signals (`LevelManager`)
- `freighter_called(call_position: Vector2)`
  - Emitted by `LevelManager` after processing a freighter request.
  - Consumers: optional UI/analytics.

- `mining_started()` / `mining_completed()`
  - Emitted by `LevelManager` when a freighter arrives or leaves.
  - Consumers: `ResourceNode` (starts/stops mining), other game flow logic.

Enemy/Spawner signals
- `ResourceNode.node_mining_started(node: Node)`
  - Emitted by the `ResourceNode` when mining begins for that node (the node passes itself).
  - Consumers: `EnemySpawner` (starts waves for that node).

- `ResourceNode.node_mining_completed(node: Node)`
  - Emitted by the `ResourceNode` when mining stops for that node.
  - Consumers: `EnemySpawner` (stops waves for that node).

- `ResourceNode.resources_depleted()`
  - Emitted when a node runs out of resources and is freed.
  - Consumers: `EnemySpawner` (cleanup), UI.

Damage/Health signals
- `health_changed(new_health: int)`
  - Emitted by characters (`Player`, `Enemy`, `Freighter`, `MiningDrone`) when health updates.
  - Consumers: local UI (`HealthBar`) or central HUD via editor connections.

Best Practices / Editor wiring (Godot way)
- Prefer connecting signals in the Godot editor for scene-local UI (e.g., connect `Player.health_changed` to the `HealthBar.update_health` method on the Player scene).
- Connect global/autoload signals in code (e.g., `HomeMapUI` connects to `GlobalData.credits_changed` in `_ready`).
- Do not mutate `GlobalData` from many places — emit events and let `GlobalData` handle persistence and state mutations.

Example: hooking `Player` health to its `HealthBar` in the editor
1. Open the `Player` scene.
2. Select the `Player` node, open the `Node` tab, find `health_changed`, press `Connect`.
3. Choose the `HealthBar` node under `BarsContainer` and bind to `update_health`.

If you want, I can add a short `docs/CONTRIBUTING.md` with these conventions and a small checklist for future contributors.
