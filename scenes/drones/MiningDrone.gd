extends CharacterBody2D

@export var max_health: int = 30
@export var max_speed: float = 250.0
@export var acceleration: float = 600.0
@export var arrival_distance: float = 30.0
@export var max_cargo_capacity: int = 10
@export var mining_rate: float = 1.0

enum DroneState {
	TRAVELING_TO_NODE,
	MINING,
	RETURNING,
	DEPOSITING
}

var current_state: DroneState = DroneState.TRAVELING_TO_NODE
var current_health: int = 0
var current_cargo: int = 0
var assigned_node: StaticBody2D = null
var parent_freighter: CharacterBody2D = null
var mining_timer: float = 0.0

@onready var health_bar: Control = $BarsContainer/HealthBar
@onready var cargo_bar: Control = $BarsContainer/CargoBar

signal drone_destroyed(assigned_node: StaticBody2D)


func _ready() -> void:
	collision_layer = 2147483648
	collision_mask = 524296
	
	current_health = max_health
	current_cargo = 0
	
	add_to_group("drones")
	
	# Assuming these nodes have an initialize method
	if health_bar.has_method("initialize"):
		health_bar.initialize(max_health)
	if cargo_bar.has_method("initialize"):
		cargo_bar.initialize(max_cargo_capacity)


func initialize(target_node: StaticBody2D, freighter: CharacterBody2D) -> void:
	assigned_node = target_node
	parent_freighter = freighter
	current_state = DroneState.TRAVELING_TO_NODE
	
	# FIX: Wrapped the ternary in parentheses and used is_instance_valid
	var target_name = assigned_node.name if is_instance_valid(assigned_node) else "null"
	print("Drone deployed to mine: ", target_name)


func _physics_process(delta: float) -> void:
	match current_state:
		DroneState.TRAVELING_TO_NODE:
			process_travel_to_node(delta)
		
		DroneState.MINING:
			process_mining(delta)
		
		DroneState.RETURNING:
			process_return_to_freighter(delta)
		
		DroneState.DEPOSITING:
			process_deposit()
	
	move_and_slide()


func process_travel_to_node(delta: float) -> void:
	if !is_instance_valid(assigned_node):
		print("Drone: assigned node invalid, returning to freighter")
		current_state = DroneState.RETURNING
		return
	
	var distance_to_node: float = global_position.distance_to(assigned_node.global_position)
	
	if distance_to_node < arrival_distance:
		current_state = DroneState.MINING
		velocity = Vector2.ZERO
		mining_timer = 0.0
		print("Drone arrived at node, starting mining")
		return
	
	var direction: Vector2 = (assigned_node.global_position - global_position).normalized()
	look_at(assigned_node.global_position)
	
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func process_mining(delta: float) -> void:
	if !is_instance_valid(assigned_node):
		print("Drone: node depleted during mining, returning")
		current_state = DroneState.RETURNING
		return
	
	mining_timer += delta
	
	if mining_timer >= mining_rate:
		mining_timer = 0.0
		
		# Ensure the node has the extract method before calling
		var extracted: int = 0
		if assigned_node.has_method("extract_resources"):
			extracted = assigned_node.extract_resources(1)
			
		if extracted > 0:
			current_cargo += extracted
			if cargo_bar.has_method("update_cargo"):
				cargo_bar.update_cargo(current_cargo)
		else:
			print("Drone: node depleted, returning")
			current_state = DroneState.RETURNING
			return
		
		if current_cargo >= max_cargo_capacity:
			print("Drone cargo full, returning to freighter")
			current_state = DroneState.RETURNING


func process_return_to_freighter(delta: float) -> void:
	if !is_instance_valid(parent_freighter):
		print("Drone: freighter lost, self-destructing")
		queue_free()
		return
	
	var distance_to_freighter: float = global_position.distance_to(parent_freighter.global_position)
	
	if distance_to_freighter < arrival_distance:
		current_state = DroneState.DEPOSITING
		velocity = Vector2.ZERO
		return
	
	var direction: Vector2 = (parent_freighter.global_position - global_position).normalized()
	look_at(parent_freighter.global_position)
	
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func process_deposit() -> void:
	if !is_instance_valid(parent_freighter):
		queue_free()
		return
	
	if parent_freighter.has_method("add_cargo"):
		parent_freighter.add_cargo(current_cargo)
		
	print("Drone deposited ", current_cargo, " resources to freighter")
	current_cargo = 0
	
	if cargo_bar.has_method("update_cargo"):
		cargo_bar.update_cargo(0)
	
	if !is_instance_valid(assigned_node):
		print("Drone: node depleted, returning")
		queue_free()
		return
	
	var freighter_full = false
	if parent_freighter.has_method("is_cargo_full"):
		freighter_full = parent_freighter.is_cargo_full()
		
	if freighter_full:
		print("Drone: freighter full, docking")
		queue_free()
		return
	
	print("Drone returning to mining node")
	current_state = DroneState.TRAVELING_TO_NODE


func take_damage(amount: int) -> void:
	current_health -= amount
	if health_bar.has_method("update_health"):
		health_bar.update_health(current_health)
	
	if current_health <= 0:
		die()


func die() -> void:
	print("Drone destroyed! Lost ", current_cargo, " resources in cargo")
	drone_destroyed.emit(assigned_node)
	queue_free()
