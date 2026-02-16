extends Control
@onready var menusfx = get_node_or_null("MenuSFX")

func _ready():
	if menusfx and not menusfx.playing: menusfx.play()
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/loading_screen.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/credits_screen.tscn")
