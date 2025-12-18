extends AnimationPlayer

func _on_animation_finished(anim_name):
		get_tree().change_scene_to_file("res://title_screen.tscn")
