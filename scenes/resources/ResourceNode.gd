extends StaticBody2D

@export var max_resources: int = 100
@export var mining_rate: int = 5

var current_resources: int = 0
var is_mouse_hovering: bool = false

@onready var hover_detector: Area2D = $HoverDetector
@onready var parking_marker: Node2D = $ParkingMarker

signal resources_depleted()
signal hover_started()
signal hover_ended()


func _ready() -> void:
	current_resources = max_resources
	add_to_group("resource_nodes")
	
	hover_detector.mouse_entered.connect(_on_mouse_entered)
	hover_detector.mouse_exited.connect(_on_mouse_exited)


func _process(_delta: float) -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var distance_to_mouse: float = global_position.distance_to(mouse_pos)
	
	var detection_radius: float = 50.0
	if hover_detector.get_child(0) is CollisionShape2D:
		var shape: CollisionShape2D = hover_detector.get_child(0)
		if shape.shape is CircleShape2D:
			detection_radius = shape.shape.radius
	
	var should_hover: bool = distance_to_mouse <= detection_radius
	
	if should_hover and not is_mouse_hovering:
		_on_mouse_entered()
	elif not should_hover and is_mouse_hovering:
		_on_mouse_exited()


func extract_resources(amount: int) -> int:
	var extracted: int = min(amount, current_resources)
	current_resources -= extracted
	
	if current_resources <= 0:
		resources_depleted.emit()
		queue_free()
	
	return extracted


func get_parking_position() -> Vector2:
	return parking_marker.global_position


func _on_mouse_entered() -> void:
	is_mouse_hovering = true
	hover_started.emit()
	modulate = Color(1.2, 1.2, 1.0)


func _on_mouse_exited() -> void:
	is_mouse_hovering = false
	hover_ended.emit()
	modulate = Color(1.0, 1.0, 1.0)
