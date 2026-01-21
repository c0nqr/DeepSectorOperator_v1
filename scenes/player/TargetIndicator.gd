extends Node2D

@export var rotation_speed: float = 2.0
@export var pulse_speed: float = 3.0
@export var pulse_scale_min: float = 0.9
@export var pulse_scale_max: float = 1.1

var pulse_time: float = 0.0


func _process(delta: float) -> void:
	rotation += rotation_speed * delta
	
	pulse_time += delta * pulse_speed
	var pulse_factor: float = (sin(pulse_time) + 1.0) / 2.0
	var current_scale: float = lerp(pulse_scale_min, pulse_scale_max, pulse_factor)
	scale = Vector2(current_scale, current_scale)
