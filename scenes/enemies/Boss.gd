extends CharacterBody2D

@export var max_health: int = 800
@export var max_speed: float = 200.0
@export var acceleration: float = 600.0
@export var chase_distance: float = 150.0
@export var laser_damage_per_second: int = 25
@export var laser_duration: float = 2.0
@export var laser_cooldown: float = 3.0
@export var detection_range: float = 600.0
@export var resource_drop: int = 100

enum BossState {
	IDLE,
	CHASING,
	FIRING_LASER,
	DEAD
}

var current_state: BossState = BossState.IDLE
var current_health: int = 0
var target_player: CharacterBody2D = null
var laser_timer: float = 0.0
var laser_cooldown_timer: float = 0.0
var laser_active: bool = false

@onready var detection_area: Area2D = $DetectionArea
@onready var laser_beam: Line2D = $LaserBeam
@onready var laser_raycast: RayCast2D = $LaserRaycast

signal boss_defeated()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 + 2
	
	current_health = max_health
	laser_cooldown_timer = laser_cooldown
	
	add_to_group("enemies")
	add_to_group("boss")
	
	detection_area.body_entered.connect(_on_detection_area_entered)
	
	print("Boss spawned at waiting area (IDLE)")


func _physics_process(delta: float) -> void:
	match current_state:
		BossState.IDLE:
			process_idle(delta)
		
		BossState.CHASING:
			process_chasing(delta)
		
		BossState.FIRING_LASER:
			process_laser(delta)
		
		BossState.DEAD:
			return
	
	move_and_slide()


func process_idle(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	
	if target_player != null and is_instance_valid(target_player):
		var distance: float = global_position.distance_to(target_player.global_position)
		if distance <= detection_range:
			current_state = BossState.CHASING
			print("Boss activated - engaging player!")


func process_chasing(delta: float) -> void:
	if target_player == null or !is_instance_valid(target_player):
		current_state = BossState.IDLE
		target_player = null
		return
	
	var distance_to_player: float = global_position.distance_to(target_player.global_position)
	
	laser_cooldown_timer -= delta
	
	if distance_to_player <= chase_distance and laser_cooldown_timer <= 0.0:
		current_state = BossState.FIRING_LASER
		laser_timer = laser_duration
		laser_active = true
		velocity = Vector2.ZERO
		print("Boss firing laser!")
		return
	
	var direction: Vector2 = (target_player.global_position - global_position).normalized()
	look_at(target_player.global_position)
	
	var desired_velocity: Vector2 = direction * max_speed
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)


func process_laser(delta: float) -> void:
	if target_player == null or !is_instance_valid(target_player):
		end_laser()
		current_state = BossState.IDLE
		return
	
	look_at(target_player.global_position)
	
	laser_raycast.target_position = Vector2(2000, 0)
	laser_raycast.force_raycast_update()
	
	var laser_end: Vector2
	if laser_raycast.is_colliding():
		laser_end = to_local(laser_raycast.get_collision_point())
		
		var hit_body: Node = laser_raycast.get_collider()
		if hit_body != null and hit_body.has_method("take_damage"):
			var damage_this_frame: int = int(laser_damage_per_second * delta)
			hit_body.take_damage(damage_this_frame)
	else:
		laser_end = laser_raycast.target_position
	
	laser_beam.points = [Vector2.ZERO, laser_end]
	laser_beam.visible = true
	
	laser_timer -= delta
	if laser_timer <= 0.0:
		end_laser()


func end_laser() -> void:
	laser_active = false
	laser_beam.visible = false
	laser_cooldown_timer = laser_cooldown
	current_state = BossState.CHASING
	print("Boss laser finished - cooldown")


func take_damage(amount: int) -> void:
	if current_state == BossState.DEAD:
		return
	
	current_health -= amount
	print("Boss took ", amount, " damage. HP: ", current_health, "/", max_health)
	
	if current_health <= 0:
		die()


func die() -> void:
	current_state = BossState.DEAD
	
	GlobalData.add_cargo(resource_drop)
	
	print("BOSS DEFEATED! Dropped ", resource_drop, " resources.")
	
	boss_defeated.emit()
	
	if LevelManager:
		LevelManager.on_boss_defeated()
	
	queue_free()


func _on_detection_area_entered(body: Node2D) -> void:
	if body.collision_layer & 1:
		target_player = body
		if current_state == BossState.IDLE:
			print("Boss detected player")
