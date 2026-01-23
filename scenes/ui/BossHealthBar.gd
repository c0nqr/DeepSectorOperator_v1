extends CanvasLayer

@onready var progress_bar: ProgressBar = $Container/Panel/ProgressBar
@onready var label: Label = $Container/Panel/Label

var boss: CharacterBody2D = null


func _ready() -> void:
	visible = false


func initialize(boss_node: CharacterBody2D) -> void:
	boss = boss_node
	progress_bar.max_value = boss.max_health
	progress_bar.value = boss.current_health
	visible = true
	label.text = "BOSS: " + str(boss.current_health) + " / " + str(boss.max_health)


func _process(_delta: float) -> void:
	if boss == null or !is_instance_valid(boss):
		queue_free()
		return
	
	progress_bar.value = boss.current_health
	label.text = "BOSS: " + str(boss.current_health) + " / " + str(boss.max_health)
