extends CanvasLayer

@onready var wave_label: Label = $Container/WaveLabel


func _ready() -> void:
	update_enemy_count()


func _process(_delta: float) -> void:
	update_enemy_count()


func update_enemy_count() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	wave_label.text = "Enemies: " + str(enemies.size())
