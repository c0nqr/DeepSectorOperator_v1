extends CharacterBody2D

@export var max_health: int = 200
@export var max_speed: float = 150.0
@export var acceleration: float = 400.0
@export var arrival_distance: float = 50.0
@export var max_cargo: int = 100
@export var drone_scene: PackedScene

enum FreighterState {
	WAITING,
	JUMPING_IN,
	TRAVELING,
	PARKED,
	DEPARTING
}

var current_state: FreighterState = FreighterState.WAITING
var current_health: int = 0
var destination: Vector2 = Vector2.ZERO
var current_cargo: int = 0
var jump_in_point: Vector2 = Vector2(-500, 0)
var assigned_resource_node: StaticBody2D = null
var active_drone: CharacterBody2D = null

@onready var drone_spawn_point: Marker2D = $DroneSpawnPoint
@onready var bars_container: Node2D = $BarsContainer
@onready var health_bar: Control = $BarsContainer/HealthBar
@onready var cargo_bar: Control = $BarsContainer/CargoBar

signal arrived_at_destination()
signal cargo_full()

func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	current_health = max_health
	add_to_group("freighter")
	global_position = jump_in_point
	visible = false
	
	health_bar.initialize(max_health)
	cargo_bar.initialize(max_cargo)
	
	if LevelManager:
		LevelManager.register_freighter(self)

func _physics_process(delta: float) -> void:
	match current_state:
		FreighterState.WAITING:
			pass
		FreighterState.JUMPING_IN:
			current_state = FreighterState.TRAVELING
		FreighterState.TRAVELING:
			process_travel(delta)
		FreighterState.PARKED:
			velocity = Vector2.ZERO
		FreighterState.DEPARTING:
			process_travel(delta)
	
	move_and_slide()

func move_to_position(target_position: Vector2, resource_node: StaticBody2D = null) -> void:
	destination = target_position
	assigned_resource_node = resource_node
	
	if current_state == FreighterState.WAITING:
		visible = true
		current_state = FreighterState.JUMPING_IN
		print("Freighter jumping in...")
	else:
		current_state = FreighterState.TRAVELING
		print("Freighter destination updated")

func process_travel(delta: float) -> void:
	var distance_to_destination: float = global_position.distance_to(destination)
	
	if distance_to_destination < arrival_distance:
		if current_state == FreighterState.TRAVELING:
			current_state = FreighterState.PARKED
			velocity = Vector2.ZERO
			arrived_at_destination.emit()
			if LevelManager:
				LevelManager.on_freighter_arrived()
			spawn_drone()
			print("Freighter arrived and parked")
		elif current_state == FreighterState.DEPARTING:
			current_state = FreighterState.PARKED
			velocity = Vector2.ZERO
			print("Freighter reached waiting area")
		return
	
	var direction: Vector2 = (destination - global_position).normalized()
	look_at(destination)
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)

func spawn_drone() -> void:
	if drone_scene == null:
		push_error("Drone scene not assigned to Freighter!")
		return
	
	if assigned_resource_node == null:
		print("No resource node assigned, skipping drone deployment")
		return

	# We use call_deferred here to be safe, as this is often called 
	# right after a state change or collision event
	call_deferred("_do_spawn_drone", assigned_resource_node)

func _on_drone_destroyed(node: StaticBody2D) -> void:
	print("Freighter: Drone destroyed, scheduling replacement")
	active_drone = null
	# The fix: Defer the spawning so it happens after the physics step
	if node != null and is_instance_valid(node):
		call_deferred("_do_spawn_drone", node)

# Helper function to handle the actual instantiation safely
func _do_spawn_drone(target_node: StaticBody2D) -> void:
	if drone_scene == null or !is_instance_valid(target_node):
		return
		
	var drone: CharacterBody2D = drone_scene.instantiate()
	get_tree().current_scene.add_child(drone)
	drone.global_position = drone_spawn_point.global_position
	drone.initialize(target_node, self)
	active_drone = drone
	drone.drone_destroyed.connect(_on_drone_destroyed)
	print("Drone deployed successfully")

func add_cargo(amount: int) -> void:
	current_cargo += amount
	cargo_bar.update_cargo(current_cargo)
	GlobalData.add_cargo(amount)
	print("Freighter cargo: ", current_cargo, "/", max_cargo)
	
	if current_cargo >= max_cargo:
		cargo_full.emit()
		if LevelManager:
			LevelManager.on_freighter_full()

func is_cargo_full() -> bool:
	return current_cargo >= max_cargo

func take_damage(amount: int) -> void:
	current_health -= amount
	health_bar.update_health(current_health)
	print("Freighter took ", amount, " damage. HP: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()

func die() -> void:
	print("Freighter destroyed! Going home.")
	GlobalData.transfer_cargo_to_vault()
	get_tree().change_scene_to_file("res://scenes/levels/HomeMap.tscn")
	queue_free()

func depart_to_waiting_area(waiting_position: Vector2) -> void:
	destination = waiting_position
	current_state = FreighterState.DEPARTING
	print("Freighter departing to waiting area...")
