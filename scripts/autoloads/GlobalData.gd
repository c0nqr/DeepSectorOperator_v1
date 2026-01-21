extends Node

## Persistent vault data (saved to disk)
var vault: Dictionary = {
	"credits": 0,
	"unlocked_levels": 1,
	"unlocked_upgrades": []
}

## Session-only cargo data (reset each run)
var cargo: Dictionary = {
	"current_resources": 0,
	"current_level": 1
}

## Save file path
const SAVE_PATH: String = "user://vault_save.dat"

## Signals for UI updates
signal credits_changed(new_amount: int)
signal cargo_changed(new_amount: int)


func _ready() -> void:
	load_vault()


## Add credits to vault (permanent)
func add_credits(amount: int) -> void:
	vault.credits += amount
	credits_changed.emit(vault.credits)
	save_vault()


## Add resources to cargo (session only)
func add_cargo(amount: int) -> void:
	cargo.current_resources += amount
	cargo_changed.emit(cargo.current_resources)


## Transfer cargo to vault and clear cargo
func transfer_cargo_to_vault() -> void:
	vault.credits += cargo.current_resources
	cargo.current_resources = 0
	credits_changed.emit(vault.credits)
	cargo_changed.emit(0)
	save_vault()


## Reset cargo (called when player dies or restarts level)
func reset_cargo() -> void:
	cargo.current_resources = 0
	cargo_changed.emit(0)


## Save vault to disk
func save_vault() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(vault)
		file.close()
	else:
		push_error("Failed to save vault: " + str(FileAccess.get_open_error()))


## Load vault from disk
func load_vault() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			vault = file.get_var()
			file.close()
			credits_changed.emit(vault.credits)
		else:
			push_error("Failed to load vault: " + str(FileAccess.get_open_error()))
	else:
		print("No save file found. Starting fresh vault.")
