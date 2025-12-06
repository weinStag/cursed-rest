extends Sprite2D

func _physics_process(delta):
	look_at(get_global_mouse_position())
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func attack() -> void:
	if Input.is_action_just_pressed('ui_mb1'):
		$AnimationPlayer.play("new_animation")
