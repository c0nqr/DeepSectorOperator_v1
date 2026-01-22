extends Area2D

@export var speed: float = 400.0
@export var damage: int = 15
@export var lifetime: float = 4.0

var velocity: Vector2 = Vector2.ZERO


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
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
