extends Control

@onready var fill: ColorRect = $Fill

var max_cargo: int = 100
var current_cargo: int = 0


func _ready() -> void:
	update_display()


func initialize(max_capacity: int) -> void:
	max_cargo = max_capacity
	current_cargo = 0
	update_display()


func update_cargo(new_cargo: int) -> void:
	current_cargo = clampi(new_cargo, 0, max_cargo)
	update_display()


func update_display() -> void:
	if max_cargo <= 0:
		fill.size.x = 0
		return
	
	var cargo_ratio: float = float(current_cargo) / float(max_cargo)
	fill.scale.x = cargo_ratio


func _on_mining_drone_cargo_changed(new_cargo: int) -> void:
	pass # Replace with function body.
