extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var pierce_count: int = 0

var velocity: Vector2 = Vector2.ZERO
var pierced_enemies: int = 0


func _ready() -> void:
	print("=== PLAYER PROJECTILE CREATED ===")
	print("  Monitoring: ", monitoring)
	print("  Collision Layer: ", collision_layer)
	print("  Collision Mask: ", collision_mask)
	print("  Has CollisionShape: ", get_child_count() > 0)
	
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	body_entered.connect(_on_body_entered)
	print("  body_entered signal connected")


func _physics_process(delta: float) -> void:
	position += velocity * delta


func initialize(direction: Vector2, spawn_rotation: float) -> void:
	velocity = direction.normalized() * speed
	rotation = spawn_rotation
	print("  Initialized with velocity: ", velocity)


func _on_body_entered(body: Node2D) -> void:
	print("!!! PLAYER PROJECTILE HIT SOMETHING !!!")
	print("  Hit node: ", body.name)
	print("  Hit type: ", body.get_class())
	print("  In enemies group: ", body.is_in_group("enemies"))
	print("  Has take_damage: ", body.has_method("take_damage"))
	
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		print("  -> Dealing damage!")
		body.take_damage(damage)
		_handle_pierce()
	else:
		print("  -> Ignoring (not enemy or no damage method)")


func _handle_pierce() -> void:
	if pierce_count == 0:
		queue_free()
	else:
		pierced_enemies += 1
		if pierced_enemies > pierce_count:
			queue_free()
