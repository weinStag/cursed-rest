extends Control


func _on_acordar_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/gameview.tscn")


func _on_sucumbir_btn_pressed() -> void:
	get_tree().quit()
