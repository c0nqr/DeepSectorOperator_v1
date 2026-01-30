extends Node

# EnemySpawner: central manager for spawning enemy waves for resource nodes.
# LevelManager will create one spawner per level root and it will register resource nodes under that root.

var tracked_nodes: Dictionary = {} # node -> state dict

func _process(delta: float) -> void:
	for node in tracked_nodes.keys():
		if not is_instance_valid(node):
			tracked_nodes.erase(node)
			continue
		var state = tracked_nodes[node]
		_update_node_spawn(node, state, delta)

func register_resource_node(node: Node) -> void:
	if tracked_nodes.has(node):
		return
	# initialize state from node properties
	var state = {
		"current_wave": 0,
		"enemies_spawned_this_wave": 0,
		"wave_spawn_timer": 0.0,
		"wave_delay_timer": 0.0,
		"waiting_for_next_wave": false,
		"active": false
	}
	tracked_nodes[node] = state
	# connect node signals
	if node.has_signal("node_mining_started"):
		node.node_mining_started.connect(_on_node_mining_started)
	if node.has_signal("node_mining_completed"):
		node.node_mining_completed.connect(_on_node_mining_completed)
	if node.has_signal("resources_depleted"):
		node.resources_depleted.connect(_on_node_resources_depleted)

func _on_node_mining_started(node: Node) -> void:
	if not tracked_nodes.has(node):
		register_resource_node(node)
	var state = tracked_nodes[node]
	state.current_wave = 0
	state.enemies_spawned_this_wave = 0
	state.wave_spawn_timer = 0.0
	state.waiting_for_next_wave = false
	state.active = true
	print("EnemySpawner: mining started for node: ", node.name)

func _on_node_mining_completed(node: Node) -> void:
	if tracked_nodes.has(node):
		tracked_nodes[node].active = false
		print("EnemySpawner: mining completed for node: ", node.name)

func _on_node_resources_depleted() -> void:
	var node = get_tree().get_current_scene().get_node(get_tree().get_current_scene().get_path())
	# resources_depleted handler provided; but nodes also get freed; cleanup happens in _process when invalid
	# No action necessary here beyond logging
	print("EnemySpawner: node resources depleted")

func _update_node_spawn(node: Node, state: Dictionary, delta: float) -> void:
	if not state.active:
		return
	# read parameters from node
	var enemies_per_wave: int = node.enemies_per_wave
	var total_waves: int = node.total_waves
	var delay_between_waves: float = node.delay_between_waves
	var spawn_interval_within_wave: float = node.spawn_interval_within_wave
	
	if state.current_wave >= total_waves:
		state.active = false
		return
	
	if state.waiting_for_next_wave:
		state.wave_delay_timer -= delta
		if state.wave_delay_timer <= 0.0:
			state.waiting_for_next_wave = false
			state.current_wave += 1
			state.enemies_spawned_this_wave = 0
			state.wave_spawn_timer = 0.0
			if state.current_wave < total_waves:
				print(node.name, " - Wave ", state.current_wave + 1, " starting!")
		return
	
	state.wave_spawn_timer -= delta
	
	if state.wave_spawn_timer <= 0.0 and state.enemies_spawned_this_wave < enemies_per_wave:
		_spawn_enemy_for_node(node, state)
		state.enemies_spawned_this_wave += 1
		state.wave_spawn_timer = spawn_interval_within_wave
		if state.enemies_spawned_this_wave >= enemies_per_wave:
			if state.current_wave < total_waves - 1:
				state.waiting_for_next_wave = true
				state.wave_delay_timer = delay_between_waves
				print(node.name, " - Wave ", state.current_wave + 1, " complete. Next wave in ", delay_between_waves, " seconds.")
			else:
				state.current_wave = total_waves
				print(node.name, " - All waves complete!")

func _spawn_enemy_for_node(node: Node, state: Dictionary) -> void:
	if node.enemy_scene == null:
		push_error("EnemySpawner: Enemy scene not assigned on node " + str(node.name))
		return
	var enemy: CharacterBody2D = node.enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	# attempt to use the node's enemy_spawn_point if present, otherwise node position
	if node.has_method("get_parking_position") and node.has_node("EnemySpawnPoint"):
		# attempt to use exported marker if available
		if is_instance_valid(node.enemy_spawn_point):
			enemy.global_position = node.enemy_spawn_point.global_position
		else:
			enemy.global_position = node.global_position
	else:
		enemy.global_position = node.global_position
	print(node.name, " - spawned enemy for wave")