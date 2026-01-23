extends Area2D

@export var portal_type: String = "next_level"

@onready var sprite: Sprite2D = $Sprite2D

var spin_speed: float = 2.0

signal portal_entered(type: String)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("portals")
	print("Portal spawned: ", portal_type)


func _process(delta: float) -> void:
	sprite.rotation += spin_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.collision_layer & 1:
		print("Player entered portal: ", portal_type)
		portal_entered.emit(portal_type)
		
		if LevelManager:
			if portal_type == "home":
				LevelManager.transition_to_vault()
			elif portal_type == "next_level":
				LevelManager.transition_to_next_level()
