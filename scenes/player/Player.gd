extends CharacterBody2D

@export var max_speed: float = 400.0
@export var acceleration: float = 1200.0
@export var deceleration: float = 800.0
@export var arrival_distance: float = 10.0
@export var hold_threshold: float = 0.15

@export var fire_rate: float = 0.2
@export var projectile_scene: PackedScene
@export var target_detection_range: float = 800.0
@export var target_indicator_scene: PackedScene

@export var max_health: int = 100

enum MoveState {
	IDLE,
	MOVING_TO_DESTINATION,
	CHASING_CURSOR
}

var current_move_state: MoveState = MoveState.IDLE
var destination: Vector2 = Vector2.ZERO

var mouse_pressed: bool = false
var mouse_press_time: float = 0.0
var mouse_press_position: Vector2 = Vector2.ZERO

var auto_fire_enabled: bool = false
var locked_target: CharacterBody2D = null
var fire_cooldown: float = 0.0
var target_indicator: Node2D = null

var current_health: int = 0

@onready var weapon_mount: Node2D = $WeaponMount
@onready var bars_container: Node2D = $BarsContainer
@onready var health_bar: Control = $BarsContainer/HealthBar

#signal freighter_requested(call_position: Vector2)
signal auto_fire_toggled(enabled: bool)
signal target_locked(target: CharacterBody2D)
signal target_unlocked()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 4
	
	current_health = max_health
	
	add_to_group("player")
	
	health_bar.initialize(max_health)
	
	if LevelManager:
		LevelManager.register_player(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_action"):
		mouse_pressed = true
		mouse_press_time = 0.0
		mouse_press_position = get_global_mouse_position()
		get_viewport().set_input_as_handled()
	
	if event.is_action_released("move_action"):
		if mouse_press_time < hold_threshold:
			destination = mouse_press_position
			current_move_state = MoveState.MOVING_TO_DESTINATION
			rotate_to_target(destination)
		
		mouse_pressed = false
		
		if current_move_state == MoveState.CHASING_CURSOR:
			current_move_state = MoveState.IDLE
		
		get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("fire_weapon"):
		auto_fire_enabled = !auto_fire_enabled
		auto_fire_toggled.emit(auto_fire_enabled)
		print("Auto-fire: ", "ON" if auto_fire_enabled else "OFF")
		get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("target_cycle"):
		cycle_target()
		get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("call_freighter"):
		var target_position: Vector2 = get_global_mouse_position()
		var target_node: Node = null
		
		var hovered_node: Node = get_hovered_resource_node()
		if hovered_node != null and hovered_node.has_method("get_parking_position"):
			target_position = hovered_node.get_parking_position()
			target_node = hovered_node
			print("Calling freighter to resource node parking position")
		else:
			print("Calling freighter to cursor position")
		
		if LevelManager:
			LevelManager.request_freighter_with_node(target_position, target_node)
		
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if mouse_pressed:
		mouse_press_time += delta
		
		if mouse_press_time >= hold_threshold and current_move_state != MoveState.CHASING_CURSOR:
			current_move_state = MoveState.CHASING_CURSOR
		
		if current_move_state == MoveState.CHASING_CURSOR:
			destination = get_global_mouse_position()
			rotate_to_target(destination)
	
	if locked_target and is_instance_valid(locked_target):
		if global_position.distance_to(locked_target.global_position) > target_detection_range:
			unlock_target()
		else:
			rotate_to_target(locked_target.global_position)
	
	match current_move_state:
		MoveState.IDLE:
			apply_deceleration(delta)
		MoveState.MOVING_TO_DESTINATION:
			process_destination_movement(delta)
		MoveState.CHASING_CURSOR:
			process_cursor_chase(delta)
	
	move_and_slide()
	process_weapons(delta)


func process_weapons(delta: float) -> void:
	fire_cooldown -= delta
	
	if auto_fire_enabled and locked_target and is_instance_valid(locked_target) and fire_cooldown <= 0.0:
		fire_projectile()
		fire_cooldown = fire_rate


func fire_projectile() -> void:
	if projectile_scene == null:
		push_error("Projectile scene not assigned to Player!")
		return
	
	var projectile: Area2D = projectile_scene.instantiate()
	get_tree().root.add_child(projectile)
	projectile.global_position = weapon_mount.global_position
	
	var fire_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	projectile.initialize(fire_direction, rotation)


func cycle_target() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		unlock_target()
		return
	
	var valid_targets: Array[CharacterBody2D] = []
	for enemy in enemies:
		if enemy is CharacterBody2D and global_position.distance_to(enemy.global_position) <= target_detection_range:
			valid_targets.append(enemy)
	
	if valid_targets.is_empty():
		unlock_target()
		return
	
	if locked_target == null or !is_instance_valid(locked_target):
		locked_target = valid_targets[0]
	else:
		var current_index: int = valid_targets.find(locked_target)
		var next_index: int = (current_index + 1) % valid_targets.size()
		locked_target = valid_targets[next_index]
	
	spawn_target_indicator()
	target_locked.emit(locked_target)
	print("Target locked: ", locked_target.name)


func spawn_target_indicator() -> void:
	if target_indicator != null and is_instance_valid(target_indicator):
		target_indicator.queue_free()
	
	if target_indicator_scene != null and locked_target != null:
		target_indicator = target_indicator_scene.instantiate()
		locked_target.add_child(target_indicator)
		target_indicator.position = Vector2.ZERO


func unlock_target() -> void:
	if target_indicator != null and is_instance_valid(target_indicator):
		target_indicator.queue_free()
		target_indicator = null
	
	locked_target = null
	target_unlocked.emit()
	print("Target unlocked")


func get_hovered_resource_node() -> Node:
	var nodes: Array = get_tree().get_nodes_in_group("resource_nodes")
	for node in nodes:
		if node is StaticBody2D and "is_mouse_hovering" in node and node.is_mouse_hovering:
			return node
	return null


func process_destination_movement(delta: float) -> void:
	var distance_to_destination: float = global_position.distance_to(destination)
	
	if distance_to_destination < arrival_distance:
		current_move_state = MoveState.IDLE
		return
	
	var direction: Vector2 = (destination - global_position).normalized()
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func process_cursor_chase(delta: float) -> void:
	var direction: Vector2 = (destination - global_position).normalized()
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func apply_deceleration(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)


func rotate_to_target(target: Vector2) -> void:
	look_at(target)


func set_rotation_target(target: Vector2) -> void:
	rotate_to_target(target)


func take_damage(amount: int) -> void:
	current_health -= amount
	health_bar.update_health(current_health)
	print("Player took ", amount, " damage. HP: ", current_health, "/", max_health)
	
	if current_health <= 0:
		print("Player would die here (death deferred to Phase 4)")
