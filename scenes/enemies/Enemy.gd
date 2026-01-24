extends CharacterBody2D

@export var max_health: int = 50
@export var max_speed: float = 250.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var weapon_range: float = 300.0
@export var fire_rate: float = 0.5
@export var damage: int = 10
@export var resource_drop_amount: int = 10
@export var projectile_scene: PackedScene
@export var retarget_interval: float = 2.0

enum EnemyState {
	IDLE,
	CHASING,
	ATTACKING,
	DEAD
}

var current_state: EnemyState = EnemyState.IDLE
var current_target: Node2D = null
var fire_cooldown: float = 0.0
var retarget_timer: float = 0.0

@onready var detection_area: Area2D = $DetectionArea

var current_health: int = 0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 + 2 + 16 + 32
	
	#current_state = EnemyState.IDLE
	
	current_health = max_health
	retarget_timer = retarget_interval
	
	add_to_group("enemies")
	
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)
	
	find_nearest_target()


func _physics_process(delta: float) -> void:
	retarget_timer -= delta
	if retarget_timer <= 0.0:
		find_nearest_target()
		retarget_timer = retarget_interval
	
	match current_state:
		EnemyState.IDLE:
			process_idle(delta)
		
		EnemyState.CHASING:
			process_chasing(delta)
		
		EnemyState.ATTACKING:
			process_attacking(delta)
		
		EnemyState.DEAD:
			return
	
	move_and_slide()


func process_idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)


func process_chasing(delta: float) -> void:
	if current_target == null or !is_instance_valid(current_target):
		current_state = EnemyState.IDLE
		return
	
	var distance_to_target: float = global_position.distance_to(current_target.global_position)
	
	if distance_to_target <= weapon_range:
		current_state = EnemyState.ATTACKING
		return

	
	var direction: Vector2 = (current_target.global_position - global_position).normalized()
	look_at(current_target.global_position)
	
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func process_attacking(delta: float) -> void:
	if current_target == null or !is_instance_valid(current_target):
		current_state = EnemyState.IDLE
		return
	
	var distance_to_target: float = global_position.distance_to(current_target.global_position)
	
	if distance_to_target > weapon_range * 1.2:
		current_state = EnemyState.CHASING
		return
	
	look_at(current_target.global_position)
	
	if distance_to_target < weapon_range * 0.8:
		var direction: Vector2 = (global_position - current_target.global_position).normalized()
		velocity = velocity.move_toward(direction * max_speed * 0.5, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	
	fire_cooldown -= delta
	if fire_cooldown <= 0.0:
		fire_at_target()
		fire_cooldown = fire_rate


func fire_at_target() -> void:
	if projectile_scene == null:
		print(name, " has no projectile scene assigned")
		return
	
	if current_target == null or !is_instance_valid(current_target):
		return
	
	var projectile: Area2D = projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	
	var fire_direction: Vector2 = (current_target.global_position - global_position).normalized()
	projectile.initialize(fire_direction, rotation)

func find_nearest_target() -> void:
	var potential_targets: Array[Node2D] = []
	
	var player_nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	for p in player_nodes:
		if p is Node2D:
			potential_targets.append(p)
	
	var drones: Array[Node] = get_tree().get_nodes_in_group("drones")
	for drone in drones:
		if drone is Node2D and is_instance_valid(drone):
			potential_targets.append(drone)
	
	var freighter_nodes: Array[Node] = get_tree().get_nodes_in_group("freighter")
	for f in freighter_nodes:
		if f is Node2D:
			potential_targets.append(f)
	
	if potential_targets.is_empty():
		current_target = null
		current_state = EnemyState.IDLE
		return
	
	var nearest: Node2D = null
	var nearest_distance: float = INF
	
	for target in potential_targets:
		if target == null or !is_instance_valid(target):
			continue
		var distance: float = global_position.distance_to(target.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = target
	
	if nearest == null:
		current_target = null
		current_state = EnemyState.IDLE
		return
	
	current_target = nearest
	
	if nearest_distance <= weapon_range:
		current_state = EnemyState.ATTACKING
	else:
		current_state = EnemyState.CHASING


func take_damage(amount: int) -> void:
	if current_state == EnemyState.DEAD:
		return
	
	current_health -= amount
	
	if current_health <= 0:
		die()


func die() -> void:
	current_state = EnemyState.DEAD
	
	GlobalData.add_cargo(resource_drop_amount)
	
	print(name, " destroyed! Dropped ", resource_drop_amount, " resources.")
	
	queue_free()


func _on_detection_area_entered(body: Node2D) -> void:
	if current_state == EnemyState.IDLE:
		find_nearest_target()


func _on_detection_area_exited(body: Node2D) -> void:
	pass
