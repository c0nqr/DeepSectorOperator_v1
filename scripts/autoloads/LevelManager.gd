extends Node

var player: CharacterBody2D = null
var freighter: CharacterBody2D = null
var current_level_root: Node2D = null

@export var boss_waiting_position: Vector2 = Vector2(1500, -500)
@export var portal_spawn_position: Vector2 = Vector2(1500, 0)
@export var portal_scene: PackedScene

enum LevelState {
	SCOUTING,
	MINING,
	DEFENDING,
	BOSS_FIGHT,
	LEVEL_COMPLETE
}

var current_state: LevelState = LevelState.SCOUTING

signal freighter_called(call_position: Vector2)
signal mining_started()
signal mining_completed()
signal boss_defeated()
signal level_transition_requested(next_level: int)


func _ready() -> void:
	pass


func register_player(player_node: CharacterBody2D) -> void:
	player = player_node


func register_freighter(freighter_node: CharacterBody2D) -> void:
	freighter = freighter_node


func register_level_root(root_node: Node2D) -> void:
	current_level_root = root_node


func request_freighter_with_node(target_position: Vector2, resource_node: Node) -> void:
	if current_state != LevelState.SCOUTING:
		print("Cannot call freighter during state: ", LevelState.keys()[current_state])
		return
	
	if freighter == null:
		push_error("Freighter not registered with LevelManager!")
		return
	
	freighter.move_to_position(target_position, resource_node)
	freighter_called.emit(target_position)


func on_freighter_arrived() -> void:
	mining_started.emit()


func on_freighter_full() -> void:
	current_state = LevelState.DEFENDING
	mining_completed.emit()
	
	if freighter != null and is_instance_valid(freighter):
		freighter.depart_to_waiting_area(boss_waiting_position)


func on_boss_defeated() -> void:
	current_state = LevelState.LEVEL_COMPLETE
	boss_defeated.emit()
	
	call_deferred("spawn_portals")


func spawn_portals() -> void:
	if portal_scene == null:
		push_error("Portal scene not assigned to LevelManager!")
		return
	
	if current_level_root == null or !is_instance_valid(current_level_root):
		push_error("Level root not registered!")
		return
	
	var home_portal: Area2D = portal_scene.instantiate()
	current_level_root.add_child(home_portal)
	home_portal.global_position = portal_spawn_position + Vector2(-100, 0)
	home_portal.portal_type = "home"
	print("Home portal spawned at: ", home_portal.global_position)
	
	var next_portal: Area2D = portal_scene.instantiate()
	current_level_root.add_child(next_portal)
	next_portal.global_position = portal_spawn_position + Vector2(100, 0)
	next_portal.portal_type = "next_level"
	print("Next Level portal spawned at: ", next_portal.global_position)


func transition_to_vault() -> void:
	GlobalData.transfer_cargo_to_vault()
	get_tree().change_scene_to_file("res://scenes/levels/HomeMap.tscn")


func transition_to_next_level() -> void:
	GlobalData.cargo.current_level += 1
	level_transition_requested.emit(GlobalData.cargo.current_level)
	print("Next level transition not implemented yet")
