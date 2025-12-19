extends AnimationPlayer



func _on_animation_finished(animCut) -> void:
	get_tree().change_scene_to_file("res://Scenes/gameview.tscn")
