extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var pierce_count: int = 0

var velocity: Vector2 = Vector2.ZERO
var pierced_enemies: int = 0


func _ready() -> void:
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta


func initialize(direction: Vector2, spawn_rotation: float) -> void:
	velocity = direction.normalized() * speed
	rotation = spawn_rotation


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
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
