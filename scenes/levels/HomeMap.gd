extends Node2D

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	print("=== HOME MAP LOADED ===")
	print("Vault Credits: ", GlobalData.vault.credits)
	print("Current Cargo: ", GlobalData.cargo.current_resources)
	
	if LevelManager:
		LevelManager.register_level_root(self)
		LevelManager.register_player(player)
