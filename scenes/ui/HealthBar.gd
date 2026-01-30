extends Control

@onready var fill: ColorRect = $Fill

var max_health: int = 100
var current_health: int = 100


func _ready() -> void:
	update_display()


func initialize(max_hp: int) -> void:
	max_health = max_hp
	current_health = max_hp
	update_display()


func update_health(new_health: int) -> void:
	current_health = clampi(new_health, 0, max_health)
	update_display()


func update_display() -> void:
	if max_health <= 0:
		fill.size.x = 0
		return
	
	var health_ratio: float = float(current_health) / float(max_health)
	fill.scale.x = health_ratio


func _on_player_health_changed(new_health: int) -> void:
	pass # Replace with function body.
