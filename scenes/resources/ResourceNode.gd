extends StaticBody2D

@export var max_resources: int = 100
@export var mining_rate: int = 5
@export var enemy_scene: PackedScene
@export var enemies_per_wave: int = 10
@export var total_waves: int = 3
@export var delay_between_waves: float = 10.0
@export var spawn_interval_within_wave: float = 0.5

var current_resources: int = 0
var is_mouse_hovering: bool = false
var is_being_mined: bool = false
var current_wave: int = 0
var enemies_spawned_this_wave: int = 0
var wave_spawn_timer: float = 0.0
var wave_delay_timer: float = 0.0
var waiting_for_next_wave: bool = false

@onready var hover_detector: Area2D = $HoverDetector
@onready var parking_marker: Node2D = $ParkingMarker
@onready var enemy_spawn_point: Marker2D = $EnemySpawnPoint

signal resources_depleted()
signal hover_started()
signal hover_ended()


func _ready() -> void:
	current_resources = max_resources
	add_to_group("resource_nodes")
	
	hover_detector.mouse_entered.connect(_on_mouse_entered)
	hover_detector.mouse_exited.connect(_on_mouse_exited)
	
	if LevelManager:
		LevelManager.mining_started.connect(_on_mining_started)
		LevelManager.mining_completed.connect(_on_mining_completed)


func _process(delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var distance_to_mouse: float = global_position.distance_to(mouse_pos)
	
	var detection_radius: float = 50.0
	if hover_detector.get_child_count() > 0 and hover_detector.get_child(0) is CollisionShape2D:
		var shape: CollisionShape2D = hover_detector.get_child(0)
		if shape.shape is CircleShape2D:
			detection_radius = shape.shape.radius
	
	var should_hover: bool = distance_to_mouse <= detection_radius
	
	if should_hover and not is_mouse_hovering:
		_on_mouse_entered()
	elif not should_hover and is_mouse_hovering:
		_on_mouse_exited()
	
	if is_being_mined:
		process_wave_spawning(delta)


func process_wave_spawning(delta: float) -> void:
	if current_wave >= total_waves:
		return
	
	if waiting_for_next_wave:
		wave_delay_timer -= delta
		if wave_delay_timer <= 0.0:
			waiting_for_next_wave = false
			current_wave += 1
			enemies_spawned_this_wave = 0
			wave_spawn_timer = 0.0
			
			if current_wave < total_waves:
				print(name, " - Wave ", current_wave + 1, " starting!")
		return
	
	wave_spawn_timer -= delta
	
	if wave_spawn_timer <= 0.0 and enemies_spawned_this_wave < enemies_per_wave:
		spawn_enemy()
		
		enemies_spawned_this_wave += 1
		wave_spawn_timer = spawn_interval_within_wave
		
		if enemies_spawned_this_wave >= enemies_per_wave:
			if current_wave < total_waves - 1:
				waiting_for_next_wave = true
				wave_delay_timer = delay_between_waves
				print(name, " - Wave ", current_wave + 1, " complete. Next wave in ", delay_between_waves, " seconds.")
			else:
				current_wave = total_waves
				print(name, " - All waves complete!")


func spawn_enemy() -> void:
	if enemy_scene == null:
		push_error("Enemy scene not assigned to ResourceNode!")
		return
	
	var enemy: CharacterBody2D = enemy_scene.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = enemy_spawn_point.global_position
	
	print(name, " - Wave ", current_wave + 1, ": Enemy ", enemies_spawned_this_wave + 1, "/", enemies_per_wave, " spawned")

func extract_resources(amount: int) -> int:
	var extracted: int = min(amount, current_resources)
	current_resources -= extracted
	
	if current_resources <= 0:
		resources_depleted.emit()
		is_being_mined = false
		queue_free()
	
	return extracted


func get_parking_position() -> Vector2:
	return parking_marker.global_position


func _on_mining_started() -> void:
	is_being_mined = true
	current_wave = 0
	enemies_spawned_this_wave = 0
	wave_spawn_timer = 0.0
	waiting_for_next_wave = false
	print(name, " - Mining started. Wave 1 beginning!")


func _on_mining_completed() -> void:
	is_being_mined = false
	print(name, " - Mining completed. Waves stopped.")


func _on_mouse_entered() -> void:
	is_mouse_hovering = true
	hover_started.emit()
	modulate = Color(1.2, 1.2, 1.0)


func _on_mouse_exited() -> void:
	is_mouse_hovering = false
	hover_ended.emit()
	modulate = Color(1.0, 1.0, 1.0)
