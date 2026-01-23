extends CanvasLayer

@onready var vault_label: Label = $Container/VBoxContainer/VaultLabel
@onready var cargo_label: Label = $Container/VBoxContainer/CargoLabel


func _ready() -> void:
	GlobalData.credits_changed.connect(_on_credits_changed)
	GlobalData.cargo_changed.connect(_on_cargo_changed)
	
	update_display()


func update_display() -> void:
	vault_label.text = "Credits: " + str(GlobalData.vault.credits)
	cargo_label.text = "Cargo: " + str(GlobalData.cargo.current_resources)


func _on_credits_changed(new_amount: int) -> void:
	vault_label.text = "Credits: " + str(new_amount)


func _on_cargo_changed(new_amount: int) -> void:
	cargo_label.text = "Cargo: " + str(new_amount)
