extends Area2D

@export var portal_type: String = "next_level"

@onready var sprite: Sprite2D = $Sprite2D

var spin_speed: float = 2.0

signal portal_entered(type: String)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("portals")
	
	# Color code portals
	if portal_type == "home":
		sprite.modulate = Color(0.3, 1.0, 0.3)  # Green for home
		print("Home Portal spawned")
	elif portal_type == "next_level":
		sprite.modulate = Color(1.0, 0.5, 0.0)  # Orange for next level
		print("Next Level Portal spawned")
	elif portal_type == "test_level":
		sprite.modulate = Color(0.5, 0.5, 1.0)  # Blue for test level
		print("Test Level Portal spawned")
	else:
		sprite.modulate = Color(1.0, 1.0, 1.0)  # White default


func _process(delta: float) -> void:
	sprite.rotation += spin_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.collision_layer & 1:
		print("Player entered portal: ", portal_type)
		portal_entered.emit(portal_type)
		
		call_deferred("_change_scene")


func _change_scene() -> void:
	if portal_type == "home":
		get_tree().change_scene_to_file("res://scenes/levels/HomeMap.tscn")
	elif portal_type == "next_level":
		print("Next level not implemented yet - staying in current scene")
		# TODO: Implement next level transition
	elif portal_type == "test_level":
		get_tree().change_scene_to_file("res://scenes/levels/TestLevel.tscn")
	else:
		push_error("Unknown portal type: " + portal_type)
