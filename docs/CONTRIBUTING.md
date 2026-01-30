Contributing Guidelines (short)

Code style
- Keep GDScript files small and focused per node responsibility.
- Use signals for cross-node communication; prefer editor connections for scene-local UI.

Signals
- Follow the contracts listed in `docs/SIGNALS.md`.
- When connecting programmatically, always check `is_connected(...)` before `connect(...)` to avoid duplicate-connection errors.

Scene edits
- Prefer making signal-to-node connections in the Godot editor for scene-local wiring.
- When adding new nodes that should be discovered at runtime (e.g., resource nodes), ensure they are added to the appropriate group (e.g., `resource_nodes`).

Testing
- Run the level and exercise events (enemy death, freighter deposit, player death) after changes.
- Check the Output/Debugger for errors and trace log prints added to managers like `EnemySpawner` and `LevelManager`.

Commit messages
- Use short, descriptive messages. Example: "Refactor: Centralize spawning in EnemySpawner; ResourceNode emits mining events".

If you're unsure about a change, open an issue or ask for a quick code review first.
