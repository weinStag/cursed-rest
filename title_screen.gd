extends Control


func _on_start_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://cutscene_01.tscn")


func _on_quit_btn_3_pressed() -> void:
	get_tree().quit()
