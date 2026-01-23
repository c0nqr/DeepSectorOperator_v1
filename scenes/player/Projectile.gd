extends Area2D

@export var speed: float = 600.0
@export var damage: int = 10
@export var lifetime: float = 3.0  ## Seconds before auto-despawn
@export var pierce_count: int = 0  ## 0 = destroy on first hit, 1+ = pierce enemies

var velocity: Vector2 = Vector2.ZERO
var pierced_enemies: int = 0


func _ready() -> void:
	# Auto-despawn after lifetime
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	
	# Connect hit detection
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta


## Initialize bullet direction and speed
func initialize(direction: Vector2, spawn_rotation: float) -> void:
	velocity = direction.normalized() * speed
	rotation = spawn_rotation


## Handle collision with enemies (Area2D)
func _on_area_entered(area: Area2D) -> void:
	# Check if it's an enemy detection area
	if area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
		_handle_pierce()


## Handle collision with enemy bodies (CharacterBody2D)
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_handle_pierce()


## Destroy bullet or allow pierce
func _handle_pierce() -> void:
	if pierce_count == 0:
		queue_free()
	else:
		pierced_enemies += 1
		if pierced_enemies > pierce_count:
			queue_free()
