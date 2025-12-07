extends PawnMobile

@warning_ignore("unused_signal") signal trigger_dialogue

@export var move_pattern: Array[Vector2i]
@export var dialogue_keys: Array[String] 

#Attack related
@export var attack_distance := 24  # pixels
@export var attack_cooldown := 1.5
var can_attack := true


var player: Node2D = null


# Movement Related (+ animation)
var move_step: int = 0

@onready var move_max: int = move_pattern.size()
@onready var dialogue: Array[Array] = GbmUtils.get_dialogue(dialogue_keys)

func _process(_delta):
	# Allow movement if conditions are meet
	if player:
		if is_in_attack_range():
			attack()
		else:
			move_towards_player()
	else:
		process_default_movement()

func is_in_attack_range() -> bool:
	if not player:
		return false
	return global_position.distance_to(player.global_position) <= attack_distance

func attack():
	if not can_attack:
		return
	
	# pausa movimento enquanto ataca
	is_stopped = true
	
	can_attack = false
	print("ATACOU o jogador!")

	# animação (se tiver)
	#set_anim_direction(get_direction_to_player())

	# aplicar dano
	if player.has_method("calc_damage"):
		player.calc_damage(10)

	await get_tree().create_timer(attack_cooldown).timeout

	is_stopped = false
	can_attack = true


func process_default_movement():
	if can_move():
		var current_step: Vector2i = move_pattern[move_step]	
		if current_step:
			set_anim_direction(current_step)
			
			# Checks if the next movement opportunity is possible, if it is move to target position
			var target_position: Vector2i = Grid.request_move(self, current_step)
			if target_position:
				move_to(target_position)
			else:
				return # If player is in the way, return to avoid adding to move_step
		else:
			wait()
		
		# Loops movement when move_step is equal to 0
		move_step += 1
		if move_step >= move_max: move_step = 0

func wait():
	is_stopped = true
	await get_tree().create_timer(1.0).timeout
	is_stopped = false

func trigger_event(direction: Vector2i):
	if not is_moving:
		set_anim_direction(-direction) # Face player
		emit_signal("trigger_dialogue", dialogue, set_talking)


func get_direction_to_player() -> Vector2i:
	var diff: Vector2 = player.global_position - global_position

	# Escolher o eixo dominante (para manter movimento tile-based)
	if abs(diff.x) > abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	else:
		return Vector2i(0, sign(diff.y))

func move_towards_player():
	if not can_move(): return
	
	var direction := get_direction_to_player()
	if direction == Vector2i.ZERO:
		return
		
	set_anim_direction(direction)

	var target_position = Grid.request_move(self, direction)
	if target_position:
		move_to(target_position)

func _on_visao_area_entered(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		player = area.get_parent()


func _on_visao_area_exited(area: Area2D) -> void:
	if area.get_parent().is_in_group("player"):
		player = null 
