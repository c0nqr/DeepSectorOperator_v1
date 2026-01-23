extends Node2D

@onready var boss: CharacterBody2D = $Boss
@onready var boss_health_bar: CanvasLayer = $BossHealthBar


func _ready() -> void:
	if LevelManager:
		LevelManager.register_level_root(self)
		LevelManager.portal_spawn_position = Vector2(1500, 0)
		LevelManager.portal_scene = preload("res://scenes/levels/Portal.tscn")
	
	if boss != null and boss_health_bar != null:
		boss_health_bar.initialize(boss)
