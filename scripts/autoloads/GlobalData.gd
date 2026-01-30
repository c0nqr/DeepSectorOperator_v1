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
signal entity_died(source: Node, drop_amount: int)
signal cargo_collected(amount: int)
signal transfer_to_vault_requested()
signal cargo_reset_requested()


func _ready() -> void:
	load_vault()

	# Connect event signals to local handlers so other nodes can emit events
	if has_signal("entity_died"):
		entity_died.connect(_on_entity_died)
	if has_signal("cargo_collected"):
		cargo_collected.connect(_on_cargo_collected)
	if has_signal("transfer_to_vault_requested"):
		transfer_to_vault_requested.connect(_on_transfer_to_vault_requested)
	if has_signal("cargo_reset_requested"):
		cargo_reset_requested.connect(_on_cargo_reset_requested)



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


## Event handlers (called when other nodes emit events to the global bus)
func _on_entity_died(source: Node, drop_amount: int) -> void:
	# Default behavior: add dropped resources to current cargo
	add_cargo(drop_amount)

func _on_cargo_collected(amount: int) -> void:
	add_cargo(amount)

func _on_transfer_to_vault_requested() -> void:
	transfer_cargo_to_vault()

func _on_cargo_reset_requested() -> void:
	reset_cargo()


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
