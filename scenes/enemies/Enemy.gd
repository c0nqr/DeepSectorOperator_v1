extends CharacterBody2D

## Enemy parameters
@export var max_health: int = 50
@export var max_speed: float = 250.0
@export var acceleration: float = 800.0
@export var deceleration: float = 600.0
@export var weapon_range: float = 300.0  ## Distance to start attacking
@export var fire_rate: float = 0.5  ## Seconds between shots
@export var damage: int = 10
@export var resource_drop_amount: int = 10  ## Credits added to cargo on death

## State machine
enum EnemyState {
	IDLE,
	CHASING,
	ATTACKING,
	DEAD
}

var current_state: EnemyState = EnemyState.IDLE
var target_player: CharacterBody2D = null
var fire_cooldown: float = 0.0

## References
@onready var detection_area: Area2D = $DetectionArea

## Health
var current_health: int = 0


func _ready() -> void:
	# Set collision layers
	collision_layer = 4  # Enemies layer
	collision_mask = 1 + 2  # Player + Projectiles
	
	# Initialize health
	current_health = max_health
	
	# Add to enemies group for target cycling
	add_to_group("enemies")
	
	# Connect detection area
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)


func _physics_process(delta: float) -> void:
	match current_state:
		EnemyState.IDLE:
			process_idle(delta)
		
		EnemyState.CHASING:
			process_chasing(delta)
		
		EnemyState.ATTACKING:
			process_attacking(delta)
		
		EnemyState.DEAD:
			return  # Do nothing when dead
	
	move_and_slide()


## IDLE: Wait for player detection
func process_idle(delta: float) -> void:
	# Apply deceleration
	velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)


## CHASING: Move toward player
func process_chasing(delta: float) -> void:
	if target_player == null or !is_instance_valid(target_player):
		current_state = EnemyState.IDLE
		return
	
	var distance_to_player := global_position.distance_to(target_player.global_position)
	
	# Check if in weapon range
	if distance_to_player <= weapon_range:
		current_state = EnemyState.ATTACKING
		return
	
	# Move toward player
	var direction := (target_player.global_position - global_position).normalized()
	look_at(target_player.global_position)
	
	var desired_velocity := direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


## ATTACKING: Stay at range and fire
func process_attacking(delta: float) -> void:
	if target_player == null or !is_instance_valid(target_player):
		current_state = EnemyState.IDLE
		return
	
	var distance_to_player := global_position.distance_to(target_player.global_position)
	
	# If player moved out of weapon range, resume chasing
	if distance_to_player > weapon_range * 1.2:  # Hysteresis to prevent flickering
		current_state = EnemyState.CHASING
		return
	
	# Face player
	look_at(target_player.global_position)
	
	# Maintain distance (optional - can remove if you want stationary attacking)
	if distance_to_player < weapon_range * 0.8:
		# Too close, back away slightly
		var direction := (global_position - target_player.global_position).normalized()
		velocity = velocity.move_toward(direction * max_speed * 0.5, acceleration * delta)
	else:
		# Apply deceleration to slow down
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	
	# Fire weapon
	fire_cooldown -= delta
	if fire_cooldown <= 0.0:
		fire_at_player()
		fire_cooldown = fire_rate


## Fire projectile at player (placeholder - you can add projectiles later)
func fire_at_player() -> void:
	# For now, just print - we'll add enemy projectiles in Phase 3
	print(name, " fires at player!")
	# TODO: Spawn enemy projectile


## Take damage from player weapons
func take_damage(amount: int) -> void:
	if current_state == EnemyState.DEAD:
		return
	
	current_health -= amount
	print(name, " took ", amount, " damage. Health: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()


## Handle death
func die() -> void:
	current_state = EnemyState.DEAD
	
	# Add resources to cargo
	GlobalData.add_cargo(resource_drop_amount)
	
	print(name, " destroyed! Dropped ", resource_drop_amount, " resources.")
	
	# TODO: Spawn death VFX, play sound
	
	# Remove from scene
	queue_free()


## Player entered detection range
func _on_detection_area_entered(body: Node2D) -> void:
	if body.collision_layer & 1:  # Check if it's on Player layer
		target_player = body
		if current_state == EnemyState.IDLE:
			current_state = EnemyState.CHASING
			print(name, " detected player - chasing!")


## Player exited detection range
func _on_detection_area_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null
		current_state = EnemyState.IDLE
		print(name, " lost player - returning to idle")
